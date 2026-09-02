//! Kulso parancsok futtatasa felso idokorlattal.
//!
//! A `std::process` es a `tokio::process` egyarant korlatlanul var egy
//! gyerekfolyamatra. Egy beragadt `hyprctl` vagy `protonvpn` igy nem csak azt a
//! hivast fagyasztja be: a modul modositasi zarat is fogva tartja, es utana mar
//! minden tovabbi parancs sorban all mogotte.
//!
//! A varakozast ezert kulon szalon vegezzuk, es idotullepeskor megoljuk a
//! gyereket. A `wait_with_output` a szalon mindket csovet folyamatosan uriti,
//! ezert nincs pipe-buffer deadlock sem.

use crate::module::ModuleError;
use anyhow::{Context, Result};
use std::process::{Command, Output, Stdio};
use std::time::Duration;

/// Egy rovid lekerdezes vagy allitas felso hatara. Ennel tovabb egy helyi
/// eszkoz-CLI-nek sincs mit gondolkodnia.
pub const SHORT: Duration = Duration::from_secs(5);

/// Lassabb, de meg interaktiv muveletek (kepatalakitas, portal-ujrainditas).
pub const LONG: Duration = Duration::from_secs(30);

/// Lefuttat egy parancsot, es legfeljebb `timeout` ideig var ra.
///
/// Idotullepeskor `SIGKILL`-t kap a gyerek, es strukturalt hibaval terunk
/// vissza -- a hivo igy meg tudja kulonboztetni a "nincs telepitve" esettol.
pub fn run(program: &str, args: &[&str], timeout: Duration) -> Result<Output> {
    let mut command = Command::new(program);
    command.args(args).stdin(Stdio::null()).stdout(Stdio::piped()).stderr(Stdio::piped());
    run_command(command, program, timeout)
}

/// Ugyanaz, de egy mar felparameterezett `Command`-dal (kornyezeti valtozok,
/// egyedi stdio).
pub fn run_command(mut command: Command, label: &str, timeout: Duration) -> Result<Output> {
    let child = command.spawn().with_context(|| format!("a(z) {label} nem futtathato"))?;
    let pid = child.id();

    let (tx, rx) = std::sync::mpsc::channel();
    std::thread::spawn(move || {
        let _ = tx.send(child.wait_with_output());
    });

    match rx.recv_timeout(timeout) {
        Ok(result) => result.with_context(|| format!("a(z) {label} kimenete nem olvashato")),
        Err(_) => {
            // SAFETY: a kill() csak egy signalt kuld, nem nyul megosztott
            // allapothoz. A pid meg a mienk: a varakozo szal tartja a Child-ot,
            // tehat meg nem lett learatva, es igy nem cserelodhetett ki.
            unsafe {
                libc::kill(pid as libc::pid_t, libc::SIGKILL);
            }
            tracing::warn!(
                program = label,
                timeout_ms = timeout.as_millis() as u64,
                "idotullepes, a folyamat kilove"
            );
            Err(ModuleError::failed(format!(
                "a(z) {label} nem valaszolt {} masodperc alatt",
                timeout.as_secs()
            ))
            .into())
        }
    }
}

/// Tuz-es-felejt valtozat: a kimenet nem erdekel, csak az, hogy ne ragadjon be.
/// A hibat a hivo szandekosan elnyeli -- ezek mind opcionalis mellekhatasok.
pub fn run_quiet(program: &str, args: &[&str], timeout: Duration) {
    if let Err(err) = run(program, args, timeout) {
        tracing::debug!(program, error = format!("{err:#}"), "opcionalis parancs nem futott le");
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_quick_command_returns_its_output() {
        let output = run("echo", &["hello"], SHORT).unwrap();
        assert!(output.status.success());
        assert_eq!(String::from_utf8_lossy(&output.stdout).trim(), "hello");
    }

    #[test]
    fn a_hanging_command_is_killed() {
        let started = std::time::Instant::now();
        let err = run("sleep", &["30"], Duration::from_millis(200)).unwrap_err();

        assert!(err.to_string().contains("nem valaszolt"), "{err}");
        // A lenyeg: visszaterunk, nem varjuk ki a 30 masodpercet.
        assert!(started.elapsed() < Duration::from_secs(5));
    }

    #[test]
    fn a_missing_program_is_an_error_not_a_hang() {
        let err = run("vellum-nincs-ilyen-program", &[], SHORT).unwrap_err();
        assert!(err.to_string().contains("nem futtathato"), "{err}");
    }

    #[test]
    fn a_failing_command_still_returns_its_status() {
        let output = run("false", &[], SHORT).unwrap();
        assert!(!output.status.success());
    }
}

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
//!
//! Minden gyerek sajat folyamatcsoportot kap, es idotullepeskor az egesz
//! csoport kap `SIGKILL`-t. Ha csak a kozvetlen gyereket olnenk meg, az altala
//! inditott unoka (pl. a `protonvpn` Python-folyamata) nyitva tartana a
//! csoveket, es a varakozo szal sosem terne vissza.

use crate::module::ModuleError;
use anyhow::{Context, Result};
use std::io::Write;
use std::os::unix::process::CommandExt;
use std::process::{Child, Command, Output, Stdio};
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

/// Parancs futtatasa egyetlen stdin bemenettel. Erzekeny adatot (peldaul
/// Wi-Fi-jelszot) igy nem kell a parancssorba tenni, ahol a folyamatlistaban
/// lathato lenne.
pub fn run_with_input(
    program: &str,
    args: &[&str],
    input: &[u8],
    timeout: Duration,
) -> Result<Output> {
    let mut command = Command::new(program);
    command.args(args).stdin(Stdio::piped()).stdout(Stdio::piped()).stderr(Stdio::piped());

    let mut child =
        spawn(&mut command).with_context(|| format!("a(z) {program} nem futtathato"))?;
    if let Some(mut stdin) = child.stdin.take()
        && let Err(err) = stdin.write_all(input)
    {
        let _ = child.kill();
        let _ = child.wait();
        return Err(err).with_context(|| format!("a(z) {program} bemenete nem irhato"));
    }
    wait_for_output(child, program, timeout)
}

/// Ugyanaz, de egy mar felparameterezett `Command`-dal (kornyezeti valtozok,
/// egyedi stdio).
pub fn run_command(mut command: Command, label: &str, timeout: Duration) -> Result<Output> {
    let child = spawn(&mut command).with_context(|| format!("a(z) {label} nem futtathato"))?;
    wait_for_output(child, label, timeout)
}

/// Inditas sajat folyamatcsoportban: a csoport azonositoja a gyerek pid-je.
fn spawn(command: &mut Command) -> std::io::Result<Child> {
    command.process_group(0).spawn()
}

fn wait_for_output(child: std::process::Child, label: &str, timeout: Duration) -> Result<Output> {
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
            // tehat meg nem lett learatva, es igy nem cserelodhetett ki. Amig
            // nincs learatva, a csoportazonosito sem kerulhet masik csoporthoz,
            // ezert a negativ pid-del a sajat csoportunkat erjuk el, az
            // unokakkal egyutt.
            unsafe {
                libc::kill(-(pid as libc::pid_t), libc::SIGKILL);
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
    fn a_timeout_also_kills_grandchildren() {
        let dir = std::env::temp_dir().join(format!("vellum-proc-test-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let pid_file = dir.join("grandchild.pid");
        let script = format!("sleep 30 & echo $! > '{}'; wait", pid_file.display());

        let err = run("sh", &["-c", &script], Duration::from_millis(300)).unwrap_err();
        assert!(err.to_string().contains("nem valaszolt"), "{err}");

        let pid = std::fs::read_to_string(&pid_file).unwrap().trim().to_string();
        let proc_dir = std::path::Path::new("/proc").join(&pid);
        let deadline = std::time::Instant::now() + Duration::from_secs(5);
        // Az unoka a mi gyerekunk gyereke, igy az init aratja le; addig zombi
        // lehet, ami mar nem fut.
        let alive = || {
            std::fs::read_to_string(proc_dir.join("stat"))
                .map(|stat| !stat.contains(") Z "))
                .unwrap_or(false)
        };
        while alive() && std::time::Instant::now() < deadline {
            std::thread::sleep(Duration::from_millis(20));
        }
        let _ = std::fs::remove_dir_all(&dir);
        assert!(!alive(), "az unoka ({pid}) tovabb fut");
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

    #[test]
    fn input_is_written_without_putting_it_in_arguments() {
        let output = run_with_input("cat", &[], b"titkos ertek\n", SHORT).unwrap();
        assert_eq!(String::from_utf8_lossy(&output.stdout), "titkos ertek\n");
    }
}

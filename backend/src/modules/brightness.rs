//! A beepitett kijelzo hattervilagitasa (laptop panel).
//!
//! Az allitas a logind `Session.SetBrightness` metodusaval megy: ehhez nem
//! kell root, sem udev-szabaly vagy `brightnessctl`. Ha a logind nem erheto el,
//! a sysfs `brightness` fajlba irunk kozvetlenul (ez csak megfelelo
//! jogosultsaggal sikerul).
//!
//! A valtozast nem pollozzuk: a kernel a `actual_brightness` attributumra
//! `sysfs_notify`-t kuld (fenyerogomb, mas eszkoz, sajat allitasunk), amire a
//! `poll(2)` `POLLPRI`-vel ebred. Hattervilagitas nelkuli gepen (asztali gep)
//! a modul `available: false`-t jelent, es csak percenkent nez ra ujra.

use crate::dbus;
use crate::login::{self, LoginManagerProxy};
use crate::module::{MethodDescription, Module, ModuleDescription, ModuleError, StateSink};
use anyhow::{Result, anyhow};
use async_trait::async_trait;
use serde_json::{Value, json};
use std::io::{Read, Seek, SeekFrom};
use std::os::fd::AsRawFd;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;
use tokio::sync::mpsc;

const BACKLIGHT_DIR: &str = "/sys/class/backlight";
/// Hattervilagitas nelkul ennyi idonkent nezunk ujra (pl. kulso DDC eszkoz).
const RESCAN: Duration = Duration::from_secs(60);
/// A figyelo szal ennyi idonkent nezi meg, le kell-e allnia.
const WATCH_TICK_MS: i32 = 1000;
/// Nullara sosem allitunk: a fekete panelt a felhasznalo nem latja, hogy
/// visszaallitsa.
const MIN_PERCENT: u32 = 1;

#[derive(Debug, Clone, PartialEq, Eq)]
struct Backlight {
    name: String,
    path: PathBuf,
}

impl Backlight {
    /// (jelenlegi, maximum) nyers ertekben.
    fn read(&self) -> Option<(u32, u32)> {
        let max = read_u32(&self.path.join("max_brightness"))?;
        let current = read_u32(&self.path.join("brightness"))?;
        Some((current, max))
    }

    fn state(&self) -> Value {
        match self.read() {
            Some((current, max)) => json!({
                "available": true,
                "device": self.name,
                "percent": to_percent(current, max),
            }),
            None => json!({ "available": false }),
        }
    }
}

fn read_u32(path: &Path) -> Option<u32> {
    std::fs::read_to_string(path).ok()?.trim().parse().ok()
}

/// A kernel ajanlasa szerinti sorrend: firmware, platform, majd raw. Egy
/// rangon belul a nev donti el, hogy a valasztas determinisztikus legyen.
fn find_backlight(dir: &Path) -> Option<Backlight> {
    let mut best: Option<(u8, Backlight)> = None;
    for entry in std::fs::read_dir(dir).ok()?.flatten() {
        let path = entry.path();
        if read_u32(&path.join("max_brightness")).is_none_or(|max| max == 0) {
            continue;
        }
        let rank = match std::fs::read_to_string(path.join("type")).unwrap_or_default().trim() {
            "firmware" => 0,
            "platform" => 1,
            "raw" => 2,
            _ => 3,
        };
        let name = entry.file_name().to_string_lossy().into_owned();
        let better = best
            .as_ref()
            .is_none_or(|(best_rank, current)| (rank, &name) < (*best_rank, &current.name));
        if better {
            best = Some((rank, Backlight { name, path }));
        }
    }
    best.map(|(_, backlight)| backlight)
}

fn to_percent(current: u32, max: u32) -> u32 {
    if max == 0 {
        return 0;
    }
    ((u64::from(current) * 100 + u64::from(max) / 2) / u64::from(max)) as u32
}

fn from_percent(percent: u32, max: u32) -> u32 {
    let percent = percent.clamp(MIN_PERCENT, 100);
    (((u64::from(percent) * u64::from(max) + 50) / 100) as u32).max(1)
}

/// Lepes szazalekban. Keves fokozatu panelen (pl. 15 lepes) egy 5%-os lepes
/// ugyanarra a nyers ertekre kerekulhet; ilyenkor legalabb egy fokozatot
/// lepunk, kulonben a gomb nem csinalna semmit.
fn stepped(current: u32, max: u32, delta: i32) -> u32 {
    let percent = (to_percent(current, max) as i32 + delta).clamp(0, 100) as u32;
    let mut target = from_percent(percent, max);
    if target == current && delta != 0 {
        target = if delta > 0 { (current + 1).min(max) } else { current.saturating_sub(1).max(1) };
    }
    target
}

/// Blokkolo figyelo: a sysfs attributum `poll`-ja csak egy olvasas utan
/// elesedik, ezert minden ebredes utan elolrol olvassuk.
fn watch_changes(path: &Path, tx: &mpsc::Sender<()>, stop: &AtomicBool) {
    let Ok(mut file) = std::fs::File::open(path) else { return };
    let mut buffer = [0u8; 32];
    loop {
        if file.seek(SeekFrom::Start(0)).is_err() || file.read(&mut buffer).is_err() {
            return;
        }
        let mut descriptor = libc::pollfd {
            fd: file.as_raw_fd(),
            events: libc::POLLPRI | libc::POLLERR,
            revents: 0,
        };
        // SAFETY: egyetlen ervenyes pollfd, a hivas alatt el.
        let ready = unsafe { libc::poll(&mut descriptor, 1, WATCH_TICK_MS) };
        if stop.load(Ordering::Relaxed) {
            return;
        }
        if ready < 0 {
            if std::io::Error::last_os_error().kind() == std::io::ErrorKind::Interrupted {
                continue;
            }
            return;
        }
        if descriptor.revents & libc::POLLNVAL != 0 {
            return;
        }
        if ready > 0 && tx.blocking_send(()).is_err() {
            return;
        }
    }
}

/// A futo hurok leallasakor a figyelo szalat is leallitja.
struct StopOnDrop(Arc<AtomicBool>);

impl Drop for StopOnDrop {
    fn drop(&mut self) {
        self.0.store(true, Ordering::Relaxed);
    }
}

pub struct Brightness;

impl Default for Brightness {
    fn default() -> Self {
        Self::new()
    }
}

impl Brightness {
    pub fn new() -> Self {
        Self
    }

    async fn apply(device: &Backlight, raw: u32) -> Result<()> {
        let via_logind = async {
            let connection = dbus::system().await?;
            let manager = LoginManagerProxy::new(&connection).await?;
            let session = login::graphical_session(&connection, &manager).await?;
            session.set_brightness("backlight", &device.name, raw).await?;
            anyhow::Ok(())
        };
        if let Err(err) = via_logind.await {
            tracing::debug!(error = format!("{err:#}"), "logind nelkul, kozvetlen sysfs iras");
            std::fs::write(device.path.join("brightness"), raw.to_string())
                .map_err(|io| anyhow!("a fenyero nem allithato (logind: {err:#}; sysfs: {io})"))?;
        }
        Ok(())
    }
}

#[async_trait]
impl Module for Brightness {
    fn name(&self) -> &'static str {
        "brightness"
    }

    fn describe(&self) -> ModuleDescription {
        ModuleDescription {
            topic: "brightness",
            summary: "A beepitett kijelzo hattervilagitasa (logind SetBrightness).",
            streams: true,
            methods: vec![
                MethodDescription::new("set", "Fenyero szazalekban (1-100).").param(
                    "percent",
                    "number",
                    true,
                    "A cel szazalek.",
                ),
                MethodDescription::new("step", "Fenyero lepese szazalekban.").param(
                    "delta",
                    "number",
                    true,
                    "Pozitiv: vilagosabb, negativ: sotetebb.",
                ),
            ],
        }
    }

    async fn run(self: Arc<Self>, sink: StateSink) -> Result<()> {
        let mut last: Option<Value> = None;
        let mut publish = |state: Value| {
            if last.as_ref() != Some(&state) {
                sink.push(state.clone());
                last = Some(state);
            }
        };

        loop {
            let Some(device) = find_backlight(Path::new(BACKLIGHT_DIR)) else {
                publish(json!({ "available": false }));
                tokio::time::sleep(RESCAN).await;
                continue;
            };
            publish(device.state());

            let (tx, mut rx) = mpsc::channel(4);
            let stop = Arc::new(AtomicBool::new(false));
            let _stop_on_drop = StopOnDrop(stop.clone());
            let watched = device.path.join("actual_brightness");
            tokio::task::spawn_blocking(move || watch_changes(&watched, &tx, &stop));

            while rx.recv().await.is_some() {
                publish(device.state());
            }
            // A figyelo leallt (az eszkoz eltunt): ujrakeresunk.
        }
    }

    async fn call(self: Arc<Self>, method: &str, params: Value, sink: &StateSink) -> Result<Value> {
        let number = |key: &str| {
            params
                .get(key)
                .and_then(Value::as_f64)
                .ok_or_else(|| ModuleError::invalid_params(format!("a `{key}` szam kotelezo")))
        };
        let device = find_backlight(Path::new(BACKLIGHT_DIR))
            .ok_or_else(|| ModuleError::not_found("nincs hattervilagitas"))?;
        let (current, max) =
            device.read().ok_or_else(|| ModuleError::failed("a fenyero nem olvashato"))?;

        let target = match method {
            "set" => from_percent(number("percent")?.round().clamp(0.0, 100.0) as u32, max),
            "step" => stepped(current, max, number("delta")?.round().clamp(-100.0, 100.0) as i32),
            other => return Err(ModuleError::UnknownMethod(other.to_string()).into()),
        };

        if target != current {
            Self::apply(&device, target).await?;
        }
        let state = device.state();
        sink.push(state.clone());
        Ok(state)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn backlight(dir: &Path, name: &str, kind: &str, max: u32, current: u32) {
        let path = dir.join(name);
        std::fs::create_dir_all(&path).unwrap();
        std::fs::write(path.join("type"), format!("{kind}\n")).unwrap();
        std::fs::write(path.join("max_brightness"), format!("{max}\n")).unwrap();
        std::fs::write(path.join("brightness"), format!("{current}\n")).unwrap();
    }

    #[test]
    fn firmware_wins_over_raw() {
        let dir = std::env::temp_dir().join(format!("vellum-backlight-{}", std::process::id()));
        backlight(&dir, "intel_backlight", "raw", 96000, 48000);
        backlight(&dir, "acpi_video0", "firmware", 15, 7);
        backlight(&dir, "broken", "platform", 0, 0);

        let found = find_backlight(&dir).unwrap();
        let state = found.state();
        let _ = std::fs::remove_dir_all(&dir);

        assert_eq!(found.name, "acpi_video0");
        assert_eq!(state["percent"], 47);
    }

    #[test]
    fn no_backlight_is_not_an_error() {
        assert!(find_backlight(Path::new("/nonexistent/vellum")).is_none());
    }

    #[test]
    fn percent_round_trips_and_never_reaches_zero() {
        assert_eq!(to_percent(48000, 96000), 50);
        assert_eq!(from_percent(50, 96000), 48000);
        assert_eq!(from_percent(0, 96000), 960);
        assert_eq!(from_percent(0, 15), 1);
    }

    #[test]
    fn a_coarse_panel_still_moves_one_level() {
        // 15 fokozat: az 5% kevesebb egy fokozatnal.
        assert_eq!(stepped(7, 15, 5), 8);
        assert_eq!(stepped(7, 15, -5), 6);
        assert_eq!(stepped(1, 15, -5), 1);
        assert_eq!(stepped(15, 15, 5), 15);
    }
}

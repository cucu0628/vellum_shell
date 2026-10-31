//! Ki hasznalja eppen a kamerat.
//!
//! Ez valtja ki a `scripts/camera-usage` rezidens bash hurkot. A mikrofon NEM
//! ide tartozik: azt a QML olvassa kozvetlenul a PipeWire grafbol, ami mar
//! esemenyvezerelt -- felesleges lenne ide hozni.
//!
//! A kernel nem ad "kamera megnyitva" esemenyt a folyamatrol, de az inotify
//! jelzi, ha valaki megnyit vagy bezar egy `/dev/video*` eszkozt. Ezert a
//! `/proc` bejarasa csak ilyenkor fut, nem harom masodpercenkent. A `/dev`
//! konyvtarat is figyeljuk, hogy egy kesobb bedugott kamera is bekeruljon.
//! Ha az inotify nem erheto el, marad a korabbi pollozas.

use crate::module::{Module, ModuleDescription, StateSink};
use anyhow::Result;
use async_trait::async_trait;
use serde::Serialize;
use serde_json::json;
use std::ffi::CString;
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd, RawFd};
use std::os::unix::ffi::OsStrExt;
use std::path::Path;
use std::sync::Arc;
use std::time::Duration;
use tokio::io::unix::AsyncFd;

/// Inotify nelkul ennyi idonkent nezunk ra a kamerakra.
const POLL_INTERVAL: Duration = Duration::from_secs(3);
/// Biztonsagi halo az inotify mellett: egy elveszett esemeny se ragadjon be.
const BACKSTOP: Duration = Duration::from_secs(60);
/// Egy megnyitas tobb esemenyt is kivalt; ennyit varunk, mielott bejarjuk a
/// `/proc`-ot, hogy egyszer fusson.
const DEBOUNCE: Duration = Duration::from_millis(150);

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize)]
pub struct CameraUser {
    pub app: String,
    pub device: String,
}

pub struct Privacy;

impl Default for Privacy {
    fn default() -> Self {
        Self::new()
    }
}

impl Privacy {
    pub fn new() -> Self {
        Self
    }
}

#[async_trait]
impl Module for Privacy {
    fn name(&self) -> &'static str {
        "privacy"
    }

    fn describe(&self) -> ModuleDescription {
        ModuleDescription {
            topic: "privacy",
            summary: "Kamerat hasznalo folyamatok. A mikrofon a QML PipeWire olvasasabol jon.",
            streams: true,
            methods: Vec::new(),
        }
    }

    async fn run(self: Arc<Self>, sink: StateSink) -> Result<()> {
        let mut last: Option<Vec<CameraUser>> = None;
        let watcher = match DeviceWatcher::new(Path::new("/dev")) {
            Ok(watcher) => Some(watcher),
            Err(err) => {
                tracing::warn!(%err, "az inotify nem erheto el, a kamerat pollozzuk");
                None
            }
        };

        loop {
            let users = tokio::task::spawn_blocking(camera_users).await.unwrap_or_default();

            if last.as_ref() != Some(&users) {
                sink.push(json!({
                    "cameraActive": !users.is_empty(),
                    "cameraUsers": users,
                }));
                last = Some(users);
            }

            match &watcher {
                Some(watcher) => watcher.wait(BACKSTOP).await?,
                None => tokio::time::sleep(POLL_INTERVAL).await,
            }
        }
    }
}

/// Inotify a videoeszkozok megnyitasara es a `/dev` valtozasaira.
struct DeviceWatcher {
    dev_dir: std::path::PathBuf,
    fd: AsyncFd<Inotify>,
}

impl DeviceWatcher {
    fn new(dev_dir: &Path) -> std::io::Result<Self> {
        let inotify = Inotify::new()?;
        inotify.watch(dev_dir, libc::IN_CREATE | libc::IN_DELETE)?;
        let watcher = Self { dev_dir: dev_dir.to_path_buf(), fd: AsyncFd::new(inotify)? };
        watcher.watch_devices();
        Ok(watcher)
    }

    /// Minden `video*` eszkozre figyelot tesz. Egy mar figyelt utvonalra a
    /// kernel ugyanazt a figyelot adja vissza, egy eltavolitott eszkoz figyeloje
    /// pedig magatol megszunik, ezert eleg mindig az egeszet ujra felvenni.
    fn watch_devices(&self) {
        let Ok(entries) = std::fs::read_dir(&self.dev_dir) else { return };
        for entry in entries.flatten() {
            if !entry.file_name().as_bytes().starts_with(b"video") {
                continue;
            }
            let mask = libc::IN_OPEN | libc::IN_CLOSE_WRITE | libc::IN_CLOSE_NOWRITE;
            if let Err(err) = self.fd.get_ref().watch(&entry.path(), mask) {
                tracing::debug!(%err, path = %entry.path().display(), "a kamera nem figyelheto");
            }
        }
    }

    /// Var a kovetkezo esemenyre (vagy a biztonsagi idokorlatig), majd
    /// osszevonja az utana erkezo esemenyeket.
    async fn wait(&self, backstop: Duration) -> std::io::Result<()> {
        tokio::select! {
            guard = self.fd.readable() => {
                let mut guard = guard?;
                guard.get_inner().drain();
                guard.clear_ready();
            }
            () = tokio::time::sleep(backstop) => {}
        }
        tokio::time::sleep(DEBOUNCE).await;
        self.fd.get_ref().drain();
        self.watch_devices();
        Ok(())
    }
}

struct Inotify {
    fd: OwnedFd,
}

impl Inotify {
    fn new() -> std::io::Result<Self> {
        // SAFETY: egyszeru rendszerhivas; a visszaadott leirot rogton atvesszuk.
        let fd = unsafe { libc::inotify_init1(libc::IN_NONBLOCK | libc::IN_CLOEXEC) };
        if fd < 0 {
            return Err(std::io::Error::last_os_error());
        }
        // SAFETY: a leiro ervenyes es csak a mienk.
        Ok(Self { fd: unsafe { OwnedFd::from_raw_fd(fd) } })
    }

    fn watch(&self, path: &Path, mask: u32) -> std::io::Result<()> {
        let path = CString::new(path.as_os_str().as_bytes())?;
        // SAFETY: a leiro es a nullterminalt utvonal a hivas alatt el.
        let wd = unsafe { libc::inotify_add_watch(self.fd.as_raw_fd(), path.as_ptr(), mask) };
        if wd < 0 {
            return Err(std::io::Error::last_os_error());
        }
        Ok(())
    }

    /// Kiuriti a varakozo esemenyeket. A tartalmuk nem erdekes: barmelyik
    /// esemeny utan ujra bejarjuk a `/proc`-ot.
    fn drain(&self) {
        let mut buffer = [0u8; 4096];
        loop {
            // SAFETY: a puffer a hivas alatt el, a hossza helyes.
            let read = unsafe {
                libc::read(self.fd.as_raw_fd(), buffer.as_mut_ptr().cast(), buffer.len())
            };
            if read <= 0 {
                break;
            }
        }
    }
}

impl AsRawFd for Inotify {
    fn as_raw_fd(&self) -> RawFd {
        self.fd.as_raw_fd()
    }
}

/// Vegigjarja a `/proc/<pid>/fd` szimlinkeket, es osszegyujti azokat, amelyek
/// egy `/dev/video*` eszkozre mutatnak.
fn camera_users() -> Vec<CameraUser> {
    // Ha nincs videoeszkoz, a teljes /proc bejarasat megsporoljuk.
    if !has_video_device() {
        return Vec::new();
    }

    let Ok(entries) = std::fs::read_dir("/proc") else {
        return Vec::new();
    };

    let mut users = Vec::new();

    for entry in entries.flatten() {
        let name = entry.file_name();
        let Some(name) = name.to_str() else { continue };
        if !name.bytes().all(|byte| byte.is_ascii_digit()) {
            continue;
        }

        let process = entry.path();
        let Ok(descriptors) = std::fs::read_dir(process.join("fd")) else {
            // A folyamat kozben eltunhetett, vagy nem a mienk -- nem hiba.
            continue;
        };

        let mut process_name: Option<String> = None;

        for descriptor in descriptors.flatten() {
            let Ok(target) = std::fs::read_link(descriptor.path()) else {
                continue;
            };
            let Some(device) = target.to_str() else { continue };
            if !device.starts_with("/dev/video") {
                continue;
            }

            let app = match &process_name {
                Some(name) => name.clone(),
                None => {
                    let name = std::fs::read_to_string(process.join("comm"))
                        .map(|value| value.trim().to_string())
                        .unwrap_or_default();
                    if name.is_empty() {
                        break;
                    }
                    process_name = Some(name.clone());
                    name
                }
            };

            users.push(CameraUser { app, device: device.to_string() });
        }
    }

    // Egy folyamat ugyanazt az eszkozt tobb leiron is tarthatja.
    users.sort();
    users.dedup();
    users
}

fn has_video_device() -> bool {
    let Ok(entries) = std::fs::read_dir("/dev") else {
        return false;
    };
    entries
        .flatten()
        .any(|entry| entry.file_name().to_str().is_some_and(|name| name.starts_with("video")))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn opening_a_device_wakes_the_watcher() {
        let dir = std::env::temp_dir().join(format!("vellum-privacy-test-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let device = dir.join("video0");
        std::fs::write(&device, b"").unwrap();

        let watcher = DeviceWatcher::new(&dir).unwrap();
        let opener = tokio::spawn(async move {
            tokio::time::sleep(Duration::from_millis(50)).await;
            let _ = std::fs::File::open(&device).unwrap();
        });

        let started = std::time::Instant::now();
        watcher.wait(Duration::from_secs(10)).await.unwrap();
        opener.await.unwrap();
        let _ = std::fs::remove_dir_all(&dir);

        assert!(started.elapsed() < Duration::from_secs(2), "az esemeny nem ebresztett");
    }

    #[tokio::test]
    async fn a_new_device_is_watched_too() {
        let dir =
            std::env::temp_dir().join(format!("vellum-privacy-hotplug-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let watcher = DeviceWatcher::new(&dir).unwrap();

        let device = dir.join("video1");
        std::fs::write(&device, b"").unwrap();
        // A letrehozas ebreszt, es a varakozas vegen mar az uj eszkozt is figyeli.
        watcher.wait(Duration::from_secs(10)).await.unwrap();

        let opener = tokio::spawn(async move {
            tokio::time::sleep(Duration::from_millis(50)).await;
            let _ = std::fs::File::open(&device).unwrap();
        });
        let started = std::time::Instant::now();
        watcher.wait(Duration::from_secs(10)).await.unwrap();
        opener.await.unwrap();
        let _ = std::fs::remove_dir_all(&dir);

        assert!(started.elapsed() < Duration::from_secs(2), "az uj eszkoz nem ebresztett");
    }
}

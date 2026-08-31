//! Ki hasznalja eppen a kamerat.
//!
//! Ez valtja ki a `scripts/camera-usage` rezidens bash hurkot. A mikrofon NEM
//! ide tartozik: azt a QML olvassa kozvetlenul a PipeWire grafbol, ami mar
//! esemenyvezerelt -- felesleges lenne ide hozni.
//!
//! A kernel nem ad "kamera megnyitva" esemenyt, ezert itt marad a pollozas. Ha
//! egyaltalan nincs `/dev/video*`, a ciklus egyetlen konyvtarolvasas -- igy egy
//! kamera nelkuli gepen sem kerul semmibe, a hotplug viszont eszrevevodik.

use crate::module::{Module, ModuleDescription, StateSink};
use anyhow::Result;
use async_trait::async_trait;
use serde::Serialize;
use serde_json::json;
use std::sync::Arc;
use std::time::Duration;

const POLL_INTERVAL: Duration = Duration::from_secs(3);

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize)]
pub struct CameraUser {
    pub app: String,
    pub device: String,
}

pub struct Privacy;

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

        loop {
            let users = tokio::task::spawn_blocking(camera_users).await.unwrap_or_default();

            if last.as_ref() != Some(&users) {
                sink.push(json!({
                    "cameraActive": !users.is_empty(),
                    "cameraUsers": users,
                }));
                last = Some(users);
            }

            tokio::time::sleep(POLL_INTERVAL).await;
        }
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

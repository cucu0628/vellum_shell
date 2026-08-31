//! Cserelheto adathordozok udisks2 D-Bus-on keresztul.
//!
//! Ez valtja ki a 2,5 masodpercenkenti `lsblk --json` inditast es a
//! `udisksctl` hivasokat. Az udisks2 ObjectManagere egyetlen keresben megadja
//! az osszes blokkeszkozt, es jelez, ha valami valtozik -- pollozni nem kell.

use crate::dbus;
use crate::module::{MethodDescription, Module, ModuleDescription, ModuleError, StateSink};
use anyhow::Result;
use async_trait::async_trait;
use futures_util::StreamExt;
use serde::Serialize;
use serde_json::{Value, json};
use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;
use zbus::zvariant::{OwnedObjectPath, OwnedValue};

const SERVICE: &str = "org.freedesktop.UDisks2";
const BLOCK: &str = "org.freedesktop.UDisks2.Block";
const FILESYSTEM: &str = "org.freedesktop.UDisks2.Filesystem";
const PARTITION: &str = "org.freedesktop.UDisks2.Partition";
const DRIVE: &str = "org.freedesktop.UDisks2.Drive";

type Interfaces = HashMap<zbus::names::OwnedInterfaceName, HashMap<String, OwnedValue>>;
type ManagedObjects = HashMap<OwnedObjectPath, Interfaces>;

#[zbus::proxy(
    interface = "org.freedesktop.UDisks2.Filesystem",
    default_service = "org.freedesktop.UDisks2"
)]
trait Filesystem {
    fn mount(&self, options: HashMap<&str, &zbus::zvariant::Value<'_>>) -> zbus::Result<String>;
    fn unmount(&self, options: HashMap<&str, &zbus::zvariant::Value<'_>>) -> zbus::Result<()>;
}

#[zbus::proxy(
    interface = "org.freedesktop.UDisks2.Drive",
    default_service = "org.freedesktop.UDisks2"
)]
trait DriveControl {
    fn power_off(&self, options: HashMap<&str, &zbus::zvariant::Value<'_>>) -> zbus::Result<()>;
}

/// A QML oldal mezoi, valtozatlanul.
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct RemovableDevice {
    pub path: String,
    pub disk_path: String,
    pub name: String,
    pub model: String,
    pub filesystem: String,
    pub size: String,
    pub mountpoint: String,
    pub mounted: bool,
    pub transport: String,
}

pub struct Removable;

impl Removable {
    pub fn new() -> Self {
        Self
    }
}

#[async_trait]
impl Module for Removable {
    fn name(&self) -> &'static str {
        "removable"
    }

    fn describe(&self) -> ModuleDescription {
        ModuleDescription {
            topic: "removable",
            summary: "Csatlakoztatott cserelheto adathordozok.",
            streams: true,
            methods: vec![
                MethodDescription::new("mount", "Kotet csatolasa.").param(
                    "path",
                    "string",
                    true,
                    "A blokkeszkoz utvonala, pl. /dev/sdb1.",
                ),
                MethodDescription::new("unmount", "Kotet lecsatolasa.").param(
                    "path",
                    "string",
                    true,
                    "A blokkeszkoz utvonala.",
                ),
                MethodDescription::new("powerOff", "A meghajto biztonsagos eltavolitasa.").param(
                    "path",
                    "string",
                    true,
                    "A blokkeszkoz utvonala.",
                ),
            ],
        }
    }

    async fn run(self: Arc<Self>, sink: StateSink) -> Result<()> {
        let connection = dbus::system().await?;
        let manager = zbus::fdo::ObjectManagerProxy::builder(&connection)
            .destination(SERVICE)?
            .path("/org/freedesktop/UDisks2")?
            .build()
            .await?;

        let mut added = manager.receive_interfaces_added().await?;
        let mut removed = manager.receive_interfaces_removed().await?;

        let mut last: Option<Vec<RemovableDevice>> = None;
        let publish = |devices: Vec<RemovableDevice>, last: &mut Option<Vec<RemovableDevice>>| {
            if last.as_ref() != Some(&devices) {
                sink.push(json!({ "devices": devices }));
                *last = Some(devices);
            }
        };

        publish(read_devices(&manager).await, &mut last);

        loop {
            // A csatolas/lecsatolas nem interfesz-valtozas, hanem property-e a
            // Filesystem-en, ezert kell melle egy ritka ellenorzes is.
            let backstop = tokio::time::sleep(Duration::from_secs(5));

            tokio::select! {
                _ = added.next() => {}
                _ = removed.next() => {}
                () = backstop => {}
            }

            // Az udisks tobb interfeszt is egyszerre ad hozza egy uj eszkoznel;
            // egy rovid varakozas osszevonja oket.
            tokio::time::sleep(Duration::from_millis(200)).await;
            publish(read_devices(&manager).await, &mut last);
        }
    }

    async fn call(self: Arc<Self>, method: &str, params: Value, sink: &StateSink) -> Result<Value> {
        let path = params
            .get("path")
            .and_then(Value::as_str)
            .ok_or_else(|| ModuleError::invalid_params("hianyzik a 'path'"))?;

        let connection = dbus::system().await?;
        let manager = zbus::fdo::ObjectManagerProxy::builder(&connection)
            .destination(SERVICE)?
            .path("/org/freedesktop/UDisks2")?
            .build()
            .await?;
        let objects = manager.get_managed_objects().await?;

        let object = find_block(&objects, path)
            .ok_or_else(|| ModuleError::not_found(format!("ismeretlen eszkoz: {path}")))?;

        match method {
            "mount" => {
                let proxy = FilesystemProxy::builder(&connection).path(&object)?.build().await?;
                let mountpoint = proxy
                    .mount(HashMap::new())
                    .await
                    .map_err(|err| ModuleError::failed(clean_error(&err.to_string())))?;
                sink.push(json!({ "devices": read_devices(&manager).await }));
                Ok(json!({ "mountpoint": mountpoint }))
            }

            "unmount" => {
                let proxy = FilesystemProxy::builder(&connection).path(&object)?.build().await?;
                proxy
                    .unmount(HashMap::new())
                    .await
                    .map_err(|err| ModuleError::failed(clean_error(&err.to_string())))?;
                sink.push(json!({ "devices": read_devices(&manager).await }));
                Ok(json!({ "unmounted": path }))
            }

            "powerOff" => {
                let drive = objects
                    .get(&object)
                    .and_then(|interfaces| interfaces.get(BLOCK))
                    .and_then(|block| block.get("Drive"))
                    .and_then(object_path_of)
                    .ok_or_else(|| ModuleError::not_found("az eszkozhoz nem tartozik meghajto"))?;

                let proxy = DriveControlProxy::builder(&connection).path(&drive)?.build().await?;
                proxy
                    .power_off(HashMap::new())
                    .await
                    .map_err(|err| ModuleError::failed(clean_error(&err.to_string())))?;
                sink.push(json!({ "devices": read_devices(&manager).await }));
                Ok(json!({ "poweredOff": path }))
            }

            other => Err(ModuleError::UnknownMethod(other.to_string()).into()),
        }
    }
}

/// Az udisks hibauzenetei hosszu D-Bus prefixet hordoznak; a felhasznalonak a
/// vege szol.
fn clean_error(message: &str) -> String {
    message.rsplit_once(": ").map_or(message, |(_, tail)| tail).trim().to_string()
}

fn find_block(objects: &ManagedObjects, device_path: &str) -> Option<OwnedObjectPath> {
    objects.iter().find_map(|(path, interfaces)| {
        let block = interfaces.get(BLOCK)?;
        (byte_string(block.get("Device")?) == device_path).then(|| path.clone())
    })
}

async fn read_devices(manager: &zbus::fdo::ObjectManagerProxy<'_>) -> Vec<RemovableDevice> {
    let Ok(objects) = manager.get_managed_objects().await else {
        return Vec::new();
    };

    // Meghajto -> (modell, busz, cserelheto-e)
    let drives: HashMap<OwnedObjectPath, (String, String, bool)> = objects
        .iter()
        .filter_map(|(path, interfaces)| {
            let drive = interfaces.get(DRIVE)?;
            let model = drive.get("Model").map(string_of).unwrap_or_default();
            let bus = drive.get("ConnectionBus").map(string_of).unwrap_or_default();
            let removable = drive.get("Removable").map(bool_of).unwrap_or(false);
            Some((path.clone(), (model, bus, removable)))
        })
        .collect();

    // Meghajto -> a teljes lemez blokkeszkoze (a particiok kizarasaval).
    let whole_disks: HashMap<OwnedObjectPath, String> = objects
        .values()
        .filter(|interfaces| !interfaces.contains_key(PARTITION))
        .filter_map(|interfaces| {
            let block = interfaces.get(BLOCK)?;
            Some((object_path_of(block.get("Drive")?)?, byte_string(block.get("Device")?)))
        })
        .collect();

    let mut devices: Vec<RemovableDevice> = objects
        .iter()
        .filter_map(|(_, interfaces)| {
            let block = interfaces.get(BLOCK)?;
            let filesystem = interfaces.get(FILESYSTEM)?;

            // Rendszerpartíciót es swapot sosem mutatunk.
            let fstype = block.get("IdType").map(string_of).unwrap_or_default();
            if fstype.is_empty() || fstype == "swap" {
                return None;
            }

            let drive_key = object_path_of(block.get("Drive")?)?;
            let (model, bus, removable) = drives.get(&drive_key)?;

            // Ugyanaz a heurisztika, mint a korabbi lsblk-alapu valtozatban.
            if !removable && !matches!(bus.as_str(), "usb" | "sdio" | "ieee1394") {
                return None;
            }

            let device = byte_string(block.get("Device")?);
            let label = block.get("IdLabel").map(string_of).unwrap_or_default();
            let mountpoint = filesystem
                .get("MountPoints")
                .map(byte_string_list)
                .unwrap_or_default()
                .into_iter()
                .next()
                .unwrap_or_default();

            let name = [label.as_str(), model.as_str()]
                .into_iter()
                .find(|value| !value.is_empty())
                .unwrap_or("Removable device");

            Some(RemovableDevice {
                disk_path: whole_disks.get(&drive_key).cloned().unwrap_or_else(|| device.clone()),
                name: name.to_string(),
                model: if model.is_empty() { "Removable drive".into() } else { model.clone() },
                filesystem: fstype,
                size: format_size(block.get("Size").map(u64_of).unwrap_or(0)),
                mounted: !mountpoint.is_empty(),
                mountpoint,
                transport: bus.clone(),
                path: device,
            })
        })
        .collect();

    // Stabil sorrend, kulonben minden olvasas "valtozasnak" latszana.
    devices.sort_by(|a, b| a.path.cmp(&b.path));
    devices
}

/// A korabbi QML `formatSize` pontos megfeleloje: 1000-es alapu egysegek.
fn format_size(bytes: u64) -> String {
    if bytes == 0 {
        return "Unknown size".to_string();
    }
    const UNITS: [&str; 5] = ["B", "KB", "MB", "GB", "TB"];
    let mut value = bytes as f64;
    let mut unit = 0;
    while value >= 1000.0 && unit < UNITS.len() - 1 {
        value /= 1000.0;
        unit += 1;
    }
    if unit > 1 {
        let decimals = if value >= 10.0 { 0 } else { 1 };
        format!("{value:.decimals$} {}", UNITS[unit])
    } else {
        format!("{} {}", value.round(), UNITS[unit])
    }
}

fn object_path_of(value: &OwnedValue) -> Option<OwnedObjectPath> {
    OwnedObjectPath::try_from(value.try_clone().ok()?).ok()
}

fn string_of(value: &OwnedValue) -> String {
    value.try_clone().ok().and_then(|value| String::try_from(value).ok()).unwrap_or_default()
}

fn bool_of(value: &OwnedValue) -> bool {
    value.try_clone().ok().and_then(|value| bool::try_from(value).ok()).unwrap_or(false)
}

fn u64_of(value: &OwnedValue) -> u64 {
    value.try_clone().ok().and_then(|value| u64::try_from(value).ok()).unwrap_or(0)
}

/// Az udisks a `ay` tipusu utvonalakat lezaro NUL-lal adja vissza.
fn byte_string(value: &OwnedValue) -> String {
    let Ok(value) = value.try_clone() else {
        return String::new();
    };
    let Ok(bytes) = Vec::<u8>::try_from(value) else {
        return String::new();
    };
    String::from_utf8_lossy(&bytes).trim_end_matches('\0').to_string()
}

fn byte_string_list(value: &OwnedValue) -> Vec<String> {
    let Ok(value) = value.try_clone() else {
        return Vec::new();
    };
    let Ok(entries) = Vec::<Vec<u8>>::try_from(value) else {
        return Vec::new();
    };
    entries
        .into_iter()
        .map(|bytes| String::from_utf8_lossy(&bytes).trim_end_matches('\0').to_string())
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn size_formatting_matches_previous_behaviour() {
        assert_eq!(format_size(0), "Unknown size");
        assert_eq!(format_size(512), "512 B");
        assert_eq!(format_size(1_500), "2 KB");
        assert_eq!(format_size(1_500_000), "1.5 MB");
        assert_eq!(format_size(64_000_000_000), "64 GB");
    }
}

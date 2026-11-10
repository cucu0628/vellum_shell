//! Hangkartya-profilok es stream-atiranyitas a Settings Hang oldalanak.
//!
//! A hangero, a nemitas es az alapertelmezett eszkoz a QML-ben marad: azt a
//! Quickshell PipeWire szolgaltatasa esemenyvezerelten adja. Ami ott nincs, az
//! a kartyak profilja (HDMI / analog / ki, Bluetooth A2DP / HFP) es egy stream
//! athelyezese masik eszkozre. Ezek nem allandoan figyelt allapotok, ezert a
//! modul nem streamel: a Hang oldal megnyitaskor es valtozaskor kerdez.
//!
//! A profilok a `pw-dump`-bol jonnek, nem a `pactl -f json`-bol: az utobbi az
//! elso nem ASCII karakternel (pl. egy ekezetes dalcim, egy honositott
//! profilnev) ervenytelen JSON helyett hibat ad. Allitas `wpctl`-lel, az
//! athelyezes `pactl`-lal tortenik. A pipewire-pulse indexe a node
//! `object.serial` erteke; a QML csak az objektum-azonositot (`PwNode.id`)
//! ismeri, a serialt ezert a `pw-dump <id>` adja.

use crate::module::{MethodDescription, Module, ModuleDescription, ModuleError, StateSink};
use crate::proc;
use anyhow::Result;
use async_trait::async_trait;
use serde::Serialize;
use serde_json::{Value, json};
use std::sync::Arc;

#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
struct Profile {
    index: u64,
    name: String,
    description: String,
    /// "yes" | "no" | "unknown": a "no" profil kimenete most nincs bedugva.
    available: String,
    #[serde(skip)]
    priority: i64,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
struct Device {
    /// A PipeWire objektum azonositoja; a `setProfile` ezt kapja vissza.
    id: u64,
    name: String,
    description: String,
    /// "pci" | "usb" | "bluetooth" | ...
    bus: String,
    /// Az aktiv profil indexe, vagy `null`, ha a kartya nem jelentett ilyet.
    profile: Option<u64>,
    profiles: Vec<Profile>,
}

pub struct Audio;

impl Default for Audio {
    fn default() -> Self {
        Self::new()
    }
}

impl Audio {
    pub fn new() -> Self {
        Self
    }
}

#[async_trait]
impl Module for Audio {
    fn name(&self) -> &'static str {
        "audio"
    }

    fn describe(&self) -> ModuleDescription {
        ModuleDescription {
            topic: "audio",
            summary: "Hangkartya-profilok (pw-dump, wpctl) es stream-atiranyitas (pactl).",
            streams: false,
            methods: vec![
                MethodDescription::new("devices", "A hangkartyak es a valaszthato profiljaik."),
                MethodDescription::new("setProfile", "Egy hangkartya profiljanak valtasa.")
                    .param("device", "number", true, "A kartya PipeWire azonositoja.")
                    .param("index", "number", true, "A profil indexe a `devices` valaszabol."),
                MethodDescription::new("moveStream", "Egy stream athelyezese masik eszkozre.")
                    .param("stream", "number", true, "A stream PipeWire objektum-azonositoja.")
                    .param("target", "string", true, "A cel eszkoz PipeWire node-neve.")
                    .param("input", "bool", false, "Felvetel (forras) stream-e."),
            ],
        }
    }

    async fn call(
        self: Arc<Self>,
        method: &str,
        params: Value,
        _sink: &StateSink,
    ) -> Result<Value> {
        match method {
            "devices" => {
                tokio::task::spawn_blocking(|| {
                    let output = proc::run("pw-dump", &[], proc::SHORT)?;
                    if !output.status.success() {
                        return Err(ModuleError::failed("pw-dump could not read PipeWire").into());
                    }
                    let dump: Value = serde_json::from_slice(&output.stdout)
                        .map_err(|_| ModuleError::failed("pw-dump returned invalid JSON"))?;
                    Ok(json!({ "devices": parse_devices(&dump) }))
                })
                .await?
            }
            "setProfile" => {
                let device = required_number(&params, "device")?.to_string();
                let index = required_number(&params, "index")?.to_string();
                tokio::task::spawn_blocking(move || {
                    run_checked("wpctl", &["set-profile", &device, &index])?;
                    Ok(Value::Null)
                })
                .await?
            }
            "moveStream" => {
                let stream = required_number(&params, "stream")?.to_string();
                let target = params
                    .get("target")
                    .and_then(Value::as_str)
                    .filter(|target| !target.is_empty() && !target.starts_with('-'))
                    .ok_or_else(|| ModuleError::invalid_params("a `target` kotelezo node-nev"))?
                    .to_string();
                let input = params.get("input").and_then(Value::as_bool).unwrap_or(false);
                let verb = if input { "move-source-output" } else { "move-sink-input" };
                tokio::task::spawn_blocking(move || {
                    let output = proc::run("pw-dump", &[&stream], proc::SHORT)?;
                    let dump: Value = serde_json::from_slice(&output.stdout).unwrap_or(Value::Null);
                    let serial = stream_serial(&dump, &stream)
                        .ok_or_else(|| ModuleError::not_found("this stream has already ended"))?;
                    run_checked("pactl", &[verb, &serial, &target])?;
                    Ok(Value::Null)
                })
                .await?
            }
            other => Err(ModuleError::UnknownMethod(other.to_string()).into()),
        }
    }
}

fn required_number(params: &Value, name: &str) -> Result<u64> {
    params.get(name).and_then(Value::as_u64).ok_or_else(|| {
        ModuleError::invalid_params(format!("a(z) `{name}` kotelezo nemnegativ egesz")).into()
    })
}

fn run_checked(program: &str, args: &[&str]) -> Result<()> {
    let output = proc::run(program, args, proc::SHORT).map_err(|_| {
        ModuleError::failed(format!("{program} is not installed or did not respond"))
    })?;
    if output.status.success() {
        return Ok(());
    }
    let stderr = String::from_utf8_lossy(&output.stderr);
    let detail = stderr.lines().next().unwrap_or("").trim();
    Err(ModuleError::failed(if detail.is_empty() {
        format!("{program} failed")
    } else {
        detail.to_string()
    })
    .into())
}

/// A `pw-dump <id>` kimenetebol a node `object.serial` erteke, szovegkent.
fn stream_serial(dump: &Value, id: &str) -> Option<String> {
    dump.as_array()?.iter().find_map(|object| {
        if object.get("id")?.as_u64()?.to_string() != id {
            return None;
        }
        match object.get("info")?.get("props")?.get("object.serial")? {
            Value::Number(number) => Some(number.to_string()),
            Value::String(text) if text.chars().all(|c| c.is_ascii_digit()) => Some(text.clone()),
            _ => None,
        }
    })
}

fn text(value: &Value, key: &str) -> String {
    value.get(key).and_then(Value::as_str).unwrap_or_default().to_string()
}

/// A `pw-dump` kimenetebol a hangkartyak (`Audio/Device`), profilokkal.
fn parse_devices(dump: &Value) -> Vec<Device> {
    let Some(objects) = dump.as_array() else { return Vec::new() };
    let mut devices: Vec<Device> = objects
        .iter()
        .filter(|object| {
            object.get("type").and_then(Value::as_str) == Some("PipeWire:Interface:Device")
        })
        .filter_map(|object| {
            let id = object.get("id")?.as_u64()?;
            let info = object.get("info")?;
            let props = info.get("props")?;
            if props.get("media.class").and_then(Value::as_str) != Some("Audio/Device") {
                return None;
            }
            let params = info.get("params");
            let list = |name: &str| {
                params
                    .and_then(|params| params.get(name))
                    .and_then(Value::as_array)
                    .cloned()
                    .unwrap_or_default()
            };

            let mut profiles: Vec<Profile> = list("EnumProfile")
                .iter()
                .filter_map(|entry| {
                    Some(Profile {
                        index: entry.get("index")?.as_u64()?,
                        name: text(entry, "name"),
                        description: text(entry, "description"),
                        available: entry
                            .get("available")
                            .and_then(Value::as_str)
                            .unwrap_or("unknown")
                            .to_string(),
                        priority: entry.get("priority").and_then(Value::as_i64).unwrap_or(0),
                    })
                })
                .collect();
            sort_profiles(&mut profiles);

            let bus = match text(props, "device.api").as_str() {
                "bluez5" => "bluetooth".to_string(),
                _ => text(props, "device.bus"),
            };
            let description = Some(text(props, "device.description"))
                .filter(|description| !description.is_empty())
                .unwrap_or_else(|| text(props, "device.name"));

            Some(Device {
                id,
                name: text(props, "device.name"),
                description,
                bus,
                profile: list("Profile").first().and_then(|entry| entry.get("index")?.as_u64()),
                profiles,
            })
        })
        .collect();
    devices.sort_by(|left, right| left.description.cmp(&right.description));
    devices
}

/// Elol a bedugott (vagy ismeretlen allapotu) profilok prioritas szerint, utana
/// a kihuzottak, majd a ritkan kello "Pro Audio", a vegen a "ki". Igy a lista teteje az, amit a WirePlumber is
/// valasztana.
fn sort_profiles(profiles: &mut [Profile]) {
    let rank = |profile: &Profile| match profile.name.as_str() {
        "off" => 3,
        "pro-audio" => 2,
        _ if profile.available == "no" => 1,
        _ => 0,
    };
    profiles.sort_by(|left, right| {
        rank(left).cmp(&rank(right)).then(right.priority.cmp(&left.priority))
    });
}

#[cfg(test)]
mod tests {
    use super::*;

    fn dump() -> Value {
        json!([
            { "id": 1, "type": "PipeWire:Interface:Core", "info": {} },
            {
                "id": 44,
                "type": "PipeWire:Interface:Device",
                "info": {
                    "props": {
                        "media.class": "Audio/Device",
                        "device.name": "alsa_card.pci-0000_03_00.1",
                        "device.description": "Navi 48 HDMI/DP Audio Controller",
                        "device.bus": "pci",
                        "device.api": "alsa"
                    },
                    "params": {
                        "EnumProfile": [
                            { "index": 0, "name": "off", "description": "Off", "available": "yes", "priority": 0 },
                            { "index": 1, "name": "output:hdmi-stereo", "description": "Digital Stereo (HDMI) Output", "available": "no", "priority": 5900 },
                            { "index": 3, "name": "output:hdmi-stereo-extra2", "description": "Digital Stereo (HDMI 3) Output", "available": "yes", "priority": 5700 },
                            { "index": 4, "name": "pro-audio", "description": "Pro Audio", "available": "yes", "priority": 1 }
                        ],
                        "Profile": [{ "index": 3, "name": "output:hdmi-stereo-extra2" }]
                    }
                }
            },
            {
                "id": 60,
                "type": "PipeWire:Interface:Device",
                "info": {
                    "props": {
                        "media.class": "Audio/Device",
                        "device.name": "bluez_card.AA_BB",
                        "device.description": "Fejhallgató",
                        "device.api": "bluez5"
                    },
                    "params": {}
                }
            },
            {
                "id": 70,
                "type": "PipeWire:Interface:Device",
                "info": { "props": { "media.class": "Video/Device" } }
            }
        ])
    }

    #[test]
    fn reads_audio_devices_with_their_active_profile() {
        let devices = parse_devices(&dump());
        assert_eq!(devices.len(), 2);

        let hdmi = devices.iter().find(|device| device.id == 44).unwrap();
        assert_eq!(hdmi.bus, "pci");
        assert_eq!(hdmi.profile, Some(3));

        let headset = devices.iter().find(|device| device.id == 60).unwrap();
        assert_eq!(headset.bus, "bluetooth");
        assert_eq!(headset.description, "Fejhallgató");
        assert_eq!(headset.profile, None);
        assert!(headset.profiles.is_empty());
    }

    #[test]
    fn plugged_profiles_come_first_and_off_comes_last() {
        let devices = parse_devices(&dump());
        let hdmi = devices.iter().find(|device| device.id == 44).unwrap();
        let order: Vec<u64> = hdmi.profiles.iter().map(|profile| profile.index).collect();
        assert_eq!(order, vec![3, 1, 4, 0]);
    }

    #[test]
    fn the_pulse_index_is_the_serial_of_the_requested_node() {
        let dump = json!([
            { "id": 77, "info": { "props": { "object.serial": 175 } } },
            { "id": 78, "info": { "props": { "object.serial": 176 } } }
        ]);
        assert_eq!(stream_serial(&dump, "78").as_deref(), Some("176"));
        assert_eq!(stream_serial(&dump, "79"), None);
        let text = json!([{ "id": 5, "info": { "props": { "object.serial": "9; rm" } } }]);
        assert_eq!(stream_serial(&text, "5"), None);
    }

    #[test]
    fn a_non_array_dump_yields_no_devices() {
        assert!(parse_devices(&json!({ "error": true })).is_empty());
    }
}

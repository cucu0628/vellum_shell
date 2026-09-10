//! Halozati allapot NetworkManager D-Bus-on keresztul.
//!
//! Ez valtja ki a `nmcli -t ... connection show --active` es az `ip -4 -j`
//! parost, amit a QML 300 masodpercenkent es minden eszkoz-esemenynel
//! ujrainditott, majd kezzel parsolt. Itt az adat a forrasabol jon, es a
//! valtozasrol maga a NetworkManager ertesit.

use crate::dbus;
use crate::module::{MethodDescription, Module, ModuleDescription, ModuleError, StateSink};
use crate::nm;
use crate::proc;
use anyhow::Result;
use async_trait::async_trait;
use futures_util::StreamExt;
use serde::Serialize;
use serde_json::{Value, json};
use std::sync::Arc;
use std::time::Duration;

/// A QML oldal property-nevei, valtozatlanul.
#[derive(Debug, Clone, Default, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct NetworkState {
    pub connected: bool,
    /// "ethernet" | "wifi" | "offline"
    pub connection_type: String,
    pub connection_name: String,
    pub device: String,
    pub lan_ip: String,
    pub vpn_active: bool,
    pub vpn_name: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
struct WifiNetwork {
    active: bool,
    ssid: String,
    signal: u8,
    security: String,
    secure: bool,
    enterprise: bool,
    device: String,
}

pub struct Network;

impl Default for Network {
    fn default() -> Self {
        Self::new()
    }
}

impl Network {
    pub fn new() -> Self {
        Self
    }
}

#[async_trait]
impl Module for Network {
    fn name(&self) -> &'static str {
        "network"
    }

    fn describe(&self) -> ModuleDescription {
        ModuleDescription {
            topic: "network",
            summary: "Aktiv halozati kapcsolat, LAN cim es VPN allapot.",
            streams: true,
            methods: vec![
                MethodDescription::new("scan", "Wi-Fi radioallapot es elerheto halozatok."),
                MethodDescription::new("setWifiEnabled", "A Wi-Fi radio be- vagy kikapcsolasa.")
                    .param("enabled", "bool", true, "A kivant radioallapot."),
                MethodDescription::new("connect", "Csatlakozas egy Wi-Fi halozathoz.")
                    .param("ssid", "string", true, "A halozat neve.")
                    .param("secure", "bool", false, "Ker-e jelszot a halozat.")
                    .param("password", "string", false, "A jelszo; csak stdinre kerul."),
                MethodDescription::new("disconnect", "Wi-Fi eszkoz levalasztasa.").param(
                    "device",
                    "string",
                    true,
                    "A NetworkManager eszkoznev, peldaul wlan0.",
                ),
            ],
        }
    }

    async fn run(self: Arc<Self>, sink: StateSink) -> Result<()> {
        let connection = dbus::system().await?;
        let manager = nm::NetworkManagerProxy::new(&connection).await?;

        // A NetworkManager sajat property-valtozasai fedik le a csatlakozast, a
        // bontast es a VPN fel-le allast.
        let mut active_changes = manager.receive_active_connections_changed().await;
        let mut state_changes = manager.receive_state_changed().await?;

        let mut last: Option<NetworkState> = None;
        let publish = |state: NetworkState, last: &mut Option<NetworkState>| {
            // Csak valodi valtozast tolunk ki: a NetworkManager sokszor ismetel.
            if last.as_ref() != Some(&state) {
                sink.push(json!(state));
                *last = Some(state);
            }
        };

        publish(read_state(&connection, &manager).await, &mut last);

        loop {
            // A backstop azert kell, mert a cim megvaltozasa (pl. uj DHCP lease)
            // nem feltetlenul jelenik meg a NetworkManager sajat property-in.
            let backstop = tokio::time::sleep(Duration::from_secs(60));

            tokio::select! {
                _ = active_changes.next() => {}
                _ = state_changes.next() => {}
                () = backstop => {}
            }

            // A NetworkManager tobb property-t is egyszerre allit at; egy rovid
            // varakozas osszevonja oket egyetlen olvasasba.
            tokio::time::sleep(Duration::from_millis(150)).await;
            publish(read_state(&connection, &manager).await, &mut last);
        }
    }

    async fn call(
        self: Arc<Self>,
        method: &str,
        params: Value,
        _sink: &StateSink,
    ) -> Result<Value> {
        match method {
            "scan" => tokio::task::spawn_blocking(scan_wifi).await?,
            "setWifiEnabled" => {
                let enabled = required_bool(&params, "enabled")?;
                tokio::task::spawn_blocking(move || {
                    run_nmcli(&["radio", "wifi", if enabled { "on" } else { "off" }], None)?;
                    Ok(json!({ "enabled": enabled }))
                })
                .await?
            }
            "connect" => {
                let ssid = required_string(&params, "ssid")?;
                let secure = params.get("secure").and_then(Value::as_bool).unwrap_or(false);
                let password =
                    params.get("password").and_then(Value::as_str).unwrap_or_default().to_string();
                tokio::task::spawn_blocking(move || {
                    let mut args = Vec::new();
                    if secure {
                        args.push("--ask");
                    }
                    args.extend(["device", "wifi", "connect", ssid.as_str()]);
                    let input = secure.then(|| format!("{password}\n"));
                    run_nmcli(&args, input.as_deref())?;
                    Ok(json!({ "connected": true, "ssid": ssid }))
                })
                .await?
            }
            "disconnect" => {
                let device = required_string(&params, "device")?;
                tokio::task::spawn_blocking(move || {
                    run_nmcli(&["device", "disconnect", &device], None)?;
                    Ok(json!({ "disconnected": true, "device": device }))
                })
                .await?
            }
            other => Err(ModuleError::UnknownMethod(other.to_string()).into()),
        }
    }
}

fn required_string(params: &Value, name: &str) -> Result<String> {
    params
        .get(name)
        .and_then(Value::as_str)
        .filter(|value| !value.is_empty())
        .map(str::to_string)
        .ok_or_else(|| ModuleError::invalid_params(format!("a(z) {name} kotelezo szoveg")).into())
}

fn required_bool(params: &Value, name: &str) -> Result<bool> {
    params.get(name).and_then(Value::as_bool).ok_or_else(|| {
        ModuleError::invalid_params(format!("a(z) {name} kotelezo logikai ertek")).into()
    })
}

fn scan_wifi() -> Result<Value> {
    let radio = run_nmcli(&["-t", "-f", "WIFI", "general"], None)?;
    let enabled = radio.trim() == "enabled";
    let networks = if enabled {
        let output = run_nmcli(
            &[
                "-t",
                "-e",
                "yes",
                "-f",
                "IN-USE,SSID,SIGNAL,SECURITY,DEVICE",
                "device",
                "wifi",
                "list",
                "--rescan",
                "yes",
            ],
            None,
        )?;
        parse_wifi_networks(&output)
    } else {
        Vec::new()
    };
    Ok(json!({ "wifiEnabled": enabled, "networks": networks }))
}

fn run_nmcli(args: &[&str], input: Option<&str>) -> Result<String> {
    let output = match input {
        Some(input) => proc::run_with_input("nmcli", args, input.as_bytes(), proc::LONG)?,
        None => proc::run("nmcli", args, proc::LONG)?,
    };
    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    if output.status.success() {
        return Ok(stdout);
    }

    let stderr = String::from_utf8_lossy(&output.stderr);
    let detail = if stderr.trim().is_empty() { stdout.trim() } else { stderr.trim() };
    Err(ModuleError::failed(connection_error(detail)).into())
}

fn connection_error(output: &str) -> String {
    let lower = output.to_lowercase();
    if lower.contains("secrets were required") || lower.contains("not provided") {
        return "A password is required or the password is incorrect".into();
    }
    if lower.contains("no network with ssid") {
        return "This network is no longer available".into();
    }
    if lower.contains("activation failed") {
        return "Could not connect to this network".into();
    }
    output
        .lines()
        .next_back()
        .filter(|line| !line.is_empty())
        .unwrap_or("Network operation failed")
        .into()
}

fn split_escaped(line: &str) -> Vec<String> {
    let mut fields = vec![String::new()];
    let mut escaped = false;
    for character in line.chars() {
        if escaped {
            fields.last_mut().unwrap().push(character);
            escaped = false;
        } else if character == '\\' {
            escaped = true;
        } else if character == ':' {
            fields.push(String::new());
        } else {
            fields.last_mut().unwrap().push(character);
        }
    }
    if escaped {
        fields.last_mut().unwrap().push('\\');
    }
    fields
}

fn parse_wifi_networks(output: &str) -> Vec<WifiNetwork> {
    let mut networks: Vec<WifiNetwork> = Vec::new();
    for line in output.lines().filter(|line| !line.is_empty()) {
        let fields = split_escaped(line);
        if fields.len() < 5 || fields[1].is_empty() {
            continue;
        }
        let security = fields[3].clone();
        let candidate = WifiNetwork {
            active: fields[0] == "*" || fields[0] == "yes",
            ssid: fields[1].clone(),
            signal: fields[2].parse().unwrap_or(0),
            secure: !security.is_empty() && security != "--",
            enterprise: security.contains("802.1X") || security.contains("EAP"),
            security,
            device: fields[4].clone(),
        };

        match networks.iter_mut().find(|network| network.ssid == candidate.ssid) {
            Some(current) if candidate.active || candidate.signal > current.signal => {
                *current = candidate;
            }
            None => networks.push(candidate),
            _ => {}
        }
    }
    networks
        .sort_by(|left, right| right.active.cmp(&left.active).then(right.signal.cmp(&left.signal)));
    networks
}

async fn read_state(
    connection: &zbus::Connection,
    manager: &nm::NetworkManagerProxy<'_>,
) -> NetworkState {
    let mut state = NetworkState { connection_type: "offline".into(), ..Default::default() };
    let links = nm::active_links(connection, manager).await;

    let mut best: Option<&nm::ActiveLink> = None;

    for link in &links {
        // A VPN kulon sav: nem versenyez a fizikai kapcsolattal.
        if link.is_tunnel() {
            if !state.vpn_active {
                state.vpn_active = true;
                state.vpn_name = link.id.clone();
            }
            continue;
        }

        let Some(kind) = link.physical_kind() else {
            continue;
        };
        if link.device.is_none() {
            continue;
        }

        // Vezetekes kapcsolat elonyt elvez a vezetek nelkulivel szemben.
        let better = best.is_none_or(|current| {
            kind == "ethernet" && current.physical_kind() != Some("ethernet")
        });
        if better {
            best = Some(link);
        }
    }

    if let Some(link) = best {
        state.connected = true;
        state.connection_type = link.physical_kind().unwrap_or("offline").to_string();
        state.connection_name = link.id.clone();
        if let Some(device_path) = &link.device {
            let (interface, ip) = nm::device_details(connection, device_path).await;
            state.device = interface;
            state.lan_ip = ip;
        }
    }

    state
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_escaped_fields_and_keeps_the_strongest_access_point() {
        let networks = parse_wifi_networks(
            "no:Cafe\\: guest:38:WPA2:wlan0\n*:Cafe\\: guest:72:WPA2:wlan0\nno:Open:91:--:wlan0\n",
        );

        assert_eq!(networks.len(), 2);
        assert_eq!(networks[0].ssid, "Cafe: guest");
        assert!(networks[0].active);
        assert_eq!(networks[0].signal, 72);
        assert!(networks[0].secure);
        assert_eq!(networks[1].ssid, "Open");
        assert!(!networks[1].secure);
    }

    #[test]
    fn maps_common_connection_errors_to_actionable_messages() {
        assert_eq!(
            connection_error("Error: Secrets were required, but not provided"),
            "A password is required or the password is incorrect"
        );
        assert_eq!(connection_error("first line\nlast line"), "last line");
    }
}

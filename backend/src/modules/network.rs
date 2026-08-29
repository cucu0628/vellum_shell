//! Halozati allapot NetworkManager D-Bus-on keresztul.
//!
//! Ez valtja ki a `nmcli -t ... connection show --active` es az `ip -4 -j`
//! parost, amit a QML 300 masodpercenkent es minden eszkoz-esemenynel
//! ujrainditott, majd kezzel parsolt. Itt az adat a forrasabol jon, es a
//! valtozasrol maga a NetworkManager ertesit.

use crate::dbus;
use crate::module::{Module, ModuleDescription, StateSink};
use crate::nm;
use anyhow::Result;
use async_trait::async_trait;
use futures_util::StreamExt;
use serde::Serialize;
use serde_json::json;
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

pub struct Network;

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
            methods: Vec::new(),
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
        let better = best
            .is_none_or(|current| kind == "ethernet" && current.physical_kind() != Some("ethernet"));
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

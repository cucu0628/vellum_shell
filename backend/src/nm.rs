//! NetworkManager D-Bus proxyk, kozosen a `network` es a `vpn` modulnak.
//!
//! Mindketto ugyanazt a listat jarja be (aktiv kapcsolatok), csak mast keres
//! benne: az egyik a fizikai linket, a masik az alagutat.

use std::collections::HashMap;
use zbus::zvariant::{OwnedObjectPath, OwnedValue};

#[zbus::proxy(
    interface = "org.freedesktop.NetworkManager",
    default_service = "org.freedesktop.NetworkManager",
    default_path = "/org/freedesktop/NetworkManager"
)]
pub trait NetworkManager {
    #[zbus(property)]
    fn active_connections(&self) -> zbus::Result<Vec<OwnedObjectPath>>;

    #[zbus(signal)]
    fn state_changed(&self, state: u32) -> zbus::Result<()>;
}

#[zbus::proxy(
    interface = "org.freedesktop.NetworkManager.Connection.Active",
    default_service = "org.freedesktop.NetworkManager"
)]
pub trait ActiveConnection {
    #[zbus(property)]
    fn id(&self) -> zbus::Result<String>;

    #[zbus(property, name = "Type")]
    fn connection_type(&self) -> zbus::Result<String>;

    #[zbus(property)]
    fn devices(&self) -> zbus::Result<Vec<OwnedObjectPath>>;
}

#[zbus::proxy(
    interface = "org.freedesktop.NetworkManager.Device",
    default_service = "org.freedesktop.NetworkManager"
)]
pub trait Device {
    #[zbus(property)]
    fn interface(&self) -> zbus::Result<String>;

    #[zbus(property)]
    fn ip4_config(&self) -> zbus::Result<OwnedObjectPath>;
}

#[zbus::proxy(
    interface = "org.freedesktop.NetworkManager.IP4Config",
    default_service = "org.freedesktop.NetworkManager"
)]
pub trait Ip4Config {
    #[zbus(property)]
    fn address_data(&self) -> zbus::Result<Vec<HashMap<String, OwnedValue>>>;
}

/// Egy aktiv kapcsolat, amennyit egy menetben kiolvasunk rola.
#[derive(Debug, Clone)]
pub struct ActiveLink {
    /// A NetworkManager tipusa, pl. "802-3-ethernet", "wifi", "vpn", "wireguard".
    pub kind: String,
    /// A kapcsolat neve, pl. "Wired connection 1" vagy "ProtonVPN NL-FREE#113".
    pub id: String,
    pub device: Option<OwnedObjectPath>,
}

impl ActiveLink {
    pub fn is_tunnel(&self) -> bool {
        self.kind == "vpn" || self.kind == "wireguard"
    }

    /// "ethernet" | "wifi" | None, ha nem fizikai link.
    pub fn physical_kind(&self) -> Option<&'static str> {
        match self.kind.as_str() {
            "802-3-ethernet" | "ethernet" => Some("ethernet"),
            "802-11-wireless" | "wifi" => Some("wifi"),
            _ => None,
        }
    }
}

/// Az osszes aktiv kapcsolat. A hibas bejegyzeseket csendben kihagyjuk: egy
/// eppen lebonto kapcsolat nem hiba.
pub async fn active_links(
    connection: &zbus::Connection,
    manager: &NetworkManagerProxy<'_>,
) -> Vec<ActiveLink> {
    let Ok(paths) = manager.active_connections().await else {
        return Vec::new();
    };

    let mut links = Vec::new();
    for path in paths {
        let Ok(builder) = ActiveConnectionProxy::builder(connection).path(&path) else {
            continue;
        };
        let Ok(active) = builder.build().await else {
            continue;
        };
        let Ok(kind) = active.connection_type().await else {
            continue;
        };
        links.push(ActiveLink {
            kind,
            id: active.id().await.unwrap_or_default(),
            device: active.devices().await.ok().and_then(|d| d.into_iter().next()),
        });
    }
    links
}

/// Az eszkoz neve es az elso globalis IPv4 cime.
pub async fn device_details(
    connection: &zbus::Connection,
    device_path: &OwnedObjectPath,
) -> (String, String) {
    let Ok(builder) = DeviceProxy::builder(connection).path(device_path) else {
        return (String::new(), String::new());
    };
    let Ok(device) = builder.build().await else {
        return (String::new(), String::new());
    };

    let interface = device.interface().await.unwrap_or_default();

    let Ok(config_path) = device.ip4_config().await else {
        return (interface, String::new());
    };
    let Ok(builder) = Ip4ConfigProxy::builder(connection).path(&config_path) else {
        return (interface, String::new());
    };
    let Ok(config) = builder.build().await else {
        return (interface, String::new());
    };
    let Ok(addresses) = config.address_data().await else {
        return (interface, String::new());
    };

    let ip = addresses
        .into_iter()
        .find_map(|entry| {
            let value = entry.get("address")?;
            String::try_from(value.try_clone().ok()?).ok()
        })
        .unwrap_or_default();

    (interface, ip)
}

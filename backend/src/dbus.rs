//! Megosztott D-Bus kapcsolatok.
//!
//! A rendszerbuszt tobb modul is hasznalja (NetworkManager, udisks2), ezert
//! egyszer nyitjuk meg es ujrahasznositjuk. A kapcsolat lusta: csak akkor jon
//! letre, amikor az elso modul tenylegesen keri.

use anyhow::{Context, Result};
use tokio::sync::OnceCell;
use zbus::Connection;

static SYSTEM: OnceCell<Connection> = OnceCell::const_new();

pub async fn system() -> Result<Connection> {
    SYSTEM
        .get_or_try_init(|| async {
            Connection::system().await.context("nem sikerult a rendszerbuszhoz csatlakozni")
        })
        .await
        .cloned()
}

//! Modul registry.
//!
//! Uj kepesseg hozzaadasa ket lepes:
//!   1. uj fajl ebben a mappaban, ami implementalja a `Module` traitet;
//!   2. egy sor a `registry()` vektoraban.
//!
//! Semmi mas -- a hub, a protokoll es a QML kliens valtozatlan marad.

pub mod health;
pub mod hypr;
pub mod network;
pub mod privacy;
pub mod removable;
pub mod sysstats;
pub mod theme;
pub mod vpn;
pub mod weather;

use crate::module::Module;
use std::sync::Arc;

pub fn registry() -> Vec<Arc<dyn Module>> {
    vec![
        Arc::new(health::Health::new()),
        Arc::new(theme::Theme::new()),
        Arc::new(network::Network::new()),
        Arc::new(hypr::Hypr::new()),
        Arc::new(removable::Removable::new()),
        Arc::new(privacy::Privacy::new()),
        Arc::new(sysstats::SysStats::new()),
        Arc::new(vpn::Vpn::new()),
        Arc::new(weather::Weather::new()),
    ]
}

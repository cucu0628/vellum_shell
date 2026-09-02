//! Vellum Shell backend konyvtar.
//!
//! A binaris (`main.rs`) es az integracios tesztek egyarant ezt hasznaljak,
//! igy a tema-generatorok kimenete kozvetlenul osszevetheto a bash scriptek
//! rogzitett golden baseline-javal.

pub mod dbus;
pub mod edid;
pub mod ipc;
pub mod module;
pub mod modules;
pub mod nm;
pub mod proc;
pub mod theme;

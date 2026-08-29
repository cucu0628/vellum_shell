//! Tema-generatorok: egy paletta -> az egyes alkalmazasok sajat formatuma.
//!
//! Uj generator hozzaadasa: egy uj fajl itt egy `generate(&Palette)`
//! fuggvennyel, plusz egy sor a `run_all`-ban.
//!
//! A kimeneti utvonalak szandekosan azonosak a korabbi bash scriptekevel: a
//! kitty.conf es a gtk.css mar hivatkozik rajuk a felhasznalo konfigjaban,
//! ezert az athelyezes csendben eltorne a temazast.

pub mod btop;
pub mod fastfetch;
pub mod gtk;
pub mod hyprland;
pub mod icon;
pub mod kitty;
pub mod sddm;
pub mod zen;

use crate::theme::palette::Palette;
use anyhow::Result;
use std::path::PathBuf;

#[derive(Debug, Clone, serde::Serialize)]
pub struct Outcome {
    pub generator: &'static str,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub path: Option<PathBuf>,
    pub changed: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

impl Outcome {
    fn ok(generator: &'static str, written: Option<(PathBuf, bool)>) -> Self {
        match written {
            Some((path, changed)) => {
                Self { generator, path: Some(path), changed, error: None }
            }
            None => Self { generator, path: None, changed: false, error: None },
        }
    }

    fn failed(generator: &'static str, err: &anyhow::Error) -> Self {
        Self { generator, path: None, changed: false, error: Some(format!("{err:#}")) }
    }
}

/// Vegigfuttatja az osszes generatort.
///
/// Egy generator hibaja nem allitja meg a tobbit -- ez a korabbi `|| true`
/// lancolas viselkedese: ha pl. nincs Zen profil, a kitty temaja attol meg
/// frissuljon.
pub fn run_all(palette: &Palette, include_zen: bool) -> Vec<Outcome> {
    let mut outcomes = vec![
        run("kitty", || kitty::generate(palette)),
        run("gtk", || gtk::generate(palette)),
        run("icon", || icon::generate(palette)),
        run("hyprland", || hyprland::generate(palette)),
        run("btop", || btop::generate(palette)),
        run("fastfetch", || fastfetch::generate(palette)),
        run("sddm", || sddm::generate(palette)),
    ];

    // A Zen profil patchelese a legtolakodobb muvelet, ezert kulon kapcsolhato.
    if include_zen {
        outcomes.push(run("zen", || zen::generate(palette)));
    }

    outcomes
}

fn run(
    name: &'static str,
    generate: impl FnOnce() -> Result<Option<(PathBuf, bool)>>,
) -> Outcome {
    match generate() {
        Ok(written) => Outcome::ok(name, written),
        Err(err) => {
            tracing::warn!(generator = name, error = format!("{err:#}"), "generator hibara futott");
            Outcome::failed(name, &err)
        }
    }
}

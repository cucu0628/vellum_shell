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
pub mod neovim;
pub mod qt6ct;
pub mod sddm;
pub mod zen;

use crate::theme::palette::Palette;
use anyhow::Result;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, serde::Serialize)]
pub struct Outcome {
    pub generator: &'static str,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub path: Option<PathBuf>,
    pub changed: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
    /// Kotelezo-e ez a generator: az altalunk birtokolt fajlok igen, a
    /// kulso alkalmazasok konfigja nem. Egy kotelezo generator hibaja azt
    /// jelenti, hogy a tema nem lett alkalmazva -- lasd `theme::apply`.
    pub required: bool,
}

impl Outcome {
    fn ok(generator: &'static str, required: bool, written: Option<(PathBuf, bool)>) -> Self {
        match written {
            Some((path, changed)) => {
                Self { generator, path: Some(path), changed, error: None, required }
            }
            None => Self { generator, path: None, changed: false, error: None, required },
        }
    }

    fn failed(generator: &'static str, required: bool, err: &anyhow::Error) -> Self {
        Self { generator, path: None, changed: false, error: Some(format!("{err:#}")), required }
    }

    pub fn is_failure(&self) -> bool {
        self.error.is_some()
    }
}

/// Kotelezo generator: olyan fajlt ir, ami a shell sajat felulethez vagy a
/// telepitesunkhoz tartozik. Ha ez bukik, a temavaltas nem tortent meg.
const REQUIRED: bool = true;

/// Opcionalis generator: egy kulso alkalmazas konfigja. Ha az app nincs
/// telepitve vagy a profilja hianyzik, az nem a temavaltas hibaja.
const OPTIONAL: bool = false;

/// Vegigfuttatja az osszes generatort.
///
/// Egy generator hibaja nem allitja meg a tobbit -- ez a korabbi `|| true`
/// lancolas viselkedese: ha pl. nincs Zen profil, a kitty temaja attol meg
/// frissuljon. A kotelezo es az opcionalis hiba viszont nem ugyanaz: az
/// elobbibol a `theme::apply` hibat csinal, es meg sem rogziti az uj temat.
/// A `wallpaper` az EPPEN alkalmazott kep, nem a rogzitett allapot: a
/// `theme::apply` szandekosan csak a legvegen commitolja a `current-wallpaper`-t,
/// tehat a generatorok futasakor a fajl meg a regi erteket tartja.
pub fn run_all(palette: &Palette, wallpaper: Option<&Path>, include_zen: bool) -> Vec<Outcome> {
    let mut outcomes = vec![
        // A sajat mappankba vagy a sajat konfigfajljainkba iranak: ha ezek
        // buknak, az nem egy hianyzo alkalmazas, hanem valodi irasi hiba.
        run("kitty", REQUIRED, || kitty::generate(palette)),
        run("gtk", REQUIRED, || gtk::generate(palette)),
        run("qt6ct", OPTIONAL, || qt6ct::generate(palette)),
        run("hyprland", REQUIRED, || hyprland::generate(palette)),
        // Kulso alkalmazasok: hianyozhatnak, es akkor nincs mit temazni.
        run("icon", OPTIONAL, || icon::generate(palette)),
        run("btop", OPTIONAL, || btop::generate(palette)),
        run("neovim", OPTIONAL, || neovim::generate(palette)),
        run("fastfetch", OPTIONAL, || fastfetch::generate(palette)),
        // Az SDDM temaja rendszerkonyvtarban ul: root nelkul varhatoan bukik.
        run("sddm", OPTIONAL, || sddm::generate(palette, wallpaper)),
    ];

    // A Zen profil patchelese a legtolakodobb muvelet, ezert kulon kapcsolhato.
    if include_zen {
        outcomes.push(run("zen", OPTIONAL, || zen::generate(palette)));
    }

    outcomes
}

/// A kotelezo generatorok hibai, ember altal olvashato formaban.
pub fn required_failures(outcomes: &[Outcome]) -> Vec<String> {
    outcomes
        .iter()
        .filter(|outcome| outcome.required && outcome.is_failure())
        .map(|outcome| {
            format!("{}: {}", outcome.generator, outcome.error.as_deref().unwrap_or("ismeretlen"))
        })
        .collect()
}

fn run(
    name: &'static str,
    required: bool,
    generate: impl FnOnce() -> Result<Option<(PathBuf, bool)>>,
) -> Outcome {
    match generate() {
        Ok(written) => Outcome::ok(name, required, written),
        Err(err) => {
            if required {
                tracing::error!(
                    generator = name,
                    error = format!("{err:#}"),
                    "kotelezo generator hibara futott"
                );
            } else {
                tracing::warn!(
                    generator = name,
                    error = format!("{err:#}"),
                    "opcionalis generator kimaradt"
                );
            }
            Outcome::failed(name, required, &err)
        }
    }
}

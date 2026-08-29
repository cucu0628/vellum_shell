//! A Vellum Ink SDDM greeter theme.conf-ja.
//!
//! A repoban levo peldanyt mindig frissiti, a telepitett rendszerpeldanyt pedig
//! akkor, ha az irhato (az `sddm-install` a hivo felhasznalora chownolja).

use crate::theme::palette::Palette;
use crate::theme::paths;
use crate::theme::render::{Vars, load_template, render};
use anyhow::Result;
use std::path::{Path, PathBuf};

const BUILTIN: &str = include_str!("../../../templates/sddm-theme.conf.tmpl");

pub fn generate(palette: &Palette) -> Result<Option<(PathBuf, bool)>> {
    let template = load_template("sddm-theme.conf.tmpl", BUILTIN);
    let payload = render(&template, &vars(palette));

    let repo_copy = paths::shell_dir().join("sddm/vellum-ink/theme.conf");
    let system_copy = PathBuf::from("/usr/share/sddm/themes/vellum-ink/theme.conf");

    let changed = write_if_writable(&repo_copy, &payload)?;
    // A rendszerpeldany hianya vagy irasvedettsege nem hiba: a greeter tema
    // egyszeruen nincs telepitve.
    let _ = write_if_writable(&system_copy, &payload);

    Ok(Some((repo_copy, changed)))
}

fn vars(palette: &Palette) -> Vars {
    // A greeter azon a kepernyon mutatja a bejelentkezo kartyat, amelyiken a
    // lockscreen is bekeri a jelszot. Ures ertek eseten a rendszer elsodleges
    // kepernyoje dont.
    let input_screen = paths::read_line_file(&paths::lockscreen_monitor_file())
        .map(|value| value.chars().filter(|c| !c.is_whitespace()).collect())
        .unwrap_or_default();

    // A MUTED-ot a LIGHT_FOREGROUND felulirja, ha az kesobb all a fajlban --
    // a temak epp igy vannak megirva, ezert a sorrend szamit.
    let muted = palette.color(&["MUTED", "LIGHT_FOREGROUND"], "#9399b2");

    let mut vars = Vars::new();
    vars.insert("NAME".into(), palette.text(&["NAME"], "Vellum Shell"));
    vars.insert("INPUT_SCREEN".into(), input_screen);
    vars.insert("BACKGROUND".into(), palette.color(&["BACKGROUND"], "#1e1e2e"));
    vars.insert("FOREGROUND".into(), palette.color(&["FOREGROUND"], "#cdd6f4"));
    vars.insert("ACCENT".into(), palette.color(&["ACCENT", "BORDER_FOREGROUND"], "#89b4fa"));
    vars.insert("SURFACE".into(), palette.color(&["SURFACE"], "#181825"));
    vars.insert("MUTED".into(), muted);
    vars.insert("RED".into(), palette.color(&["RED"], "#d7472f"));
    vars
}

/// Helyben ir, hogy eleg legyen a fajlra kapott irasi jog (a mappa lehet root
/// tulajdonu). Ha nincs jogunk, csendben kihagyjuk.
fn write_if_writable(path: &Path, payload: &str) -> Result<bool> {
    if let Ok(existing) = std::fs::read_to_string(path) {
        if existing == payload {
            return Ok(false);
        }
        if std::fs::metadata(path).map(|m| m.permissions().readonly()).unwrap_or(true) {
            return Ok(false);
        }
        std::fs::write(path, payload)?;
        return Ok(true);
    }

    let Some(dir) = path.parent() else {
        return Ok(false);
    };
    if !dir.is_dir() {
        return Ok(false);
    }
    match std::fs::write(path, payload) {
        Ok(()) => Ok(true),
        Err(_) => Ok(false),
    }
}

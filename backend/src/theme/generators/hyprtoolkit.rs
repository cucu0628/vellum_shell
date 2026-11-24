//! hyprtoolkit paletta: ezt olvassa a Hyprland sajat GUI-ja (a kepernyomegosztas
//! valasztoja, a `hyprland-dialog` stb.).
//!
//! Minden hyprtoolkit app induleskor olvassa be a fajlt, a megosztasvalaszto
//! pedig keresenkent uj processz, ezert nincs mit ujratolteni.

use crate::theme::generators::icon;
use crate::theme::palette::Palette;
use crate::theme::render::{Vars, load_template, render, write_if_changed};
use crate::theme::{color, paths};
use anyhow::Result;
use std::path::PathBuf;

const BUILTIN: &str = include_str!("../../../templates/hyprtoolkit.conf.tmpl");

pub fn generate(palette: &Palette) -> Result<Option<(PathBuf, bool)>> {
    let output = paths::config_dir().join("hypr/hyprtoolkit.conf");
    let template = load_template("hyprtoolkit.conf.tmpl", BUILTIN);
    let mut vars = vars(palette);
    // Nem telepitett ikontema helyett inkabb a rendszer alapertelmezese.
    let icon_theme = icon::resolve(palette);
    let icon_theme = if icon::is_installed(&icon_theme) { icon_theme } else { String::new() };
    vars.insert("ICON_THEME".into(), icon_theme);
    let changed = write_if_changed(&output, &render(&template, &vars))?;
    Ok(Some((output, changed)))
}

fn vars(palette: &Palette) -> Vars {
    let background = palette.color(&["BACKGROUND"], "#1e1e2e");
    let foreground = palette.color(&["FOREGROUND"], "#cdd6f4");
    let accent = palette.color(&["ACCENT", "BORDER_FOREGROUND"], "#89b4fa");
    let surface = palette.color(&["SURFACE"], "#313244");
    let bright = palette.color_opt(&["BRIGHT_FOREGROUND"]).unwrap_or_else(|| foreground.clone());

    // A `base` a listasorok es gombok alapja: epp csak valjon el a hattertol,
    // a hover (`alternate_base`) pedig a shell feluleti szine legyen.
    let base = color::mix(&surface, &background, 45);
    // A masodlagos akcentus a fo akcentus visszafogott, hatter fele huzott valtozata.
    let accent_secondary = color::mix(&accent, &background, 60);

    let mut vars = Vars::new();
    vars.insert("BACKGROUND".into(), argb(&background));
    vars.insert("BASE".into(), argb(&base));
    vars.insert("ALTERNATE_BASE".into(), argb(&surface));
    vars.insert("TEXT".into(), argb(&foreground));
    vars.insert("BRIGHT_TEXT".into(), argb(&bright));
    vars.insert("LINK_TEXT".into(), argb(&accent));
    vars.insert("ACCENT".into(), argb(&accent));
    vars.insert("ACCENT_SECONDARY".into(), argb(&accent_secondary));
    vars
}

/// A hyprtoolkit a szineket egesz szamkent olvassa, `0xAARRGGBB` alakban.
fn argb(value: &str) -> String {
    match color::to_rgb(value) {
        Some((r, g, b)) => format!("0xFF{r:02X}{g:02X}{b:02X}"),
        None => "0xFFFF00FF".to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn colors_are_opaque_argb_integers() {
        let palette = Palette::parse(
            "ACCENT=#cba6f7\nBACKGROUND=#1e1e2e\nFOREGROUND=#cdd6f4\nSURFACE=#313244\n",
        );
        let values = vars(&palette);

        assert_eq!(values["BACKGROUND"], "0xFF1E1E2E");
        assert_eq!(values["ACCENT"], "0xFFCBA6F7");
        assert_eq!(values["ALTERNATE_BASE"], "0xFF313244");
        // Hianyzo BRIGHT_FOREGROUND eseten a sima eloter ugrik be.
        assert_eq!(values["BRIGHT_TEXT"], "0xFFCDD6F4");
        assert!(values.values().all(|v| v.len() == 10 && v.starts_with("0xFF")));
    }

    #[test]
    fn template_leaves_no_placeholder_unfilled() {
        let palette = Palette::parse("ACCENT=#ffffff\nBACKGROUND=#000000\n");
        let mut values = vars(&palette);
        values.insert("ICON_THEME".into(), String::new());
        let text = render(BUILTIN, &values);

        assert!(!text.contains("{{"), "{text}");
        assert!(text.contains("accent = 0xFFFFFFFF"));
    }
}

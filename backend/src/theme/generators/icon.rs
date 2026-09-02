//! Ikontema valasztasa es beallitasa.
//!
//! Ez az egyetlen generator, ami nem fajlt ir: a `gsettings` es a
//! `kwriteconfig6` az API. Temavaltaskor fut le egyszer, nem forro ut.

use crate::theme::palette::Palette;
use crate::theme::{color, paths};
use anyhow::Result;
use std::path::PathBuf;

pub fn generate(palette: &Palette) -> Result<Option<(PathBuf, bool)>> {
    let icon_theme = resolve(palette);

    // Ha a tema nincs telepitve, nem allitunk semmit -- kulonben eltunnenek az
    // ikonok.
    if !is_installed(&icon_theme) {
        tracing::debug!(icon_theme, "az ikontema nincs telepitve, kihagyva");
        return Ok(None);
    }

    if !crate::theme::side_effects_enabled() {
        return Ok(None);
    }

    run_quiet("gsettings", &["set", "org.gnome.desktop.interface", "icon-theme", &icon_theme]);
    run_quiet(
        "kwriteconfig6",
        &["--file", "kdeglobals", "--group", "Icons", "--key", "Theme", "--notify", &icon_theme],
    );

    let qt6ct = paths::config_dir().join("qt6ct/qt6ct.conf");
    if qt6ct.is_file() {
        run_quiet(
            "kwriteconfig6",
            &[
                "--file",
                &qt6ct.to_string_lossy(),
                "--group",
                "Appearance",
                "--key",
                "icon_theme",
                &icon_theme,
            ],
        );
    }

    Ok(None)
}

/// Az ICON_THEME kulcs, vagy -- ha hianyzik/`auto` -- az akcentus arnyalatabol
/// valasztott Yaru variáns.
pub fn resolve(palette: &Palette) -> String {
    let configured = palette.text(&["ICON_THEME"], "");
    if !configured.is_empty() && configured != "auto" {
        return configured;
    }

    let accent = palette.color(&["ACCENT", "BORDER_FOREGROUND"], "#89b4fa");
    let Some((hue, delta)) = color::hue_and_delta(&accent) else {
        return "Yaru-sage-dark".to_string();
    };

    // Arnyalat szerint valasztunk, nem nyers RGB-tavolsag alapjan: a Material
    // palettak vilagos, deszaturalt akcentusai kulonben bezsnek latszananak.
    if delta < 18 {
        return "Yaru-sage-dark".to_string();
    }

    match hue {
        h if !(15..345).contains(&h) => "Yaru-red-dark",
        h if h < 45 => "Yaru-wartybrown-dark",
        h if h < 80 => "Yaru-yellow-dark",
        h if h < 145 => "Yaru-olive-dark",
        h if h < 195 => "Yaru-prussiangreen-dark",
        h if h < 255 => "Yaru-blue-dark",
        h if h < 300 => "Yaru-purple-dark",
        _ => "Yaru-magenta-dark",
    }
    .to_string()
}

fn is_installed(name: &str) -> bool {
    let home = paths::home();
    [
        PathBuf::from("/usr/share/icons").join(name),
        home.join(".local/share/icons").join(name),
        home.join(".icons").join(name),
    ]
    .iter()
    .any(|path| path.is_dir())
}

fn run_quiet(program: &str, args: &[&str]) {
    crate::proc::run_quiet(program, args, crate::proc::SHORT);
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::theme::palette::Palette;

    fn icon_for(accent: &str) -> String {
        resolve(&Palette::parse(&format!("ACCENT={accent}\n")))
    }

    #[test]
    fn explicit_theme_wins() {
        let palette = Palette::parse("ICON_THEME=Papirus\nACCENT=#ff0000\n");
        assert_eq!(resolve(&palette), "Papirus");
    }

    #[test]
    fn auto_falls_through_to_hue_matching() {
        let palette = Palette::parse("ICON_THEME=auto\nACCENT=#ff0000\n");
        assert_eq!(resolve(&palette), "Yaru-red-dark");
    }

    #[test]
    fn desaturated_accent_uses_sage() {
        assert_eq!(icon_for("#808080"), "Yaru-sage-dark");
    }

    #[test]
    fn hue_buckets() {
        assert_eq!(icon_for("#ff0000"), "Yaru-red-dark");
        assert_eq!(icon_for("#00ff00"), "Yaru-olive-dark");
        assert_eq!(icon_for("#0000ff"), "Yaru-blue-dark");
    }
}

//! Ikontema valasztasa es beallitasa.
//!
//! Az alap egy kesz Yaru-variáns (vagy a tema `ICON_THEME` kulcsa). Erre epul
//! a generalt mappaikon-tema (`folder_icons`), ami csak a mappakat szinezi at
//! a palettaval; a `gsettings` es a `kwriteconfig6` ezt kapja meg. Ha a
//! generalas ki van kapcsolva vagy nem sikerul, az alap tema marad.
//! Temavaltaskor fut le egyszer, nem forro ut.

use crate::theme::generators::folder_icons;
use crate::theme::palette::Palette;
use crate::theme::{color, paths};
use anyhow::Result;
use std::path::PathBuf;

pub fn generate(palette: &Palette) -> Result<Option<(PathBuf, bool)>> {
    let base = resolve(palette);

    // Ha a tema nincs telepitve, nem allitunk semmit -- kulonben eltunnenek az
    // ikonok.
    if !is_installed(&base) {
        tracing::debug!(icon_theme = base, "az ikontema nincs telepitve, kihagyva");
        return Ok(None);
    }

    if !crate::theme::side_effects_enabled() {
        return Ok(None);
    }

    let root = folder_icons::icons_root();
    let folders = if folder_icons::enabled(palette) {
        match folder_icons::write_into(&root, palette, &base) {
            Ok(written) => Some(written),
            Err(err) => {
                tracing::warn!(
                    error = format!("{err:#}"),
                    "a mappaikonok nem generalhatok, marad az alap ikontema"
                );
                None
            }
        }
    } else {
        None
    };
    let icon_theme = folders.as_ref().map_or_else(|| base.clone(), |written| written.name.clone());

    apply(&icon_theme);

    // A regi nevet csak az atallitas utan toroljuk: addig meg az a hasznalt tema.
    folder_icons::remove_others(&root, folders.as_ref().map(|written| written.name.as_str()));

    Ok(folders.map(|written| (written.dir, written.changed)))
}

/// Beallitja az ikontemat a GTK-nak, a KDE-nek es a qt6ct-nek.
fn apply(icon_theme: &str) {
    run_quiet("gsettings", &["set", "org.gnome.desktop.interface", "icon-theme", icon_theme]);
    run_quiet(
        "kwriteconfig6",
        &["--file", "kdeglobals", "--group", "Icons", "--key", "Theme", "--notify", icon_theme],
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
                icon_theme,
            ],
        );
    }
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

pub fn is_installed(name: &str) -> bool {
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

//! GTK3/GTK4 (libadwaita) szinvaltozok.

use crate::theme::palette::Palette;
use crate::theme::render::{Vars, load_template, render, write_if_changed};
use crate::theme::{color, paths};
use anyhow::Result;
use std::path::PathBuf;
use std::process::{Command, Stdio};

const BUILTIN: &str = include_str!("../../../templates/gtk-theme.css.tmpl");

pub fn generate(palette: &Palette) -> Result<Option<(PathBuf, bool)>> {
    let output = paths::shell_dir().join("gtk-theme.css");
    let template = load_template("gtk-theme.css.tmpl", BUILTIN);
    let changed = write_if_changed(&output, &render(&template, &vars(palette)))?;

    // A portal-ujrainditas draga, es a valaszto elo elonezete percenkent
    // tobbszor is alkalmazhat temat. Valtozatlan CSS-nel nincs mit frissiteni.
    if changed && crate::theme::side_effects_enabled() {
        let _ = Command::new("gsettings")
            .args(["set", "org.gnome.desktop.interface", "color-scheme", "prefer-dark"])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status();

        // A portalok gyorsitotarazzak a temat; ujrainditas nelkul a GTK appok a
        // regi szineket mutatnak a kovetkezo bejelentkezesig.
        let _ = Command::new("systemctl")
            .args([
                "--user",
                "restart",
                "xdg-desktop-portal-gtk.service",
                "xdg-desktop-portal.service",
            ])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status();
    }

    Ok(Some((output, changed)))
}

fn vars(palette: &Palette) -> Vars {
    let background = palette.color(&["BACKGROUND"], "#1e1e2e");
    let foreground = palette.color(&["FOREGROUND"], "#cdd6f4");
    let accent = palette.color(&["ACCENT", "BORDER_FOREGROUND"], "#89b4fa");
    let surface = palette.color(&["SURFACE"], "#181825");
    let muted = palette.color(&["MUTED"], "#9399b2");

    let selection = palette.color_opt(&["SELECTION"]).unwrap_or_else(|| accent.clone());
    let dark_background =
        palette.color_opt(&["DARK_BACKGROUND"]).unwrap_or_else(|| background.clone());
    let lighter_background =
        palette.color_opt(&["LIGHTER_BACKGROUND"]).unwrap_or_else(|| surface.clone());
    let red = palette.color(&["RED"], "#ff5449");

    // A destruktiv/hiba szinek megtartjak a voros arnyalatot, de kovetik a temat.
    let error_background = color::mix(&red, &foreground, 55);
    let error_foreground = color::mix("#690005", &background, 70);

    // Vilagos akcentuson sotet, sotet akcentuson vilagos felirat.
    let accent_foreground =
        if color::luminance(&accent) >= 145 { background.clone() } else { foreground.clone() };

    let mut vars = Vars::new();
    vars.insert("BACKGROUND".into(), background);
    vars.insert("FOREGROUND".into(), foreground);
    vars.insert("ACCENT".into(), accent);
    vars.insert("SURFACE".into(), surface);
    vars.insert("MUTED".into(), muted);
    vars.insert("SELECTION".into(), selection);
    vars.insert("DARK_BACKGROUND".into(), dark_background);
    vars.insert("LIGHTER_BACKGROUND".into(), lighter_background);
    vars.insert("ERROR_BACKGROUND".into(), error_background);
    vars.insert("ERROR_FOREGROUND".into(), error_foreground);
    vars.insert("ACCENT_FOREGROUND".into(), accent_foreground);
    vars
}

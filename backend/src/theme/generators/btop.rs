//! btop szinsema.

use crate::theme::palette::Palette;
use crate::theme::render::{Vars, load_template, render, write_if_changed};
use crate::theme::{color, paths};
use anyhow::Result;
use std::path::PathBuf;

const BUILTIN: &str = include_str!("../../../templates/btop.theme.tmpl");

pub fn generate(palette: &Palette) -> Result<Option<(PathBuf, bool)>> {
    let output = paths::config_dir().join("btop/themes/vellum.theme");
    let template = load_template("btop.theme.tmpl", BUILTIN);
    let changed = write_if_changed(&output, &render(&template, &vars(palette)))?;
    Ok(Some((output, changed)))
}

fn vars(palette: &Palette) -> Vars {
    let background = palette.color(&["BACKGROUND"], "#1e1e2e");
    let foreground = palette.color(&["FOREGROUND"], "#cdd6f4");
    let accent = palette.color(&["ACCENT", "BORDER_FOREGROUND"], "#89b4fa");
    let surface = palette.color(&["SURFACE"], "#181825");
    let muted = palette.color(&["MUTED"], "#9399b2");

    // Ahol a paletta nem ad sajat erteket, a btop sajat arnyalatait az
    // akcentusbol keverjuk ki -- igy a szemantikus szinek is kovetik a temat.
    let graph_text = color::mix(&muted, &foreground, 70);
    let selection = palette.color_opt(&["SELECTION"]).unwrap_or_else(|| accent.clone());
    let cyan = palette.color_opt(&["CYAN"]).unwrap_or_else(|| color::mix(&accent, &foreground, 75));
    let green = palette.color_opt(&["GREEN"]).unwrap_or_else(|| color::mix("#a6e3a1", &accent, 70));
    let yellow =
        palette.color_opt(&["YELLOW"]).unwrap_or_else(|| color::mix("#f9e2af", &accent, 70));
    let orange =
        palette.color_opt(&["ORANGE"]).unwrap_or_else(|| color::mix("#fab387", &accent, 70));
    let red = palette.color_opt(&["RED"]).unwrap_or_else(|| color::mix("#f38ba8", &accent, 70));
    let magenta =
        palette.color_opt(&["MAGENTA"]).unwrap_or_else(|| color::mix("#cba6f7", &accent, 70));

    let mut vars = Vars::new();
    vars.insert("BACKGROUND".into(), background);
    vars.insert("FOREGROUND".into(), foreground);
    vars.insert("ACCENT".into(), accent);
    vars.insert("SURFACE".into(), surface);
    vars.insert("MUTED".into(), muted);
    vars.insert("GRAPH_TEXT".into(), graph_text);
    vars.insert("SELECTION".into(), selection);
    vars.insert("CYAN".into(), cyan);
    vars.insert("GREEN".into(), green);
    vars.insert("YELLOW".into(), yellow);
    vars.insert("ORANGE".into(), orange);
    vars.insert("RED".into(), red);
    vars.insert("MAGENTA".into(), magenta);
    vars
}

//! kitty terminal szinsema.

use crate::theme::palette::Palette;
use crate::theme::render::{Vars, load_template, render, write_if_changed};
use crate::theme::{color, paths};
use anyhow::Result;
use std::path::PathBuf;

const BUILTIN: &str = include_str!("../../../templates/kitty.conf.tmpl");

pub fn generate(palette: &Palette) -> Result<Option<(PathBuf, bool)>> {
    let output = paths::shell_dir().join("kitty-theme.conf");
    let template = load_template("kitty.conf.tmpl", BUILTIN);
    let changed = write_if_changed(&output, &render(&template, &vars(palette)))?;
    Ok(Some((output, changed)))
}

/// A szarmaztatott ertekek pontosan a korabbi bash script tartalekjait kovetik.
fn vars(palette: &Palette) -> Vars {
    let background = palette.color(&["BACKGROUND"], "#1e1e2e");
    let foreground = palette.color(&["FOREGROUND"], "#cdd6f4");
    let accent = palette.color(&["ACCENT", "BORDER_FOREGROUND"], "#89b4fa");
    let surface = palette.color(&["SURFACE"], "#181825");
    let muted = palette.color(&["MUTED"], "#9399b2");

    let selection = palette.color_opt(&["SELECTION"]).unwrap_or_else(|| accent.clone());
    let dark_background = palette
        .color_opt(&["DARK_BACKGROUND"])
        .unwrap_or_else(|| color::mix(&surface, &background, 70));
    let dark_foreground = palette.color_opt(&["DARK_FOREGROUND"]).unwrap_or_else(|| muted.clone());
    let bright_foreground = palette
        .color_opt(&["BRIGHT_FOREGROUND"])
        .unwrap_or_else(|| foreground.clone());
    let blue = palette.color_opt(&["BLUE"]).unwrap_or_else(|| accent.clone());

    let mut vars = Vars::new();
    vars.insert("BACKGROUND".into(), background);
    vars.insert("FOREGROUND".into(), foreground);
    vars.insert("ACCENT".into(), accent);
    vars.insert("SURFACE".into(), surface);
    vars.insert("MUTED".into(), muted);
    vars.insert("SELECTION".into(), selection);
    vars.insert("DARK_BACKGROUND".into(), dark_background);
    vars.insert("DARK_FOREGROUND".into(), dark_foreground);
    vars.insert("BRIGHT_FOREGROUND".into(), bright_foreground);
    vars.insert("BLUE".into(), blue);
    vars.insert("RED".into(), palette.color(&["RED"], "#f7768e"));
    vars.insert("GREEN".into(), palette.color(&["GREEN"], "#9ece6a"));
    vars.insert("YELLOW".into(), palette.color(&["YELLOW"], "#e0af68"));
    vars.insert("MAGENTA".into(), palette.color(&["MAGENTA"], "#bb9af7"));
    vars.insert("CYAN".into(), palette.color(&["CYAN"], "#7dcfff"));
    vars.insert("BRIGHT_RED".into(), palette.color(&["BRIGHT_RED"], "#ff8fa3"));
    vars.insert("BRIGHT_GREEN".into(), palette.color(&["BRIGHT_GREEN"], "#b9e87f"));
    vars.insert("BRIGHT_YELLOW".into(), palette.color(&["BRIGHT_YELLOW"], "#f4c97a"));
    vars.insert("BRIGHT_BLUE".into(), palette.color(&["BRIGHT_BLUE"], "#9bb8ff"));
    vars.insert("BRIGHT_MAGENTA".into(), palette.color(&["BRIGHT_MAGENTA"], "#d0afff"));
    vars.insert("BRIGHT_CYAN".into(), palette.color(&["BRIGHT_CYAN"], "#9de4ff"));
    vars
}

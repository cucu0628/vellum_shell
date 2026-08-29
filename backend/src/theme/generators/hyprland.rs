//! Hyprland ablakkeret-szinek (natív Lua konfiguracio).

use crate::theme::palette::Palette;
use crate::theme::render::{Vars, load_template, render, write_if_changed};
use crate::theme::{color, paths};
use anyhow::Result;
use std::path::PathBuf;

const BUILTIN: &str = include_str!("../../../templates/hyprland-colors.lua.tmpl");

pub fn generate(palette: &Palette) -> Result<Option<(PathBuf, bool)>> {
    let output = paths::config_dir().join("hypr/colors.lua");
    let template = load_template("hyprland-colors.lua.tmpl", BUILTIN);
    let changed = write_if_changed(&output, &render(&template, &vars(palette)))?;
    Ok(Some((output, changed)))
}

fn vars(palette: &Palette) -> Vars {
    let foreground = palette.color(&["FOREGROUND"], "#cdd6f4");
    let accent = palette.color(&["ACCENT", "BORDER_FOREGROUND"], "#89b4fa");
    let muted = palette.color(&["MUTED"], "#9399b2");
    let locked_accent = color::mix(&foreground, &accent, 55);

    // A Hyprland `rgb()` jelolese `#` nelkuli hexet var.
    let strip = |value: &str| value.trim_start_matches('#').to_string();

    let mut vars = Vars::new();
    vars.insert("ACTIVE".into(), strip(&accent));
    vars.insert("INACTIVE".into(), strip(&muted));
    vars.insert("LOCKED_ACTIVE".into(), strip(&locked_accent));
    vars
}

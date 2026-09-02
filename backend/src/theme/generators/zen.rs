//! Zen Browser: ket generalt stiluslap, plusz az aktiv profil bekotese.
//!
//! Ez a legtolakodobb generator -- a felhasznalo profiljaba ir --, ezert minden
//! muvelete idempotens es megorzo: a sajat `@import` sorunkat cserejuk, a tobbi
//! tartalmat erintetlenul hagyjuk.

use crate::theme::palette::Palette;
use crate::theme::render::{Vars, load_template, render, write_if_changed};
use crate::theme::{color, paths};
use anyhow::Result;
use std::path::{Path, PathBuf};

const BUILTIN_CHROME: &str = include_str!("../../../templates/zen-theme.css.tmpl");
const BUILTIN_CONTENT: &str = include_str!("../../../templates/zen-content-theme.css.tmpl");

pub fn generate(palette: &Palette) -> Result<Option<(PathBuf, bool)>> {
    let shell_dir = paths::shell_dir();
    let chrome_output = shell_dir.join("zen-theme.css");
    let content_output = shell_dir.join("zen-content-theme.css");

    let vars = vars(palette);
    let changed = write_if_changed(
        &chrome_output,
        &render(&load_template("zen-theme.css.tmpl", BUILTIN_CHROME), &vars),
    )?;
    // A belso about:newtab/about:home lapok nem oroklik a userChrome valtozoit,
    // ezert kell nekik kulon stiluslap.
    write_if_changed(
        &content_output,
        &render(&load_template("zen-content-theme.css.tmpl", BUILTIN_CONTENT), &vars),
    )?;

    install_into_profile(&chrome_output, &content_output)?;

    Ok(Some((chrome_output, changed)))
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
    let red = palette.color_opt(&["RED"]).unwrap_or_else(|| color::mix("#ff5449", &foreground, 70));
    let yellow =
        palette.color_opt(&["YELLOW"]).unwrap_or_else(|| color::mix(&foreground, &accent, 75));
    let orange =
        palette.color_opt(&["ORANGE"]).unwrap_or_else(|| color::mix(&accent, &foreground, 85));
    let green =
        palette.color_opt(&["GREEN"]).unwrap_or_else(|| color::mix(&muted, &foreground, 65));
    let cyan = palette.color_opt(&["CYAN"]).unwrap_or_else(|| accent.clone());
    let blue = palette.color_opt(&["BLUE"]).unwrap_or_else(|| color::mix(&accent, &foreground, 70));
    let magenta =
        palette.color_opt(&["MAGENTA"]).unwrap_or_else(|| color::mix(&accent, &background, 35));

    let primary = color::mix(&accent, &background, 45);
    let url_color = color::mix(&muted, &foreground, 75);
    let identity_pink = color::mix(&accent, &foreground, 55);

    let mut vars = Vars::new();
    vars.insert("SELECTION_TEXT".into(), foreground.clone());
    vars.insert("BACKGROUND".into(), background);
    vars.insert("FOREGROUND".into(), foreground);
    vars.insert("ACCENT".into(), accent);
    vars.insert("SURFACE".into(), surface);
    vars.insert("MUTED".into(), muted);
    vars.insert("SELECTION".into(), selection);
    vars.insert("DARK_BACKGROUND".into(), dark_background);
    vars.insert("LIGHTER_BACKGROUND".into(), lighter_background);
    vars.insert("RED".into(), red);
    vars.insert("YELLOW".into(), yellow);
    vars.insert("ORANGE".into(), orange);
    vars.insert("GREEN".into(), green);
    vars.insert("CYAN".into(), cyan);
    vars.insert("BLUE".into(), blue);
    vars.insert("MAGENTA".into(), magenta);
    vars.insert("PRIMARY".into(), primary);
    vars.insert("URL_COLOR".into(), url_color);
    vars.insert("IDENTITY_PINK".into(), identity_pink);
    vars
}

/// Bekoti a stiluslapokat az aktiv Zen profilba. Ha nincs Zen telepitve, ez
/// csendben kimarad -- nem hiba.
fn install_into_profile(chrome_output: &Path, content_output: &Path) -> Result<()> {
    let zen_root = paths::config_dir().join("zen");
    let Some(profile_dir) = default_profile(&zen_root) else {
        return Ok(());
    };

    // A Zen csak akkor olvassa a userChrome.css-t, ha ez a pref be van kapcsolva.
    set_user_prefs(&profile_dir)?;

    let chrome_dir = profile_dir.join("chrome");
    std::fs::create_dir_all(&chrome_dir)?;

    upsert_import(&chrome_dir.join("userChrome.css"), chrome_output, "/zen-theme.css\");")?;
    upsert_import(
        &chrome_dir.join("userContent.css"),
        content_output,
        "/zen-content-theme.css\");",
    )?;

    Ok(())
}

fn default_profile(zen_root: &Path) -> Option<PathBuf> {
    let installs = std::fs::read_to_string(zen_root.join("installs.ini")).ok()?;
    let profile = installs.lines().find_map(|line| {
        let (key, value) = line.split_once('=')?;
        (key.trim() == "Default").then(|| value.trim().to_string())
    })?;
    if profile.is_empty() {
        return None;
    }
    let dir = zen_root.join(profile);
    dir.is_dir().then_some(dir)
}

fn set_user_prefs(profile_dir: &Path) -> Result<()> {
    let user_js = profile_dir.join("user.js");
    let mut lines: Vec<String> = std::fs::read_to_string(&user_js)
        .map(|text| text.lines().map(str::to_string).collect())
        .unwrap_or_default();

    for (key, value) in [
        ("toolkit.legacyUserProfileCustomizations.stylesheets", "true"),
        ("ui.systemUsesDarkTheme", "1"),
        ("browser.theme.toolbar-theme", "0"),
        ("browser.theme.content-theme", "0"),
    ] {
        let prefix = format!("user_pref(\"{key}\",");
        let replacement = format!("user_pref(\"{key}\", {value});");
        let mut found = false;
        for line in lines.iter_mut() {
            if line.starts_with(&prefix) {
                *line = replacement.clone();
                found = true;
            }
        }
        if !found {
            lines.push(replacement);
        }
    }

    let mut contents = lines.join("\n");
    contents.push('\n');
    write_if_changed(&user_js, &contents)?;
    Ok(())
}

/// Kicsereli a sajat `@import` sorunkat, vagy ha nincs, a fajl elejere teszi.
/// A tobbi sort erintetlenul hagyja -- a felhasznalo sajat CSS-e megmarad.
fn upsert_import(target: &Path, stylesheet: &Path, suffix: &str) -> Result<()> {
    let import = format!("@import url(\"{}\");", stylesheet.display());
    let existing: Vec<String> = std::fs::read_to_string(target)
        .map(|text| text.lines().map(str::to_string).collect())
        .unwrap_or_default();

    let mut lines = Vec::with_capacity(existing.len() + 2);
    let mut found = false;
    for line in existing {
        if line.starts_with("@import url(\"") && line.ends_with(suffix) {
            lines.push(import.clone());
            found = true;
        } else {
            lines.push(line);
        }
    }

    if !found {
        lines.insert(0, String::new());
        lines.insert(0, import);
    }

    let mut contents = lines.join("\n");
    contents.push('\n');
    write_if_changed(target, &contents)?;
    Ok(())
}

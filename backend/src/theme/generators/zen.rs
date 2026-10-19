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

/// Ahol egy Zen telepites profiljai lehetnek: a nativ csomag (`~/.config/zen`,
/// regebben `~/.zen`) es a Flatpak (`~/.var/app/app.zen_browser.zen/.zen`).
fn profile_roots() -> Vec<PathBuf> {
    vec![
        paths::config_dir().join("zen"),
        paths::home().join(".zen"),
        paths::home().join(".var/app/app.zen_browser.zen/.zen"),
    ]
}

/// A profil `chrome` mappajaba masolt stiluslapok neve. A Flatpak sandbox nem
/// latja a shell mappajat, ezert a fajlok a profilba kerulnek, es onnan
/// relativ utvonallal importaljuk oket -- igy nem kell extra jogosultsag.
const CHROME_COPY: &str = "vellum-zen-theme.css";
const CONTENT_COPY: &str = "vellum-zen-content-theme.css";

/// Bekoti a stiluslapokat minden talalt Zen telepites alapertelmezett
/// profiljaba. Ha nincs Zen telepitve, ez csendben kimarad -- nem hiba.
fn install_into_profile(chrome_output: &Path, content_output: &Path) -> Result<()> {
    for zen_root in profile_roots() {
        let Some(profile_dir) = default_profile(&zen_root) else {
            continue;
        };

        // A Zen csak akkor olvassa a userChrome.css-t, ha ez a pref be van kapcsolva.
        set_user_prefs(&profile_dir)?;

        let chrome_dir = profile_dir.join("chrome");
        std::fs::create_dir_all(&chrome_dir)?;

        write_if_changed(&chrome_dir.join(CHROME_COPY), &std::fs::read_to_string(chrome_output)?)?;
        write_if_changed(&chrome_dir.join(CONTENT_COPY), &std::fs::read_to_string(content_output)?)?;

        upsert_import(&chrome_dir.join("userChrome.css"), CHROME_COPY, &["/zen-theme.css\");"])?;
        upsert_import(
            &chrome_dir.join("userContent.css"),
            CONTENT_COPY,
            &["/zen-content-theme.css\");"],
        )?;
    }

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

/// Kicsereli a sajat `@import` sorunkat, vagy ha nincs, a fajl elejere teszi
/// (az `@import`-nak minden mas szabaly elott kell allnia). A tobbi sort
/// erintetlenul hagyja -- a felhasznalo sajat CSS-e megmarad. A `legacy`
/// vegzodesu regi importok (abszolut ut a shell mappajaba) is a mieink: ezeket
/// az uj, relativ sorra csereljuk.
fn upsert_import(target: &Path, file_name: &str, legacy: &[&str]) -> Result<()> {
    let import = format!("@import url(\"{file_name}\");");
    let existing: Vec<String> = std::fs::read_to_string(target)
        .map(|text| text.lines().map(str::to_string).collect())
        .unwrap_or_default();

    let ours = |line: &str| {
        line.starts_with("@import url(\"")
            && (line == import || legacy.iter().any(|suffix| line.ends_with(suffix)))
    };

    let mut lines = Vec::with_capacity(existing.len() + 2);
    let mut found = false;
    for line in existing {
        if ours(&line) {
            if !found {
                lines.push(import.clone());
                found = true;
            }
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

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_file(name: &str, contents: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("vellum-zen-test-{}-{name}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("userChrome.css");
        std::fs::write(&path, contents).unwrap();
        path
    }

    #[test]
    fn import_goes_first_and_keeps_user_css() {
        let path = temp_file("first", "#nav-bar { color: red; }\n");
        upsert_import(&path, CHROME_COPY, &["/zen-theme.css\");"]).unwrap();
        let text = std::fs::read_to_string(&path).unwrap();
        assert!(text.starts_with("@import url(\"vellum-zen-theme.css\");"), "{text}");
        assert!(text.contains("#nav-bar { color: red; }"));
    }

    #[test]
    fn legacy_absolute_import_is_replaced_once() {
        let path = temp_file(
            "legacy",
            "@import url(\"/home/x/.config/quickshell/vellum_shell/zen-theme.css\");\n\n#a {}\n",
        );
        upsert_import(&path, CHROME_COPY, &["/zen-theme.css\");"]).unwrap();
        upsert_import(&path, CHROME_COPY, &["/zen-theme.css\");"]).unwrap();
        let text = std::fs::read_to_string(&path).unwrap();
        assert_eq!(text.matches("@import").count(), 1, "{text}");
        assert!(text.starts_with("@import url(\"vellum-zen-theme.css\");"));
    }
}

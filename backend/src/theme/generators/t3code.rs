//! T3 Code tema: a desktop app "environment theme" mappajaba publikalt JSON.
//!
//! A T3 Code szervere figyeli a `<T3CODE_HOME>/userdata/themes` mappat, es a
//! benne levo `<id>.json` fajlokat elo kozvetiti a kliensek fele -- igy egy
//! temavaltas ujrainditas nelkul atszinezi az appot. A kliens a `settings.json`
//! `defaultTheme` mezojet alkalmazza (egyszer, a `defaultThemeSetAt` szerint);
//! ezt csak akkor allitjuk be, ha meg nincs kornyezeti tema, hogy a
//! felhasznalo kesobbi, appon beluli valasztasat ne irjuk felul.

use crate::modules::calendar::format_rfc3339_utc;
use crate::theme::palette::Palette;
use crate::theme::render::{stage, write_if_changed};
use crate::theme::{color, paths};
use anyhow::{Context, Result, bail};
use serde::Serialize;
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

/// A publikalt tema azonositoja: a fajlnev es a `defaultTheme` erteke.
pub const THEME_ID: &str = "vellum";

pub fn generate(palette: &Palette) -> Result<Option<(PathBuf, bool)>> {
    let base = base_dir();
    // Nincs telepitett T3 Code: nincs mit temazni.
    if !base.is_dir() {
        return Ok(None);
    }
    let state_dir = base.join("userdata");
    let output = state_dir.join("themes").join(format!("{THEME_ID}.json"));
    let changed = write_if_changed(&output, &render(palette)?)?;
    adopt_as_default(&state_dir.join("settings.json"))?;
    Ok(Some((output, changed)))
}

/// A T3 Code sajat feloldasa: `T3CODE_HOME`, kulonben `~/.t3`.
fn base_dir() -> PathBuf {
    match std::env::var_os("T3CODE_HOME") {
        Some(dir) if !dir.to_string_lossy().trim().is_empty() => PathBuf::from(dir),
        _ => paths::home().join(".t3"),
    }
}

#[derive(Serialize)]
struct ThemeFile<'a> {
    version: u8,
    name: &'a str,
    appearance: &'a str,
    /// A T3 ezekbol szarmaztatja a teljes palettat, a `colors` csak felulir --
    /// igy egy kesobb bevezetett szerep sem marad szinezetlen.
    canvas: String,
    accent: String,
    colors: BTreeMap<&'static str, String>,
}

fn render(palette: &Palette) -> Result<String> {
    let colors = colors(palette);
    let file = ThemeFile {
        version: 1,
        name: "Vellum",
        appearance: appearance(palette),
        canvas: colors["canvas"].clone(),
        accent: colors["accent"].clone(),
        colors,
    };
    Ok(serde_json::to_string_pretty(&file)? + "\n")
}

/// A T3 tema `light` vagy `dark`. A paletta MODE mezoje hianyozhat: olyankor
/// a hatter vilagossaga dont, mint a Neovim generatornal.
fn appearance(palette: &Palette) -> &'static str {
    match palette.text(&["MODE"], "").to_ascii_lowercase().as_str() {
        "light" => "light",
        "dark" => "dark",
        _ if color::luminance(&palette.color(&["BACKGROUND"], "#1e1e2e")) > 127 => "light",
        _ => "dark",
    }
}

/// A Vellum paletta leképezése a T3 Code szinszerepeire.
fn colors(palette: &Palette) -> BTreeMap<&'static str, String> {
    let light = appearance(palette) == "light";
    let bg = palette.color(&["BACKGROUND"], "#1e1e2e");
    let fg = palette.color(&["FOREGROUND"], "#cdd6f4");
    let accent = palette.color(&["ACCENT", "BORDER_FOREGROUND"], "#89b4fa");
    // Ugyanaz a feloldas, mint a shell `muted` szine (lasd `theme::summarize`).
    let muted = palette.color(&["MUTED", "LIGHT_FOREGROUND"], "#9399b2");
    let shade = if light { "#ffffff" } else { "#000000" };
    let deep =
        palette.color_opt(&["DARK_BACKGROUND"]).unwrap_or_else(|| color::mix(&bg, shade, 80));
    let raised = palette
        .color_opt(&["LIGHTER_BACKGROUND", "SURFACE"])
        .unwrap_or_else(|| color::mix(&fg, &bg, 10));
    let selection =
        palette.color_opt(&["SELECTION"]).unwrap_or_else(|| color::mix(&accent, &bg, 25));
    let red = palette.color(&["RED"], "#f38ba8");
    let yellow = palette.color(&["YELLOW"], "#f9e2af");
    let warning = palette.color(&["ORANGE", "YELLOW"], "#fab387");

    // A paneleket csak epp emeljuk el a vaszontol, mint a shell kartyait.
    let surface = color::mix(&raised, &bg, 45);
    let surface_raised = color::mix(&raised, &bg, 65);
    let border = color::mix(&fg, &bg, 16);
    let input = color::mix(&fg, &bg, 22);
    let on_accent = if color::luminance(&accent) >= 145 { deep.clone() } else { fg.clone() };
    let tint = |base: &str, weight: u32| color::mix(base, &bg, weight);

    let mut map = BTreeMap::new();
    let mut set = |key: &'static str, value: &str| {
        map.insert(key, value.to_string());
    };

    set("canvas", &bg);
    set("chrome", &bg);
    set("toolbar", &bg);
    set("toolbarForeground", &fg);
    set("toolbarBorder", &border);
    set("toolbarControl", &surface);
    set("toolbarControlForeground", &fg);
    set("toolbarControlHover", &surface_raised);

    set("surface", &surface);
    set("surfaceRaised", &surface_raised);
    set("surfaceOverlay", &surface_raised);
    set("text", &fg);
    set("textMuted", &muted);
    set("border", &border);
    set("input", &input);
    set("focus", &accent);
    set("accent", &accent);
    set("accentForeground", &on_accent);

    set("secondary", &surface);
    set("secondaryForeground", &fg);
    set("muted", &surface);
    set("mutedForeground", &muted);
    set("placeholder", &color::mix(&muted, &bg, 75));
    set("secondaryLabel", &muted);
    set("iconMuted", &muted);

    set("error", &red);
    set("errorForeground", &color::mix(&red, &fg, 85));
    set("errorSurface", &tint(&red, 16));
    set("warning", &warning);
    set("warningForeground", &yellow);
    set("warningSurface", &tint(&warning, 16));
    set("update", &accent);
    set("updateForeground", &color::mix(&accent, &fg, 85));
    set("updateSurface", &tint(&accent, 16));

    set("accentSurface", &tint(&accent, 14));
    set("accentSurfaceForeground", &fg);
    set("messageSurface", &raised);
    set("messageForeground", &fg);
    set("messageAction", &accent);
    set("messageActionForeground", &on_accent);
    set("messageActionHover", &color::mix(&accent, &fg, 85));
    set("codeBackground", &deep);
    set("codeForeground", &fg);

    set("searchMatchBackground", &tint(&yellow, 35));
    set("searchMatchForeground", &fg);
    set("searchMatchActiveBackground", &warning);
    set("searchMatchActiveForeground", &deep);

    set("sidebar", &deep);
    set("sidebarForeground", &fg);
    set("sidebarMutedForeground", &muted);
    set("sidebarControlSurface", &color::mix(&raised, &deep, 50));
    set("sidebarRowHover", &color::mix(&raised, &deep, 45));
    set("sidebarRowActive", &color::mix(&raised, &deep, 70));
    set("sidebarRowSelected", &selection);
    set("sidebarBorder", &color::mix(&border, &deep, 60));

    set("terminalBackground", &bg);
    set("terminalForeground", &fg);
    set("terminalCursor", &accent);
    set("terminalSelection", &selection);
    set("terminalScrollbar", &tint(&fg, 15));
    set("terminalScrollbarHover", &tint(&fg, 28));

    map
}

/// Beallitja a Vellum temat a T3 kornyezeti alapertelmezesekent, ha meg nincs
/// ilyen. A meglevo `settings.json`-t szovegesen bovitjuk, hogy a T3 sajat
/// kulcssorrendje es formazasa megmaradjon; ervenytelen fajlhoz nem nyulunk.
fn adopt_as_default(settings: &Path) -> Result<()> {
    let raw = match std::fs::read_to_string(settings) {
        Ok(raw) => raw,
        Err(err) if err.kind() == std::io::ErrorKind::NotFound => String::new(),
        Err(err) => {
            return Err(err).with_context(|| format!("nem olvashato: {}", settings.display()));
        }
    };
    let set_at = format_rfc3339_utc(
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|elapsed| elapsed.as_secs() as i64)
            .unwrap_or(0),
    );
    let Some(next) = with_default_theme(&raw, &set_at)? else {
        return Ok(());
    };
    stage(settings, &next)?.commit()
}

/// Az uj `settings.json` tartalom, vagy `None`, ha mar van kornyezeti tema.
fn with_default_theme(raw: &str, set_at: &str) -> Result<Option<String>> {
    let entries = format!(
        "\"defaultTheme\": {},\n  \"defaultThemeSetAt\": {}",
        serde_json::to_string(THEME_ID)?,
        serde_json::to_string(set_at)?
    );
    if raw.trim().is_empty() {
        return Ok(Some(format!("{{\n  {entries}\n}}\n")));
    }

    let parsed: serde_json::Value =
        serde_json::from_str(raw).context("a T3 Code settings.json nem ervenyes JSON")?;
    let Some(object) = parsed.as_object() else {
        bail!("a T3 Code settings.json nem objektum");
    };
    if object.get("defaultTheme").and_then(|value| value.as_str()).is_some_and(|v| !v.is_empty()) {
        return Ok(None);
    }
    if object.contains_key("defaultTheme") || object.contains_key("defaultThemeSetAt") {
        // Ures vagy furcsa ertek: a szoveges beszuras duplikalt kulcsot adna.
        return Ok(None);
    }

    let close = raw.rfind('}').context("a T3 Code settings.json nem objektum")?;
    let head = raw[..close].trim_end();
    let separator = if head.ends_with('{') { "" } else { "," };
    let next = format!("{head}{separator}\n  {entries}\n}}{}", &raw[close + 1..]);
    // Biztonsagi halo: csak ervenyes JSON-t irunk vissza.
    serde_json::from_str::<serde_json::Value>(&next)
        .context("a bovitett settings.json ervenytelen")?;
    Ok(Some(next))
}

#[cfg(test)]
mod tests {
    use super::*;

    const MOCHA: &str = "MODE=dark\nACCENT=#cba6f7\nSELECTION=#45475a\nMUTED=#9399b2\n\
        BACKGROUND=#1e1e2e\nDARK_BACKGROUND=#181825\nLIGHTER_BACKGROUND=#313244\n\
        FOREGROUND=#cdd6f4\nLIGHT_FOREGROUND=#bac2de\nRED=#f38ba8\nYELLOW=#f9e2af\n";

    fn is_hex(value: &str) -> bool {
        value.len() == 7
            && value.starts_with('#')
            && value[1..].chars().all(|c| c.is_ascii_hexdigit())
    }

    #[test]
    fn theme_file_matches_the_t3_schema() {
        let text = render(&Palette::parse(MOCHA)).unwrap();
        let json: serde_json::Value = serde_json::from_str(&text).unwrap();

        assert_eq!(json["version"], 1);
        assert_eq!(json["name"], "Vellum");
        assert_eq!(json["appearance"], "dark");
        assert_eq!(json["canvas"], "#1e1e2e");
        assert_eq!(json["accent"], "#cba6f7");
        let colors = json["colors"].as_object().unwrap();
        assert!(colors.len() >= 60, "{}", colors.len());
        for (key, value) in colors {
            assert!(key.chars().next().unwrap().is_ascii_alphabetic(), "{key}");
            assert!(is_hex(value.as_str().unwrap()), "{key}={value}");
        }
        assert_eq!(colors["sidebar"], "#181825");
        assert_eq!(colors["textMuted"], "#bac2de");
        assert_eq!(colors["sidebarRowSelected"], "#45475a");
        // A T3 32 KiB folotti temafajlt nem publikal.
        assert!(text.len() < 32 * 1024);
    }

    #[test]
    fn appearance_falls_back_to_the_background_luminance() {
        assert_eq!(appearance(&Palette::parse("BACKGROUND=#fafafa\n")), "light");
        assert_eq!(appearance(&Palette::parse("BACKGROUND=#101010\n")), "dark");
        assert_eq!(appearance(&Palette::parse("MODE=light\nBACKGROUND=#101010\n")), "light");
    }

    #[test]
    fn bright_accent_gets_dark_text() {
        let colors = colors(&Palette::parse(MOCHA));
        assert_eq!(colors["accentForeground"], "#181825");
        let colors = colors_for("ACCENT=#1b4ed8\nBACKGROUND=#000000\nFOREGROUND=#ffffff\n");
        assert_eq!(colors["accentForeground"], "#ffffff");
    }

    fn colors_for(text: &str) -> BTreeMap<&'static str, String> {
        colors(&Palette::parse(text))
    }

    #[test]
    fn default_theme_is_added_preserving_existing_keys() {
        let raw = "{\n  \"favorites\": [],\n  \"defaultRuntimeMode\": \"auto\"\n}\n";
        let next = with_default_theme(raw, "2026-11-17T00:00:00Z").unwrap().unwrap();

        assert!(next.starts_with("{\n  \"favorites\": [],\n  \"defaultRuntimeMode\": \"auto\","));
        let json: serde_json::Value = serde_json::from_str(&next).unwrap();
        assert_eq!(json["defaultTheme"], "vellum");
        assert_eq!(json["defaultThemeSetAt"], "2026-11-17T00:00:00Z");
        assert_eq!(json["defaultRuntimeMode"], "auto");
        assert!(next.ends_with("}\n"));
    }

    #[test]
    fn default_theme_handles_empty_files_and_objects() {
        for raw in ["", "{}", "{ }\n"] {
            let next = with_default_theme(raw, "t").unwrap().unwrap();
            let json: serde_json::Value = serde_json::from_str(&next).unwrap();
            assert_eq!(json["defaultTheme"], "vellum", "{raw:?}");
        }
    }

    #[test]
    fn existing_default_theme_is_left_alone() {
        let raw = "{\"defaultTheme\": \"ocean\", \"defaultThemeSetAt\": \"x\"}";
        assert!(with_default_theme(raw, "t").unwrap().is_none());
    }

    #[test]
    fn invalid_settings_are_not_rewritten() {
        assert!(with_default_theme("{ nope", "t").is_err());
        assert!(with_default_theme("[1, 2]", "t").is_err());
    }
}

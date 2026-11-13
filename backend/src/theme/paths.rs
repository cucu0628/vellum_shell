//! A backend altal ismert utvonalak.
//!
//! Minden a `VELLUM_SHELL_DIR`-bol szarmazik, ami alapertelmezesben a repo
//! helye. A tesztek ezt allitjak at egy homokozora, igy sosem nyulnak az eles
//! konfiguraciohoz.

use std::path::PathBuf;

pub fn home() -> PathBuf {
    std::env::var_os("HOME").map(PathBuf::from).unwrap_or_else(|| PathBuf::from("/"))
}

pub fn shell_dir() -> PathBuf {
    match std::env::var_os("VELLUM_SHELL_DIR") {
        Some(dir) if !dir.is_empty() => PathBuf::from(dir),
        _ => home().join(".config/quickshell/vellum_shell"),
    }
}

pub fn themes_dir() -> PathBuf {
    shell_dir().join("themes")
}

pub fn theme_conf(slug: &str) -> PathBuf {
    themes_dir().join(slug).join("theme.conf")
}

pub fn templates_dir() -> PathBuf {
    shell_dir().join("backend/templates")
}

pub fn current_theme_file() -> PathBuf {
    shell_dir().join("current-theme")
}

pub fn current_wallpaper_file() -> PathBuf {
    shell_dir().join("current-wallpaper")
}

/// A shell egyesitett beallitasfajlja. A QML `core/SettingsStore.qml` irja; a
/// backend csak olvas belole.
pub fn settings_file() -> PathBuf {
    shell_dir().join("settings.json")
}

pub fn config_dir() -> PathBuf {
    match std::env::var_os("XDG_CONFIG_HOME") {
        Some(dir) if !dir.is_empty() => PathBuf::from(dir),
        _ => home().join(".config"),
    }
}

/// XDG allapotmappa (pl. a vagolap-elozmeny helye).
pub fn state_dir() -> PathBuf {
    match std::env::var_os("XDG_STATE_HOME") {
        Some(dir) if !dir.is_empty() => PathBuf::from(dir),
        _ => home().join(".local/state"),
    }
}

/// XDG adatmappa. A Neovim `site` konyvtara ide esik.
pub fn data_dir() -> PathBuf {
    match std::env::var_os("XDG_DATA_HOME") {
        Some(dir) if !dir.is_empty() => PathBuf::from(dir),
        _ => home().join(".local/share"),
    }
}

/// A generalt Neovim colorscheme. A `site` mappa a runtimepath resze, tehat a
/// `:colorscheme vellum` innen is betoltodik, a felhasznalo nvim configja
/// viszont generalt fajl nelkul marad.
pub fn nvim_colorscheme() -> PathBuf {
    data_dir().join("nvim/site/colors/vellum.lua")
}

pub fn hypr_dir() -> PathBuf {
    config_dir().join("hypr")
}

/// A settings app perzisztalt beallitasai. Ez az igazsag forrasa; a Lua
/// modulok ebbol generalodnak.
pub fn hypr_settings_file() -> PathBuf {
    hypr_dir().join("vellum-settings.json")
}

/// Generalt monitor-modul. A `hyprland.lua` require-listajanak a vegen ul.
pub fn hypr_display_module() -> PathBuf {
    hypr_dir().join("vellum_display.lua")
}

/// Generalt kompozitor-opcio modul.
pub fn hypr_tuning_module() -> PathBuf {
    hypr_dir().join("vellum_tuning.lua")
}

/// Egy szoveges beallitas a `settings.json`-bol (`szekcio.kulcs`). Hianyzo
/// fajl, hibas JSON, nem szoveges vagy ures ertek: `None`.
pub fn read_setting(section: &str, key: &str) -> Option<String> {
    setting_from(&std::fs::read_to_string(settings_file()).ok()?, section, key)
}

fn setting_from(text: &str, section: &str, key: &str) -> Option<String> {
    let root: serde_json::Value = serde_json::from_str(text).ok()?;
    let value = root.get(section)?.get(key)?.as_str()?.trim();
    if value.is_empty() { None } else { Some(value.to_string()) }
}

/// Egy soros allapotfajl olvasasa (`current-theme` es tarsai).
pub fn read_line_file(path: &std::path::Path) -> Option<String> {
    let text = std::fs::read_to_string(path).ok()?;
    let value = text.trim().to_string();
    if value.is_empty() { None } else { Some(value) }
}

#[cfg(test)]
mod tests {
    use super::setting_from;

    #[test]
    fn setting_is_read_from_its_section() {
        let text = r#"{"version": 1, "weather": {"location": "  Veszprem "}}"#;
        assert_eq!(setting_from(text, "weather", "location").as_deref(), Some("Veszprem"));
    }

    #[test]
    fn missing_blank_or_malformed_settings_are_none() {
        assert_eq!(setting_from(r#"{"weather": {}}"#, "weather", "location"), None);
        assert_eq!(setting_from(r#"{"weather": {"location": " "}}"#, "weather", "location"), None);
        assert_eq!(setting_from(r#"{"weather": {"location": 3}}"#, "weather", "location"), None);
        assert_eq!(setting_from("{not json", "weather", "location"), None);
    }
}

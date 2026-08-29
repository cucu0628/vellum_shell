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

pub fn lockscreen_monitor_file() -> PathBuf {
    shell_dir().join("lockscreen-monitor")
}

pub fn config_dir() -> PathBuf {
    match std::env::var_os("XDG_CONFIG_HOME") {
        Some(dir) if !dir.is_empty() => PathBuf::from(dir),
        _ => home().join(".config"),
    }
}

/// Egy soros allapotfajl olvasasa (`current-theme` es tarsai).
pub fn read_line_file(path: &std::path::Path) -> Option<String> {
    let text = std::fs::read_to_string(path).ok()?;
    let value = text.trim().to_string();
    if value.is_empty() { None } else { Some(value) }
}

//! A `theme.conf` beolvasasa es irasa.
//!
//! A formatum lapos `KULCS=ertek`, kommentekkel es ures sorokkal. A bash
//! scriptek `while IFS='=' read -r key value` szerkezettel olvassak, ami az
//! ELSO `=` menten vag, es minden talalatnal felulirja a valtozot -- tehat a
//! fajlban KESOBB allo sor nyer. A `resolve` pontosan ezt a szemantikat koveti,
//! kulonben a kimenet elterne a golden baseline-tol.

use crate::theme::color;
use anyhow::{Context, Result};
use serde::Serialize;
use std::collections::BTreeMap;
use std::path::Path;

#[derive(Debug, Clone, Default)]
pub struct Palette {
    /// Fajlbeli sorrendben. Nem map: az aliasolt kulcsok (pl. ACCENT es
    /// BORDER_FOREGROUND) kozott a sorrend dont.
    entries: Vec<(String, String)>,
}

impl Palette {
    pub fn parse(text: &str) -> Self {
        let mut entries = Vec::new();
        for line in text.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with('#') {
                continue;
            }
            let Some((key, value)) = trimmed.split_once('=') else {
                continue;
            };
            entries.push((key.chars().filter(|c| !c.is_whitespace()).collect(), value.to_string()));
        }
        Self { entries }
    }

    pub fn load(path: &Path) -> Result<Self> {
        let text = std::fs::read_to_string(path)
            .with_context(|| format!("nem olvashato: {}", path.display()))?;
        Ok(Self::parse(&text))
    }

    /// Az adott kulcsok kozul a fajlban UTOLSOKENT szereplo ertek.
    fn resolve(&self, keys: &[&str]) -> Option<&str> {
        self.entries
            .iter()
            .rev()
            .find(|(key, _)| keys.contains(&key.as_str()))
            .map(|(_, value)| value.as_str())
    }

    /// Szin ertek. A bash `value=${value//[[:space:]\"]/}` MINDEN whitespace-t
    /// es idezojelet eltavolit, majd a validalas kesobb tortenik -- tehat ha az
    /// utolso elofordulas ervenytelen, az alapertelmezes nyer, nem egy korabbi
    /// ervenyes ertek.
    pub fn color(&self, keys: &[&str], default: &str) -> String {
        self.resolve(keys)
            .map(strip_all_whitespace_and_quotes)
            .filter(|value| color::is_valid(value))
            .unwrap_or_else(|| default.to_string())
    }

    /// Ugyanaz, de alapertelmezes nelkul.
    pub fn color_opt(&self, keys: &[&str]) -> Option<String> {
        self.resolve(keys)
            .map(strip_all_whitespace_and_quotes)
            .filter(|value| color::is_valid(value))
    }

    /// Szoveges ertek. A belso szokozok megmaradnak (a NAME miatt: "Kanagawa
    /// Wave"), csak a szeleket es az idezojeleket vagjuk le -- ez a `theme-list`
    /// `tr -d '"' | xargs` viselkedese.
    pub fn text(&self, keys: &[&str], default: &str) -> String {
        self.resolve(keys)
            .map(|value| value.replace('"', "").trim().to_string())
            .filter(|value| !value.is_empty())
            .unwrap_or_else(|| default.to_string())
    }

    pub fn set(&mut self, key: &str, value: impl Into<String>) {
        let value = value.into();
        for (existing, slot) in self.entries.iter_mut() {
            if existing == key {
                *slot = value;
                return;
            }
        }
        self.entries.push((key.to_string(), value));
    }

    /// A shellnek kuldott JSON. Minden kulcsot atadunk, hogy a QML oldal ne
    /// legyen 6 szinre korlatozva, ahogy a regi ThemeStore volt.
    pub fn to_json(&self) -> BTreeMap<String, String> {
        self.entries
            .iter()
            .map(|(key, value)| (key.clone(), value.replace('"', "").trim().to_string()))
            .collect()
    }
}

/// camelCase, mert a fogyasztoja QML/JavaScript.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ThemeSummary {
    pub name: String,
    pub slug: String,
    pub background: String,
    pub foreground: String,
    pub accent: String,
    pub surface: String,
    pub muted: String,
    pub kind: String,
    pub icon_theme: String,
    pub current: bool,
}

fn strip_all_whitespace_and_quotes(value: &str) -> String {
    value.chars().filter(|c| !c.is_whitespace() && *c != '"').collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn later_entry_wins() {
        let palette = Palette::parse("ACCENT=#111111\nACCENT=#222222\n");
        assert_eq!(palette.color(&["ACCENT"], "#000000"), "#222222");
    }

    #[test]
    fn alias_resolution_follows_file_order() {
        let palette = Palette::parse("ACCENT=#111111\nBORDER_FOREGROUND=#222222\n");
        assert_eq!(palette.color(&["ACCENT", "BORDER_FOREGROUND"], "#000000"), "#222222");

        let palette = Palette::parse("BORDER_FOREGROUND=#222222\nACCENT=#111111\n");
        assert_eq!(palette.color(&["ACCENT", "BORDER_FOREGROUND"], "#000000"), "#111111");
    }

    #[test]
    fn invalid_last_value_falls_back_to_default_not_earlier_value() {
        let palette = Palette::parse("ACCENT=#111111\nACCENT=szemet\n");
        assert_eq!(palette.color(&["ACCENT"], "#000000"), "#000000");
    }

    #[test]
    fn name_keeps_internal_spaces() {
        let palette = Palette::parse("NAME=Kanagawa Wave\n");
        assert_eq!(palette.text(&["NAME"], ""), "Kanagawa Wave");
    }

    #[test]
    fn comments_and_blanks_ignored() {
        let palette = Palette::parse("# komment\n\nACCENT=#abcdef\n");
        assert_eq!(palette.color(&["ACCENT"], "#000000"), "#abcdef");
    }
}

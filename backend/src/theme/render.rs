//! Minimalis sablonmotor es atomikus fajlkiiras.
//!
//! A sablonok `{{KULCS}}` helyorzoket tartalmaznak. Futasidoben a
//! `backend/templates/` mappabol olvassuk oket, hogy testreszabhatoak legyenek
//! ujraforditas nelkul; ha egy sablon hianyzik, a binarisba fordított valtozat
//! ugrik be, igy a temazas sosem tud eltorni.

use crate::theme::paths;
use anyhow::{Context, Result};
use std::collections::BTreeMap;
use std::path::Path;

pub type Vars = BTreeMap<String, String>;

pub fn render(template: &str, vars: &Vars) -> String {
    let mut out = String::with_capacity(template.len());
    let mut rest = template;

    while let Some(start) = rest.find("{{") {
        out.push_str(&rest[..start]);
        let after = &rest[start + 2..];
        let Some(end) = after.find("}}") else {
            // Lezaratlan helyorzo: szo szerint atengedjuk.
            out.push_str(&rest[start..]);
            return out;
        };
        let key = after[..end].trim();
        match vars.get(key) {
            Some(value) => out.push_str(value),
            // Ismeretlen kulcsot meghagyunk, hogy lathato legyen a hiba.
            None => {
                out.push_str("{{");
                out.push_str(&after[..end]);
                out.push_str("}}");
            }
        }
        rest = &after[end + 2..];
    }

    out.push_str(rest);
    out
}

/// Betolti a sablont a lemezrol, vagy visszaesik a beepitett valtozatra.
pub fn load_template(name: &str, builtin: &str) -> String {
    let path = paths::templates_dir().join(name);
    match std::fs::read_to_string(&path) {
        Ok(text) => text,
        Err(_) => builtin.to_string(),
    }
}

/// Atomikus iras: ideiglenes fajl ugyanabban a mappaban, majd rename.
/// Ha a tartalom valtozatlan, nem irunk -- ez a bash `cmp -s` viselkedese, es
/// megkimeli a fajlfigyeloket a felesleges ebresztestol.
pub fn write_if_changed(path: &Path, contents: &str) -> Result<bool> {
    if let Ok(existing) = std::fs::read_to_string(path)
        && existing == contents
    {
        return Ok(false);
    }

    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)
            .with_context(|| format!("nem hozhato letre a mappa: {}", parent.display()))?;
    }

    let tmp = path.with_extension(format!("vellum-tmp-{}", std::process::id()));
    std::fs::write(&tmp, contents).with_context(|| format!("nem irhato: {}", tmp.display()))?;
    std::fs::rename(&tmp, path)
        .with_context(|| format!("nem nevezheto at ide: {}", path.display()))?;
    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn vars() -> Vars {
        let mut vars = Vars::new();
        vars.insert("ACCENT".into(), "#abcdef".into());
        vars
    }

    #[test]
    fn substitutes_known_keys() {
        assert_eq!(render("a {{ACCENT}} b", &vars()), "a #abcdef b");
        assert_eq!(render("{{ ACCENT }}", &vars()), "#abcdef");
    }

    #[test]
    fn unknown_key_is_left_visible() {
        assert_eq!(render("x {{NOPE}} y", &vars()), "x {{NOPE}} y");
    }

    #[test]
    fn unclosed_placeholder_passes_through() {
        assert_eq!(render("x {{ACCENT", &vars()), "x {{ACCENT");
    }

    #[test]
    fn no_placeholders() {
        assert_eq!(render("sima szoveg", &vars()), "sima szoveg");
    }
}

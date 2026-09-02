//! Minimalis sablonmotor es atomikus fajlkiiras.
//!
//! A sablonok `{{KULCS}}` helyorzoket tartalmaznak. Futasidoben a
//! `backend/templates/` mappabol olvassuk oket, hogy testreszabhatoak legyenek
//! ujraforditas nelkul; ha egy sablon hianyzik, a binarisba fordított valtozat
//! ugrik be, igy a temazas sosem tud eltorni.

use crate::theme::paths;
use anyhow::{Context, Result};
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};

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

/// Egy ideiglenes fajlnev ugyanabban a mappaban, mint a cel.
///
/// A PID onmagaban nem eleg: a daemonban tobb szal is irhat egyszerre (a
/// temavalaszto elonezete es egy parhuzamos alkalmazas), es ugyanarra a nevre
/// ket iro egymas felig kiirt tartalmat nevezne at a helyere. A processzenkent
/// novekvo sorszam teszi a nevet egyedive.
fn temp_path(path: &Path) -> PathBuf {
    static SERIAL: AtomicU64 = AtomicU64::new(0);
    let serial = SERIAL.fetch_add(1, Ordering::Relaxed);
    path.with_extension(format!("vellum-tmp-{}-{serial}", std::process::id()))
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

    stage(path, contents)?.commit()?;
    Ok(true)
}

/// Egy kiirt, de meg a helyere nem tett fajl.
///
/// Ez adja a tobbfajlos tranzakciot: eloszor minden resztvevo kiirodik a maga
/// ideiglenes fajljaba, es a rename-ek csak akkor kovetkeznek, ha mind sikerult.
/// Igy nem maradhat felig atallitott allapot azert, mert a masodik iras bukott.
#[must_use = "a staged fajl commit vagy eldobas nelkul szemetet hagy"]
pub struct Staged {
    temp: PathBuf,
    target: PathBuf,
}

impl Staged {
    /// A helyere teszi a fajlt.
    pub fn commit(mut self) -> Result<()> {
        std::fs::rename(&self.temp, &self.target)
            .with_context(|| format!("nem nevezheto at ide: {}", self.target.display()))?;
        // Nehogy a Drop utana torolni probalja a mar atnevezett fajlt.
        self.temp.clear();
        Ok(())
    }
}

impl Drop for Staged {
    fn drop(&mut self) {
        if !self.temp.as_os_str().is_empty() {
            let _ = std::fs::remove_file(&self.temp);
        }
    }
}

/// Kiirja a tartalmat egy ideiglenes fajlba a cel mappajaban, de nem teszi meg
/// a helyere. Eldobva (commit nelkul) a temp fajl is eltunik.
pub fn stage(path: &Path, contents: &str) -> Result<Staged> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)
            .with_context(|| format!("nem hozhato letre a mappa: {}", parent.display()))?;
    }

    let temp = temp_path(path);
    std::fs::write(&temp, contents).with_context(|| format!("nem irhato: {}", temp.display()))?;
    Ok(Staged { temp, target: path.to_path_buf() })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn vars() -> Vars {
        let mut vars = Vars::new();
        vars.insert("ACCENT".into(), "#abcdef".into());
        vars
    }

    fn scratch(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("vellum-render-{}-{name}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn a_staged_file_only_appears_after_commit() {
        let dir = scratch("stage");
        let target = dir.join("current-theme");

        let staged = stage(&target, "rose-pine\n").unwrap();
        assert!(!target.exists(), "a staged fajl mar a helyen van");

        staged.commit().unwrap();
        assert_eq!(std::fs::read_to_string(&target).unwrap(), "rose-pine\n");

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn a_dropped_stage_leaves_nothing_behind() {
        let dir = scratch("drop");
        let target = dir.join("current-theme");

        drop(stage(&target, "eldobva\n").unwrap());

        assert!(!target.exists());
        let leftovers: Vec<_> = std::fs::read_dir(&dir).unwrap().flatten().collect();
        assert!(leftovers.is_empty(), "ideiglenes fajl maradt: {leftovers:?}");

        let _ = std::fs::remove_dir_all(&dir);
    }

    /// A PID onmagaban nem tette egyedive a nevet: ket parhuzamos iro
    /// ugyanabba az ideiglenes fajlba dolgozott volna.
    #[test]
    fn concurrent_writers_do_not_share_a_temp_file() {
        let dir = scratch("temp");
        let target = dir.join("gtk-theme.css");

        let first = stage(&target, "elso\n").unwrap();
        let second = stage(&target, "masodik\n").unwrap();

        let names: Vec<_> = std::fs::read_dir(&dir)
            .unwrap()
            .flatten()
            .map(|entry| entry.file_name().to_string_lossy().to_string())
            .collect();
        assert_eq!(names.len(), 2, "a ket iro ugyanazt a temp fajlt hasznalta: {names:?}");

        first.commit().unwrap();
        second.commit().unwrap();
        assert_eq!(std::fs::read_to_string(&target).unwrap(), "masodik\n");

        let _ = std::fs::remove_dir_all(&dir);
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

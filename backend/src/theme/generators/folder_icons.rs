//! Generalt mappaikonok.
//!
//! Egy kis "ratet" ikontema a `~/.local/share/icons` alatt: csak a mappakat
//! rajzolja at a paletta szineivel, minden mas ikont (alkalmazasok,
//! fajltipusok, muveletek) az alapul vett temabol orokol. Az ikonkereses a
//! lancban az elso olyan temanal all meg, amelyikben az ikon megvan, ezert a
//! mappak innen jonnek, a tobbi a Yaru-bol.
//!
//! A tema ket nev kozott valtakozik (`vellum-a`, `vellum-b`). Ha a nev
//! ugyanaz maradna, a `gsettings` nem jelezne valtozast, a GTK es a KDE pedig
//! a mar betoltott ikonokat tartana meg; a csere minden alkalmazasban valodi
//! temavaltast valt ki.

use crate::theme::color;
use crate::theme::palette::Palette;
use crate::theme::render::{Vars, load_template, render};
use anyhow::{Context, Result};
use std::path::{Path, PathBuf};

const BUILTIN: &str = include_str!("../../../templates/folder-icon.svg.tmpl");

/// A ket valtakozo temanev.
pub const THEME_NAMES: [&str; 2] = ["vellum-a", "vellum-b"];

/// A kitoltott alakzatok jeloloje a jelekben; a glyph szinere cserelodik.
const FILL: &str = "F/>";

/// Az ikonnevek es a jeluk. Egy sor tobb nevet is kaphat: ugyanaz a rajz
/// tobb neven is kell (a Dolphin peldaul `inode-directory`-t ker a sima
/// mappahoz, a nyitott es a huzas alatti mappa pedig ne valtson vissza a
/// Yaru szinere).
const ICONS: &[(&[&str], &str)] = &[
    (&["folder", "inode-directory", "folder-open", "folder-drag-accept"], ""),
    (
        &["folder-documents"],
        concat!(
            r#"<path d="M50 53H71L80 62V94Q80 97 77 97H50Q47 97 47 94V56Q47 53 50 53Z"/>"#,
            r#"<path d="M71 53V62H80" F/>"#,
            r#"<path d="M54 70H73M54 76H73M54 82H73M54 88H64"/>"#,
        ),
    ),
    (&["folder-download"], r#"<path d="M60 52H68V71H76L64 85L52 71H60Z"/><path d="M50 94H78"/>"#),
    (
        &["folder-music"],
        concat!(
            r#"<path d="M57 89V63L77 58V84"/><path d="M57 61L77 56V63L57 68Z" F/>"#,
            r#"<circle cx="52" cy="89" r="6" F/><circle cx="72" cy="84" r="6" F/>"#,
        ),
    ),
    (
        &["folder-pictures"],
        r#"<path d="M45 92L58 71L66 83L71 76L83 92Z" F/><circle cx="76" cy="62" r="6" F/>"#,
    ),
    (
        &["folder-videos"],
        concat!(
            r#"<rect x="43" y="55" width="42" height="40" rx="3"/><path d="M51 55V95M77 55V95"/>"#,
            r#"<rect x="45.5" y="59" width="3" height="3.4" rx="0.6" F/>"#,
            r#"<rect x="45.5" y="66" width="3" height="3.4" rx="0.6" F/>"#,
            r#"<rect x="45.5" y="73" width="3" height="3.4" rx="0.6" F/>"#,
            r#"<rect x="45.5" y="80" width="3" height="3.4" rx="0.6" F/>"#,
            r#"<rect x="45.5" y="87" width="3" height="3.4" rx="0.6" F/>"#,
            r#"<rect x="79.5" y="59" width="3" height="3.4" rx="0.6" F/>"#,
            r#"<rect x="79.5" y="66" width="3" height="3.4" rx="0.6" F/>"#,
            r#"<rect x="79.5" y="73" width="3" height="3.4" rx="0.6" F/>"#,
            r#"<rect x="79.5" y="80" width="3" height="3.4" rx="0.6" F/>"#,
            r#"<rect x="79.5" y="87" width="3" height="3.4" rx="0.6" F/>"#,
            r#"<path d="M59.5 66.5V83.5L71 75Z" F/>"#,
        ),
    ),
    (
        &["folder-templates"],
        concat!(
            r#"<path d="M43 95V58L71 95Z"/><path d="M49 89V76L59 89Z"/>"#,
            r#"<path d="M43 65H47M43 71H46M43 77H47M43 83H46"/>"#,
            r#"<path d="M74 56H84V83L79 93L74 83Z"/><path d="M74 83H84M74 62H84"/>"#,
            r#"<path d="M77.4 89H80.6L79 93Z" F/>"#,
        ),
    ),
    (
        &["folder-publicshare"],
        concat!(
            r#"<path d="M53 75L75 63M53 75L75 87"/>"#,
            r#"<circle cx="52" cy="75" r="6" F/><circle cx="76" cy="62" r="6" F/>"#,
            r#"<circle cx="76" cy="88" r="6" F/>"#,
        ),
    ),
    (
        &["folder-remote"],
        concat!(
            r#"<circle cx="64" cy="74" r="20"/><ellipse cx="64" cy="74" rx="8" ry="20"/>"#,
            r#"<path d="M44 74H84M47 64H81M47 84H81"/>"#,
        ),
    ),
    (&["user-home"], r#"<path d="M64 52L86 72H79V95H69V82H59V95H49V72H42Z" F/>"#),
    (
        &["user-desktop"],
        r#"<rect x="44" y="56" width="40" height="28" rx="3"/><path d="M64 84V94M54 95H74"/>"#,
    ),
];

/// A nagy (jeles) es a kis (jel nelkuli) ikonok mappaja. 24 px alatt a jel
/// csak zaj lenne, ahogy a Yaru 16 px-es mappain sincs.
const LARGE_DIR: &str = "scalable/places";
const SMALL_DIR: &str = "small/places";

/// Ki van-e kapcsolva a temaban (`FOLDER_ICONS=off`). Ilyenkor a kesz
/// Yaru-variáns marad, mint korabban.
pub fn enabled(palette: &Palette) -> bool {
    let value = palette.text(&["FOLDER_ICONS"], "auto").to_ascii_lowercase();
    !matches!(value.as_str(), "off" | "false" | "no" | "0")
}

/// Egy megirt (vagy valtozatlanul hagyott) tema.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Written {
    pub name: String,
    pub dir: PathBuf,
    pub changed: bool,
}

pub fn icons_root() -> PathBuf {
    crate::theme::paths::data_dir().join("icons")
}

/// Megirja a temat a `root` ala, `inherits` temara epitve.
///
/// Ha az egyik nev alatt mar pontosan ez a tartalom ul, azt hasznalja
/// ujrairas nelkul. Kulonben a masik nevet irja meg, hogy az alkalmazasok
/// valodi temavaltast lassanak.
pub fn write_into(root: &Path, palette: &Palette, inherits: &str) -> Result<Written> {
    let files = files(palette, inherits);

    if let Some(name) = THEME_NAMES.iter().find(|name| matches_on_disk(&root.join(name), &files)) {
        return Ok(Written { name: name.to_string(), dir: root.join(name), changed: false });
    }

    let name = next_name(root);
    let target = root.join(name);

    // Eloszor egy ideiglenes mappaba irunk, es csak a kesz temat nevezzuk at
    // a helyere: felig megirt tema sosem lathato.
    let staging = root.join(format!(".{name}.vellum-tmp-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&staging);
    let result = write_files(&staging, &files).and_then(|()| {
        let _ = std::fs::remove_dir_all(&target);
        std::fs::rename(&staging, &target)
            .with_context(|| format!("nem nevezheto at ide: {}", target.display()))
    });
    if result.is_err() {
        let _ = std::fs::remove_dir_all(&staging);
    }
    result?;

    Ok(Written { name: name.to_string(), dir: target, changed: true })
}

/// Torli a generalt temak kozul azokat, amelyek nem `keep` nevuek. `None`
/// eseten mindet (kikapcsolt mappaikonok utan).
pub fn remove_others(root: &Path, keep: Option<&str>) {
    for name in THEME_NAMES {
        if Some(name) != keep {
            let _ = std::fs::remove_dir_all(root.join(name));
        }
    }
}

/// Az a nev, amelyik most nem aktiv. Ha csak az egyik letezik, a masik; ha
/// egyik sem, az elso; ha mindketto (egy felbeszakadt csere utan), a regebbi
/// -- az ujabbat a futo alkalmazasok valoszinuleg mar hasznaljak.
fn next_name(root: &Path) -> &'static str {
    let modified = |name: &str| {
        std::fs::metadata(root.join(name).join("index.theme")).and_then(|m| m.modified()).ok()
    };
    match (modified(THEME_NAMES[0]), modified(THEME_NAMES[1])) {
        (Some(a), Some(b)) => {
            if a <= b {
                THEME_NAMES[0]
            } else {
                THEME_NAMES[1]
            }
        }
        (Some(_), None) => THEME_NAMES[1],
        _ => THEME_NAMES[0],
    }
}

fn matches_on_disk(dir: &Path, files: &[(String, String)]) -> bool {
    dir.is_dir()
        && files.iter().all(|(relative, contents)| {
            std::fs::read_to_string(dir.join(relative)).is_ok_and(|existing| existing == *contents)
        })
}

fn write_files(dir: &Path, files: &[(String, String)]) -> Result<()> {
    for (relative, contents) in files {
        let path = dir.join(relative);
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)
                .with_context(|| format!("nem hozhato letre a mappa: {}", parent.display()))?;
        }
        std::fs::write(&path, contents)
            .with_context(|| format!("nem irhato: {}", path.display()))?;
    }
    Ok(())
}

/// A tema minden fajlja (relativ utvonal, tartalom).
fn files(palette: &Palette, inherits: &str) -> Vec<(String, String)> {
    let template = load_template("folder-icon.svg.tmpl", BUILTIN);
    let vars = vars(palette);

    let mut files = vec![("index.theme".to_string(), index_theme(inherits))];
    for (names, glyph) in ICONS {
        let large = svg(&template, &vars, glyph);
        let small = svg(&template, &vars, "");
        for name in *names {
            files.push((format!("{LARGE_DIR}/{name}.svg"), large.clone()));
            files.push((format!("{SMALL_DIR}/{name}.svg"), small.clone()));
        }
    }
    files
}

fn svg(template: &str, vars: &Vars, glyph: &str) -> String {
    let glyph = glyph.replace(FILL, r#"fill="{{GLYPH_COLOR}}" stroke="none"/>"#);
    let mut vars = vars.clone();
    vars.insert("GLYPH".into(), render(&glyph, &vars));
    render(template, &vars)
}

fn index_theme(inherits: &str) -> String {
    format!(
        "[Icon Theme]\n\
         Name=Vellum\n\
         Comment=Vellum Shell: a paletta szineibol generalt mappaikonok\n\
         Inherits={inherits},Adwaita,hicolor\n\
         Directories={LARGE_DIR},{SMALL_DIR}\n\
         \n\
         [{LARGE_DIR}]\n\
         Context=Places\n\
         Size=128\n\
         MinSize=24\n\
         MaxSize=512\n\
         Type=Scalable\n\
         \n\
         [{SMALL_DIR}]\n\
         Context=Places\n\
         Size=16\n\
         MinSize=8\n\
         MaxSize=23\n\
         Type=Scalable\n"
    )
}

/// A szinek: az akcentus szinu hatlap balrol jobbra sotetbol vilagosba megy,
/// az eloap az akcentussal enyhen arnyalt semleges szurke (mint a Yaru
/// mappain), a jel ennek vilagos valtozata.
fn vars(palette: &Palette) -> Vars {
    let accent = palette.color(&["ACCENT", "BORDER_FOREGROUND"], "#89b4fa");
    let front = color::mix("#717171", &accent, 86);

    let mut vars = Vars::new();
    vars.insert("BACK_DARK".into(), color::mix(&accent, "#000000", 58));
    vars.insert("BACK_MID".into(), color::mix(&accent, "#000000", 88));
    vars.insert("BACK_LIGHT".into(), color::mix(&accent, "#ffffff", 82));
    vars.insert("FRONT_TOP".into(), color::mix(&front, "#000000", 97));
    vars.insert("FRONT_BOTTOM".into(), color::mix(&front, "#ffffff", 97));
    vars.insert("GLYPH_COLOR".into(), color::mix(&front, "#ffffff", 38));
    vars
}

#[cfg(test)]
mod tests {
    use super::*;

    fn palette(accent: &str) -> Palette {
        Palette::parse(&format!("ACCENT={accent}\nBACKGROUND=#1a1b26\n"))
    }

    fn scratch(name: &str) -> PathBuf {
        let dir =
            std::env::temp_dir().join(format!("vellum-folders-{}-{name}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn every_icon_is_filled_in() {
        let files = files(&palette("#7aa2f7"), "Yaru-blue-dark");
        for (path, contents) in &files {
            assert!(!contents.contains("{{"), "{path}: kitoltetlen helyorzo");
            assert!(!contents.contains(FILL), "{path}: maradt kitoltes-jelolo");
        }
        let svgs = files.iter().filter(|(path, _)| path.ends_with(".svg")).count();
        let names: usize = ICONS.iter().map(|(names, _)| names.len()).sum();
        assert_eq!(svgs, names * 2, "minden ikonnak nagy es kis valtozat kell");
    }

    #[test]
    fn small_icons_have_no_glyph() {
        let files = files(&palette("#7aa2f7"), "Yaru-blue-dark");
        let get = |path: &str| &files.iter().find(|(p, _)| p == path).unwrap().1;

        let large = get("scalable/places/folder-music.svg");
        let small = get("small/places/folder-music.svg");
        assert!(large.contains("<circle"), "a nagy ikonon latszik a jel");
        assert!(!small.contains("<circle"), "a kis ikonon nincs jel");
        assert_eq!(small, get("small/places/folder.svg"));
    }

    #[test]
    fn colors_follow_the_accent() {
        let blue = files(&palette("#7aa2f7"), "Yaru-blue-dark");
        let red = files(&palette("#c34043"), "Yaru-blue-dark");
        assert_ne!(blue[1].1, red[1].1);
        assert!(blue[1].1.contains(&color::mix("#7aa2f7", "#ffffff", 82)));
    }

    #[test]
    fn index_inherits_the_base_theme() {
        let index = index_theme("Papirus-Dark");
        assert!(index.contains("Inherits=Papirus-Dark,Adwaita,hicolor\n"));
        assert!(index.contains("[small/places]\n"));
    }

    #[test]
    fn can_be_switched_off() {
        assert!(enabled(&Palette::parse("ACCENT=#ff0000\n")));
        assert!(enabled(&Palette::parse("FOLDER_ICONS=auto\n")));
        assert!(!enabled(&Palette::parse("FOLDER_ICONS=off\n")));
    }

    /// Valtozatlan paletta: ugyanaz a nev, iras nelkul. Uj szin: a masik nev,
    /// hogy az alkalmazasok temavaltast lassanak.
    #[test]
    fn names_alternate_only_when_content_changes() {
        let root = scratch("alternate");

        let first = write_into(&root, &palette("#7aa2f7"), "Yaru-blue-dark").unwrap();
        assert_eq!((first.name.as_str(), first.changed), ("vellum-a", true));
        assert!(first.dir.join("scalable/places/folder.svg").is_file());

        let again = write_into(&root, &palette("#7aa2f7"), "Yaru-blue-dark").unwrap();
        assert_eq!((again.name.as_str(), again.changed), ("vellum-a", false));

        let next = write_into(&root, &palette("#c34043"), "Yaru-red-dark").unwrap();
        assert_eq!((next.name.as_str(), next.changed), ("vellum-b", true));

        remove_others(&root, Some(&next.name));
        assert!(!root.join("vellum-a").exists());
        assert!(root.join("vellum-b/index.theme").is_file());

        // Visszavaltas az elozo szinre: ujra a masik nevre kerul.
        let back = write_into(&root, &palette("#7aa2f7"), "Yaru-blue-dark").unwrap();
        assert_eq!((back.name.as_str(), back.changed), ("vellum-a", true));

        let leftovers: Vec<_> = std::fs::read_dir(&root)
            .unwrap()
            .flatten()
            .map(|entry| entry.file_name().to_string_lossy().to_string())
            .filter(|name| name.contains("vellum-tmp"))
            .collect();
        assert!(leftovers.is_empty(), "ideiglenes mappa maradt: {leftovers:?}");

        remove_others(&root, None);
        assert!(!root.join("vellum-a").exists() && !root.join("vellum-b").exists());
        let _ = std::fs::remove_dir_all(&root);
    }
}

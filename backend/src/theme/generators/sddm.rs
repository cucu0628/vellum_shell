//! A Vellum Ink SDDM greeter theme.conf-ja.
//!
//! A repoban levo peldanyt mindig frissiti, a telepitett rendszerpeldanyt pedig
//! akkor, ha az irhato (az `sddm-install` a hivo felhasznalora chownolja).

use crate::theme::palette::Palette;
use crate::theme::paths;
use crate::theme::render::{Vars, load_template, render};
use anyhow::Result;
use std::io::Cursor;
use std::path::{Path, PathBuf};
use std::time::SystemTime;

const BUILTIN: &str = include_str!("../../../templates/sddm-theme.conf.tmpl");

/// A greeter sajat hatterkep-peldanya. A `/home` tipikusan 0700, tehat az
/// `sddm` felhasznalo nem eri el az eredetit -- masolat nelkul a greeternek
/// nem lehet ugyanaz a hattere, mint a zarolokepernyonek.
const BACKGROUND_NAME: &str = "background.jpg";

/// A greeter ugyanugy elhomalyositja a kepet, mint a lockscreen, ezert a
/// reszletek elvesznek: felesleges 4K-t masolni a rendszerkonyvtarba.
const BACKGROUND_WIDTH: u32 = 1280;
const BACKGROUND_QUALITY: u8 = 82;

fn repo_dir() -> PathBuf {
    paths::shell_dir().join("sddm/vellum-ink")
}

fn system_dir() -> PathBuf {
    PathBuf::from("/usr/share/sddm/themes/vellum-ink")
}

/// A `wallpaper` az EPPEN alkalmazott kep. Azert kell parameterkent, mert a
/// `theme::apply` a `current-wallpaper`-t csak a generatorok UTAN commitolja:
/// ha a fajlbol olvasnank, a greeter mindig egy valtassal lemaradna.
pub fn generate(palette: &Palette, wallpaper: Option<&Path>) -> Result<Option<(PathBuf, bool)>> {
    // A kep elobb keszul el, mint a theme.conf: az csak akkor hivatkozzon ra,
    // ha tenyleg ott van a tema mellett.
    let has_background = sync_background(wallpaper);

    let template = load_template("sddm-theme.conf.tmpl", BUILTIN);
    let payload = render(&template, &vars(palette, has_background));

    let repo_copy = repo_dir().join("theme.conf");
    let system_copy = system_dir().join("theme.conf");

    let changed = write_if_writable(&repo_copy, &payload)?;

    // A rendszerpeldany utvonala beegetett abszolut ut: sem a `VELLUM_SHELL_DIR`
    // sandbox, sem a temp HOME nem tereli el. Enelkul a golden teszt minden
    // futasa atirna az ELO greeter temajat arra a palettara, amelyik utolsonak
    // fut le -- ezert kell ugyanaz a kapcsolo, mint a gsettings/systemctl agnak.
    //
    // A rendszerpeldany hianya vagy irasvedettsege nem hiba: a greeter tema
    // egyszeruen nincs telepitve.
    if crate::theme::side_effects_enabled() {
        let _ = write_if_writable(&system_copy, &payload);
    }

    Ok(Some((repo_copy, changed)))
}

/// A kicsinyitett hatterkep frissitese a tema mappaiban.
///
/// A rendszerpeldany mappaja root tulajdonu, ezert a fajlnak mar leteznie kell
/// es a felhasznaloe kell legyen -- errol az `sddm-install` gondoskodik,
/// ugyanugy, mint a `theme.conf` eseteben. Ha nem sikerul irni, az nem hiba:
/// a greeter ilyenkor a temaszinre es az ensō vizjelre esik vissza.
fn sync_background(wallpaper: Option<&Path>) -> bool {
    let mut dirs = vec![repo_dir()];
    // Ugyanaz a kapcsolo, mint a theme.conf rendszerpeldanyanal: teszt alatt
    // nem nyulunk az ELO greeter mappajahoz.
    if crate::theme::side_effects_enabled() {
        dirs.push(system_dir());
    }

    // A hivo altal adott kep az elsodleges. A `current-wallpaper` csak tartalek:
    // a `theme::apply` azt a generatorok UTAN commitolja, tehat itt meg a regi
    // erteket tartja.
    let source = match wallpaper {
        Some(path) => path.to_path_buf(),
        None => match paths::read_line_file(&paths::current_wallpaper_file()) {
            Some(line) => PathBuf::from(line.trim()),
            None => return false,
        },
    };
    if !source.is_file() {
        return false;
    }

    // Ha a hivo konkret kepet adott, az szandekos valtoztatas -- olyankor mindig
    // ujrakodolunk. Idobelyeget osszehasonlitani ilyenkor nem lehet: az uj kep
    // fajlja regebbi is lehet, mint az elozo masolat.
    let forced = wallpaper.is_some();
    let changed_at = newest(&source);

    let mut encoded: Option<Vec<u8>> = None;
    for dir in &dirs {
        let target = dir.join(BACKGROUND_NAME);
        if !dir.is_dir() || (!forced && !is_stale(&target, changed_at)) {
            continue;
        }
        let bytes = match &encoded {
            Some(bytes) => bytes,
            None => match downscale(&source) {
                Ok(bytes) => encoded.insert(bytes),
                Err(err) => {
                    tracing::warn!(
                        error = format!("{err:#}"),
                        "a greeter hatterkepe nem keszult el"
                    );
                    break;
                }
            },
        };
        let _ = write_bytes_if_writable(&target, bytes);
    }

    // Egy elavult, de meglevo peldany is jobb, mint semmi: a greeter attol meg
    // mutat kepet, csak eggyel korabbit.
    dirs.iter().any(|dir| dir.join(BACKGROUND_NAME).is_file())
}

fn newest(path: &Path) -> Option<SystemTime> {
    std::fs::metadata(path).and_then(|meta| meta.modified()).ok()
}

fn is_stale(target: &Path, changed_at: Option<SystemTime>) -> bool {
    let Some(written) = newest(target) else {
        return true;
    };
    changed_at.is_none_or(|changed| written < changed)
}

fn downscale(source: &Path) -> Result<Vec<u8>> {
    let image = image::open(source)?;
    let image = if image.width() > BACKGROUND_WIDTH {
        image.resize(BACKGROUND_WIDTH, u32::MAX, image::imageops::FilterType::Lanczos3)
    } else {
        image
    };

    let mut bytes = Vec::new();
    let mut encoder = image::codecs::jpeg::JpegEncoder::new_with_quality(
        Cursor::new(&mut bytes),
        BACKGROUND_QUALITY,
    );
    encoder.encode_image(&image.to_rgb8())?;
    Ok(bytes)
}

fn vars(palette: &Palette, has_background: bool) -> Vars {
    // A greeter azon a kepernyon mutatja a bejelentkezo kartyat, amelyiken a
    // lockscreen is bekeri a jelszot. Ures ertek eseten a rendszer elsodleges
    // kepernyoje dont.
    let input_screen: String = paths::read_line_file(&paths::lockscreen_monitor_file())
        .map(|value| value.chars().filter(|c| !c.is_whitespace()).collect())
        .unwrap_or_default();

    // A connector neve csak a Wayland oldalon ervenyes. A greeter X szervere
    // mas neveket ad ugyanarra a kijelzore, ezert az EDID-bol kiolvasott
    // azonositot is atadjuk -- az mindket oldalon ugyanaz.
    let identity = if input_screen.is_empty() {
        None
    } else {
        crate::edid::identity_for_connector(&input_screen).filter(|id| id.is_usable())
    };

    // A MUTED-ot a LIGHT_FOREGROUND felulirja, ha az kesobb all a fajlban --
    // a temak epp igy vannak megirva, ezert a sorrend szamit.
    let muted = palette.color(&["MUTED", "LIGHT_FOREGROUND"], "#9399b2");

    let mut vars = Vars::new();
    vars.insert("NAME".into(), palette.text(&["NAME"], "Vellum Shell"));
    vars.insert("INPUT_SCREEN".into(), input_screen);
    vars.insert(
        "INPUT_SCREEN_SERIAL".into(),
        identity.as_ref().map(|id| id.serial.clone()).unwrap_or_default(),
    );
    vars.insert(
        "INPUT_SCREEN_MODEL".into(),
        identity.as_ref().map(|id| id.model.clone()).unwrap_or_default(),
    );
    vars.insert("BACKGROUND".into(), palette.color(&["BACKGROUND"], "#1e1e2e"));
    vars.insert("FOREGROUND".into(), palette.color(&["FOREGROUND"], "#cdd6f4"));
    vars.insert("ACCENT".into(), palette.color(&["ACCENT", "BORDER_FOREGROUND"], "#89b4fa"));
    vars.insert("SURFACE".into(), palette.color(&["SURFACE"], "#181825"));
    vars.insert("MUTED".into(), muted);
    vars.insert("RED".into(), palette.color(&["RED"], "#d7472f"));
    // Relativ ut: a greeter a tema mappajahoz kepest oldja fel.
    vars.insert(
        "BACKGROUND_IMAGE".into(),
        if has_background { BACKGROUND_NAME.into() } else { String::new() },
    );
    vars
}

/// Helyben ir, hogy eleg legyen a fajlra kapott irasi jog (a mappa lehet root
/// tulajdonu). Ha nincs jogunk, csendben kihagyjuk.
fn write_if_writable(path: &Path, payload: &str) -> Result<bool> {
    if let Ok(existing) = std::fs::read_to_string(path) {
        if existing == payload {
            return Ok(false);
        }
        if std::fs::metadata(path).map(|m| m.permissions().readonly()).unwrap_or(true) {
            return Ok(false);
        }
        std::fs::write(path, payload)?;
        return Ok(true);
    }

    let Some(dir) = path.parent() else {
        return Ok(false);
    };
    if !dir.is_dir() {
        return Ok(false);
    }
    match std::fs::write(path, payload) {
        Ok(()) => Ok(true),
        Err(_) => Ok(false),
    }
}

/// A `write_if_writable` bajtos parja a hatterkephez.
fn write_bytes_if_writable(path: &Path, payload: &[u8]) -> bool {
    if path.is_file() {
        if std::fs::metadata(path).map(|m| m.permissions().readonly()).unwrap_or(true) {
            return false;
        }
        return std::fs::write(path, payload).is_ok();
    }

    match path.parent() {
        Some(dir) if dir.is_dir() => std::fs::write(path, payload).is_ok(),
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn render_with(input_screen: &str, serial: &str, model: &str) -> String {
        let mut vars = Vars::new();
        vars.insert("NAME".into(), "Gruvbox Material".into());
        vars.insert("INPUT_SCREEN".into(), input_screen.into());
        vars.insert("INPUT_SCREEN_SERIAL".into(), serial.into());
        vars.insert("INPUT_SCREEN_MODEL".into(), model.into());
        for key in ["BACKGROUND", "FOREGROUND", "ACCENT", "SURFACE", "MUTED", "RED"] {
            vars.insert(key.into(), "#000000".into());
        }
        vars.insert("BACKGROUND_IMAGE".into(), BACKGROUND_NAME.into());
        render(BUILTIN, &vars)
    }

    #[test]
    fn carries_both_the_connector_name_and_the_edid_identity() {
        let output = render_with("HDMI-A-1", "SERIAL-1", "MODEL-X");
        // A nev a Wayland oldalnak kell, az azonosito a greeternek.
        assert!(output.contains("\ninputScreen=HDMI-A-1\n"), "{output}");
        assert!(output.contains("\ninputScreenSerial=SERIAL-1\n"), "{output}");
        assert!(output.contains("\ninputScreenModel=MODEL-X\n"), "{output}");
        assert!(output.starts_with("[General]\n"));
    }

    /// EDID nelkul (pl. virtualis kijelzo) a mezok uresen maradnak, es a
    /// greeter a nevre, majd a sajat elsodleges kepernyojere esik vissza.
    #[test]
    fn missing_edid_leaves_the_fields_empty() {
        let output = render_with("HDMI-A-1", "", "");
        assert!(output.contains("\ninputScreenSerial=\n"), "{output}");
        assert!(output.contains("\ninputScreenModel=\n"), "{output}");
    }

    /// A greeter a tema mappajahoz kepest oldja fel az utat, ezert relativ
    /// nevnek kell odakerulnie -- abszolut ut a `/home` 0700 miatt hasznalhatatlan.
    #[test]
    fn the_background_is_a_relative_name() {
        let output = render_with("HDMI-A-1", "S", "M");
        assert!(output.contains("\nbackground=background.jpg\n"), "{output}");
        assert!(!output.contains("background=/"), "{output}");
    }

    /// A rendszerkonyvtarba nem masolunk 4K-t: a greeter ugyis elhomalyositja.
    #[test]
    fn the_background_copy_is_scaled_down_to_a_jpeg() {
        let dir = std::env::temp_dir().join(format!("vellum-sddm-bg-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let source = dir.join("wide.png");
        image::RgbImage::from_pixel(2400, 1000, image::Rgb([90, 60, 140])).save(&source).unwrap();

        let bytes = downscale(&source).unwrap();
        let copy = image::load_from_memory(&bytes).unwrap();
        assert_eq!(copy.width(), BACKGROUND_WIDTH);
        // Az aranyot tartja, nem nyujt.
        assert_eq!(copy.height(), BACKGROUND_WIDTH * 1000 / 2400);
        assert!(bytes.len() < std::fs::metadata(&source).unwrap().len() as usize);

        std::fs::remove_dir_all(&dir).ok();
    }

    /// A mar kiirt masolatot csak akkor kodoljuk ujra, ha valoban valtozott.
    #[test]
    fn an_up_to_date_copy_is_not_rewritten() {
        let dir = std::env::temp_dir().join(format!("vellum-sddm-stale-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let target = dir.join(BACKGROUND_NAME);

        assert!(is_stale(&target, None), "hianyzo masolat mindig elavult");

        std::fs::write(&target, b"x").unwrap();
        let written = newest(&target).unwrap();
        assert!(!is_stale(&target, Some(written - std::time::Duration::from_secs(60))));
        assert!(is_stale(&target, Some(written + std::time::Duration::from_secs(60))));

        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn no_placeholder_survives_rendering() {
        let output = render_with("HDMI-A-1", "S", "M");
        assert!(!output.contains("{{"), "feloldatlan helyorzo maradt:\n{output}");
    }
}

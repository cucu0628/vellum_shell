//! A Vellum greeter palettaja es hatterkepe.
//!
//! A greeter (`GreeterShell.qml`, greetd alatt) a zarolokepernyo nyelvet
//! beszeli, ezert ugyanazokat a szineket es ugyanazt a hatterkepet kapja. A
//! `/home`-ot nem latja, igy a temamotor a `crate::greeter` allapotmappajaba
//! irja ki, amire szuksege van. A monitor-elrendezest is innen frissitjuk, hogy
//! a telepito egyetlen `theme apply`-jal a teljes greeter-allapotot elkeszitse.

use crate::greeter;
use crate::theme::palette::Palette;
use crate::theme::paths;
use anyhow::Result;
use serde_json::json;
use std::io::Cursor;
use std::path::{Path, PathBuf};
use std::time::SystemTime;

const THEME_NAME: &str = "theme.json";

/// A greeter sajat hatterkep-peldanya, az allapotmappahoz kepest.
const BACKGROUND_NAME: &str = "background.jpg";

/// A greeter ugyanugy elhomalyositja a kepet, mint a lockscreen, de belepeskor
/// felenged: egy 1080p kijelzon a masolat ne legyen szemmel lathatoan elmosott.
const BACKGROUND_WIDTH: u32 = 1920;
const BACKGROUND_QUALITY: u8 = 85;

/// A `wallpaper` az EPPEN alkalmazott kep. Azert kell parameterkent, mert a
/// `theme::apply` a `current-wallpaper`-t csak a generatorok UTAN commitolja:
/// ha a fajlbol olvasnank, a greeter mindig egy valtassal lemaradna.
pub fn generate(palette: &Palette, wallpaper: Option<&Path>) -> Result<Option<(PathBuf, bool)>> {
    let Some(dir) = greeter::state_dir() else {
        return Ok(None);
    };

    // Teszt alatt nincs Hyprland, amit meg lehetne kerdezni.
    if crate::theme::side_effects_enabled() {
        crate::modules::hypr::sync_greeter_layout();
    }

    // A kep elobb keszul el, mint a paletta: az csak akkor hivatkozzon ra, ha
    // tenyleg ott van.
    let has_background = sync_background(&dir, wallpaper);
    let path = dir.join(THEME_NAME);
    let payload = render(palette, has_background);
    Ok(greeter::write_if_writable(&path, payload.as_bytes()).map(|changed| (path, changed)))
}

/// A `theme.json`. A kulcsok a paletta sajat nevei, ugyanugy, ahogy a `theme`
/// topic kuldi: a greeter igy a lockscreen lekepezeset hasznalhatja.
fn render(palette: &Palette, has_background: bool) -> String {
    let value = json!({
        "name": palette.text(&["NAME"], "Vellum Shell"),
        "colors": {
            "BACKGROUND": palette.color(&["BACKGROUND"], "#1e1e2e"),
            "FOREGROUND": palette.color(&["FOREGROUND"], "#cdd6f4"),
            "ACCENT": palette.color(&["ACCENT", "BORDER_FOREGROUND"], "#89b4fa"),
            "SURFACE": palette.color(&["SURFACE"], "#181825"),
            "MUTED": palette.color(&["MUTED"], "#9399b2"),
            "LIGHT_FOREGROUND": palette.color(&["LIGHT_FOREGROUND"], "#bac2de"),
            "RED": palette.color(&["RED"], "#d7472f"),
        },
        // Relativ nev: a greeter az allapotmappahoz kepest oldja fel.
        "background": if has_background { BACKGROUND_NAME } else { "" },
    });
    format!("{}\n", serde_json::to_string_pretty(&value).unwrap_or_default())
}

/// A kicsinyitett hatterkep frissitese. Ha nem sikerul irni, az nem hiba: a
/// greeter ilyenkor a temaszinre es az ensō vizjelre esik vissza.
fn sync_background(dir: &Path, wallpaper: Option<&Path>) -> bool {
    let target = dir.join(BACKGROUND_NAME);

    // A hivo altal adott kep az elsodleges. A `current-wallpaper` csak tartalek:
    // a `theme::apply` azt a generatorok UTAN commitolja, tehat itt meg a regi
    // erteket tartja.
    let source = match wallpaper {
        Some(path) => path.to_path_buf(),
        None => match paths::read_line_file(&paths::current_wallpaper_file()) {
            Some(line) => PathBuf::from(line.trim()),
            None => return target.is_file(),
        },
    };
    if !source.is_file() {
        return target.is_file();
    }

    // Ha a hivo konkret kepet adott, az szandekos valtoztatas -- olyankor mindig
    // ujrakodolunk. Idobelyeget osszehasonlitani ilyenkor nem lehet: az uj kep
    // fajlja regebbi is lehet, mint az elozo masolat.
    if wallpaper.is_some() || is_stale(&target, newest(&source)) {
        match downscale(&source) {
            Ok(bytes) => {
                greeter::write_if_writable(&target, &bytes);
            }
            Err(err) => {
                tracing::warn!(error = format!("{err:#}"), "a greeter hatterkepe nem keszult el");
            }
        }
    }

    // Egy elavult, de meglevo peldany is jobb, mint semmi: a greeter attol meg
    // mutat kepet, csak eggyel korabbit. Egy ures helyorzo viszont nem kep.
    std::fs::metadata(&target).is_ok_and(|meta| meta.is_file() && meta.len() > 0)
}

fn newest(path: &Path) -> Option<SystemTime> {
    std::fs::metadata(path).and_then(|meta| meta.modified()).ok()
}

fn is_stale(target: &Path, changed_at: Option<SystemTime>) -> bool {
    let Some(written) = newest(target) else {
        return true;
    };
    // A telepito ures helyorzot tesz le: azt mindig ki kell tolteni.
    if std::fs::metadata(target).is_ok_and(|meta| meta.len() == 0) {
        return true;
    }
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

#[cfg(test)]
mod tests {
    use super::*;

    fn palette() -> Palette {
        Palette::parse(
            "NAME=\"Gruvbox Material\"\nBACKGROUND=\"#282828\"\nFOREGROUND=\"#d4be98\"\n\
             BORDER_FOREGROUND=\"#a9b665\"\nMUTED=\"#7c6f64\"\nLIGHT_FOREGROUND=\"#ddc7a1\"\n",
        )
    }

    #[test]
    fn the_palette_keeps_the_shell_key_names() {
        let value: serde_json::Value = serde_json::from_str(&render(&palette(), true)).unwrap();
        assert_eq!(value["name"], "Gruvbox Material");
        assert_eq!(value["colors"]["BACKGROUND"], "#282828");
        // Az ACCENT hianyaban a keret szine az akcent, ugyanugy, mint a shellben.
        assert_eq!(value["colors"]["ACCENT"], "#a9b665");
        assert_eq!(value["colors"]["MUTED"], "#7c6f64");
        assert_eq!(value["colors"]["LIGHT_FOREGROUND"], "#ddc7a1");
        // Hianyzo kulcs: alapertek, nem ures string.
        assert_eq!(value["colors"]["SURFACE"], "#181825");
    }

    /// A greeter az allapotmappahoz kepest oldja fel az utat, ezert relativ
    /// nevnek kell odakerulnie -- abszolut ut a `/home` miatt hasznalhatatlan.
    #[test]
    fn the_background_is_a_relative_name_or_empty() {
        let with: serde_json::Value = serde_json::from_str(&render(&palette(), true)).unwrap();
        assert_eq!(with["background"], BACKGROUND_NAME);
        let without: serde_json::Value = serde_json::from_str(&render(&palette(), false)).unwrap();
        assert_eq!(without["background"], "");
    }

    #[test]
    fn the_background_copy_is_scaled_down_to_a_jpeg() {
        let dir = std::env::temp_dir().join(format!("vellum-greeter-bg-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let source = dir.join("wide.png");
        image::RgbImage::from_pixel(3200, 1000, image::Rgb([90, 60, 140])).save(&source).unwrap();

        let bytes = downscale(&source).unwrap();
        let copy = image::load_from_memory(&bytes).unwrap();
        assert_eq!(copy.width(), BACKGROUND_WIDTH);
        // Az aranyot tartja, nem nyujt.
        assert_eq!(copy.height(), BACKGROUND_WIDTH * 1000 / 3200);

        std::fs::remove_dir_all(&dir).ok();
    }

    /// A mar kiirt masolatot csak akkor kodoljuk ujra, ha valoban valtozott --
    /// kiveve a telepito ures helyorzojet.
    #[test]
    fn an_up_to_date_copy_is_not_rewritten() {
        let dir = std::env::temp_dir().join(format!("vellum-greeter-stale-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let target = dir.join(BACKGROUND_NAME);

        assert!(is_stale(&target, None), "hianyzo masolat mindig elavult");

        std::fs::write(&target, b"").unwrap();
        assert!(is_stale(&target, None), "az ures helyorzo mindig elavult");

        std::fs::write(&target, b"x").unwrap();
        let written = newest(&target).unwrap();
        assert!(!is_stale(&target, Some(written - std::time::Duration::from_secs(60))));
        assert!(is_stale(&target, Some(written + std::time::Duration::from_secs(60))));

        std::fs::remove_dir_all(&dir).ok();
    }
}

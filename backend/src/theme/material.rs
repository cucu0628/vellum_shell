//! Natív Material You paletta hatterkepbol.
//!
//! Ez valtja ki a `matugen` + `jq` fuggoseget. A logika azonos a korabbi
//! `scripts/matugen-theme`-mel, csak a kerulout maradt el: ott a script azzal
//! ismerte fel a "nincs hasznalhato szin" esetet, hogy sajat fallback-szint
//! adott a matugennek, es megnezte, hogy azt kapta-e vissza. Ugyanezt tesszuk,
//! csak kozvetlenul a `Score` fuggvennyel.
//!
//! Az ok, amiert ez szamit: monokrom hatterkepnel a Material `Score` mindent
//! kiszur (chroma < 5), es ilyenkor alapertelmezesben Google Blue-t ad vissza.
//! Kek arnyalatot kapna egy szurke kep -- ezert ilyenkor a monokrom semara
//! valtunk ahelyett, hogy szint talalnank ki.

use crate::theme::palette::Palette;
use crate::theme::render::{Vars, load_template, render, write_if_changed};
use crate::theme::{DYNAMIC_SLUG, color, paths};
use anyhow::{Context, Result};
use material_colors::color::Argb;
use material_colors::hct::Hct;
use material_colors::image::{FilterType, ImageReader};
use material_colors::quantize::{Quantizer, QuantizerCelebi};
use material_colors::scheme::Scheme;
use material_colors::scheme::variant::{SchemeMonochrome, SchemeTonalSpot};
use material_colors::score::Score;
use std::path::Path;

const BUILTIN: &str = include_str!("../../templates/dynamic-theme.conf.tmpl");

/// Efolott a leghosszabb oldal folott kicsinyitunk a kvantalas elott.
///
/// Szandekosan magas: merve a kicsinyites NEM gyorsit erdemben (504 ms teljes
/// kepre vs 276-549 ms kicsinyitve), viszont a Lanczos ujramintavetelezes
/// eltolja a szineloszlast, es mas akcentust ad. Ez a hatar tehat csak arra
/// van, hogy egy abszurd meretu kep se fusson el.
///
/// FONTOS: ha megis kicsinyitunk, a kepARANYT meg kell tartani. Negyzetre
/// torzitva az akcentus lathatoan elcsuszik.
const SAMPLE_BOUND: u32 = 4000;

/// Az a szin, amit akkor kapunk vissza, ha egyetlen szin sem eleg telitett.
/// Az erteke lenyegtelen -- csak arra kell, hogy felismerjuk az esetet.
const NEUTRAL_SENTINEL: Argb = Argb { alpha: 255, red: 0x80, green: 0x80, blue: 0x80 };

/// A kepbol szarmaztatott theme.conf tartalma. A `generate` es a `palette_for`
/// is ezt hasznalja, igy a ketto sosem terhet el egymastol.
fn render_conf(wallpaper: &Path) -> Result<String> {
    let scheme = scheme_for(wallpaper)?;
    let vars = vars_from_scheme(&scheme);

    Ok(render(&load_template("dynamic-theme.conf.tmpl", BUILTIN), &vars))
}

/// A hatterkepbol szarmaztatott paletta, lemezre iras nelkul. A valaszto
/// elonezete ezt hasznalja: bongeszes kozben nem szabad felulirni a temat, amit
/// a felhasznalo esetleg megsem valaszt.
pub fn palette_for(wallpaper: &Path) -> Result<Palette> {
    Ok(Palette::parse(&render_conf(wallpaper)?))
}

/// Legeneralja a dinamikus temat a hatterkepbol, es kiirja a
/// `themes/dynamic-matugen/theme.conf`-ot.
pub fn generate(wallpaper: &Path) -> Result<Palette> {
    let contents = render_conf(wallpaper)?;

    let output = paths::theme_conf(DYNAMIC_SLUG);
    write_if_changed(&output, &contents)?;

    Ok(Palette::parse(&contents))
}

fn scheme_for(wallpaper: &Path) -> Result<Scheme> {
    let mut image = ImageReader::open(wallpaper)
        .with_context(|| format!("a hatterkep nem olvashato: {}", wallpaper.display()))?;
    if let Some((width, height)) = sample_size(wallpaper) {
        image.resize(width, height, FilterType::Lanczos3);
    }

    let source = extract_source_color(&image);

    // Ha a sentinelt kaptuk vissza, egyetlen szin sem volt eleg telitett: ez egy
    // semleges kep. Ilyenkor monokrom sema, nem kitalált arnyalat.
    let is_neutral = source == NEUTRAL_SENTINEL;
    let hct = Hct::new(source);

    Ok(if is_neutral {
        SchemeMonochrome::new(hct, true, None).scheme.into()
    } else {
        SchemeTonalSpot::new(hct, true, None).scheme.into()
    })
}

/// A kvantalas celmerete, kepARANY-tartoan. `None`, ha a kep amugy is kicsi.
fn sample_size(wallpaper: &Path) -> Option<(u32, u32)> {
    // Csak a fejlecet olvassa, nem dekodolja a kepet.
    let (width, height) = image::image_dimensions(wallpaper).ok()?;
    let longest = width.max(height);
    if longest <= SAMPLE_BOUND {
        return None;
    }

    let scale = f64::from(SAMPLE_BOUND) / f64::from(longest);
    Some((
        ((f64::from(width) * scale).round() as u32).max(1),
        ((f64::from(height) * scale).round() as u32).max(1),
    ))
}

/// A kepet legjobban jellemzo szin. A `ImageReader::extract_color` ugyanezt
/// teszi, de nem engedi atadni a fallback szint -- nekunk pedig pont arra van
/// szuksegunk, hogy felismerjuk a "nincs hasznalhato szin" esetet.
fn extract_source_color(image: &material_colors::image::Image) -> Argb {
    use material_colors::image::AsPixels;
    let pixels = image.as_pixels();
    let quantized = QuantizerCelebi::quantize(&pixels, 128);
    let ranked = Score::score(&quantized.color_to_count, None, Some(NEUTRAL_SENTINEL), None);
    ranked.first().copied().unwrap_or(NEUTRAL_SENTINEL)
}

fn vars_from_scheme(scheme: &Scheme) -> Vars {
    let hex = |argb: Argb| argb.to_hex_with_pound().to_lowercase();

    // A Material szerepek leképezese a paletta kulcsaira -- ugyanaz, amit a
    // korabbi script jq-val szedett ki a matugen JSON-jabol.
    let background = hex(scheme.background);
    let foreground = hex(scheme.on_surface);
    let accent = hex(scheme.primary);
    let surface = hex(scheme.surface_container);
    let muted = hex(scheme.on_surface_variant);
    let red = hex(scheme.error);
    let orange = hex(scheme.tertiary);
    let cyan = hex(scheme.secondary);
    let blue = hex(scheme.primary);
    let magenta = hex(scheme.tertiary);

    // A hianyzo ANSI szineket az akcentusbol keverjuk, hogy a paletta egyben
    // maradjon; a vilagos valtozatok a szoveg szine fele tolodnak.
    let yellow = color::mix("#e0af68", &accent, 72);
    let green = color::mix("#9ece6a", &accent, 72);
    let brown = color::mix("#8b5e4a", &accent, 70);
    let brighten = |value: &str| color::mix(value, &foreground, 82);

    let mut vars = Vars::new();
    vars.insert("BRIGHT_RED".into(), brighten(&red));
    vars.insert("BRIGHT_YELLOW".into(), brighten(&yellow));
    vars.insert("BRIGHT_GREEN".into(), brighten(&green));
    vars.insert("BRIGHT_CYAN".into(), brighten(&cyan));
    vars.insert("BRIGHT_BLUE".into(), brighten(&blue));
    vars.insert("BRIGHT_MAGENTA".into(), brighten(&magenta));
    vars.insert("SELECTION".into(), hex(scheme.secondary_container));
    vars.insert("DARK_BACKGROUND".into(), hex(scheme.surface_dim));
    vars.insert("DARKER_BACKGROUND".into(), hex(scheme.surface_container_lowest));
    vars.insert("LIGHTER_BACKGROUND".into(), hex(scheme.surface_container_high));
    vars.insert("DARK_FOREGROUND".into(), hex(scheme.outline));
    vars.insert("LIGHT_FOREGROUND".into(), hex(scheme.on_surface_variant));
    vars.insert("BRIGHT_FOREGROUND".into(), hex(scheme.on_surface));
    vars.insert("YELLOW".into(), yellow);
    vars.insert("GREEN".into(), green);
    vars.insert("BROWN".into(), brown);
    vars.insert("BACKGROUND".into(), background);
    vars.insert("FOREGROUND".into(), foreground);
    vars.insert("ACCENT".into(), accent);
    vars.insert("SURFACE".into(), surface);
    vars.insert("MUTED".into(), muted);
    vars.insert("RED".into(), red);
    vars.insert("ORANGE".into(), orange);
    vars.insert("CYAN".into(), cyan);
    vars.insert("BLUE".into(), blue);
    vars.insert("MAGENTA".into(), magenta);
    vars
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Egy teljesen szurke kep nem kaphat kek arnyalatot -- ez volt a korabbi
    /// script kifejezett celja, es a legkonnyebben elrontheto reszlet.
    #[test]
    fn grey_image_stays_neutral() {
        let dir = std::env::temp_dir().join("vellum-material-grey");
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("grey.png");

        std::fs::write(&path, grey_png()).unwrap();

        let scheme = scheme_for(&path).unwrap();
        let accent = scheme.primary.to_hex_with_pound().to_lowercase();
        let (r, g, b) = color::to_rgb(&accent).unwrap();

        let max = r.max(g).max(b);
        let min = r.min(g).min(b);
        assert!(
            max - min < 20,
            "a szurke kep akcentusa szines lett: {accent} (delta {})",
            max - min
        );

        let _ = std::fs::remove_dir_all(&dir);
    }

    /// A kicsinyitesnek meg kell tartania a kepARANYT. Negyzetre torzitva a
    /// szineloszlas eltolodik, es lathatoan mas akcentust kapunk -- ez egy mar
    /// egyszer elkovetett hiba.
    #[test]
    fn resize_preserves_aspect_ratio() {
        let dir = std::env::temp_dir().join("vellum-material-aspect");
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("wide.png");

        // Szandekosan a hataron tuli, eros keparannyal (3:1).
        let width = SAMPLE_BOUND + 2000;
        let height = width / 3;
        write_png(&path, width, height);

        let (out_width, out_height) = sample_size(&path).expect("a hataron tul kicsinyiteni kell");
        assert_eq!(out_width.max(out_height), SAMPLE_BOUND);

        let source_ratio = f64::from(width) / f64::from(height);
        let output_ratio = f64::from(out_width) / f64::from(out_height);
        assert!(
            (source_ratio - output_ratio).abs() < 0.01,
            "a keparany elcsuszott: {source_ratio} -> {output_ratio}"
        );

        let _ = std::fs::remove_dir_all(&dir);
    }

    /// A hatar alatti kepet nem bantjuk.
    #[test]
    fn small_image_is_not_resized() {
        let dir = std::env::temp_dir().join("vellum-material-small");
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("small.png");
        write_png(&path, 800, 600);

        assert!(sample_size(&path).is_none());

        let _ = std::fs::remove_dir_all(&dir);
    }

    fn write_png(path: &Path, width: u32, height: u32) {
        let img = image::RgbImage::from_pixel(width, height, image::Rgb([128, 128, 128]));
        image::DynamicImage::ImageRgb8(img).save(path).unwrap();
    }

    fn grey_png() -> Vec<u8> {
        use std::io::Cursor;
        let mut out = Vec::new();
        let img = image::RgbImage::from_pixel(64, 64, image::Rgb([128, 128, 128]));
        image::DynamicImage::ImageRgb8(img)
            .write_to(&mut Cursor::new(&mut out), image::ImageFormat::Png)
            .unwrap();
        out
    }
}

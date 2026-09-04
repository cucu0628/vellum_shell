//! Tema motor: paletta beolvasasa, generatorok futtatasa, allapot vezetese.

pub mod color;
pub mod generators;
pub mod material;
pub mod palette;
pub mod paths;
pub mod render;

use anyhow::{Context, Result};
use palette::{Palette, ThemeSummary};
use std::path::PathBuf;

pub const DYNAMIC_SLUG: &str = "dynamic-matugen";

/// Futtathat-e a generator rendszerszintu mellekhatast (`gsettings`,
/// `systemctl restart`, `magick`).
///
/// A `VELLUM_NO_SIDE_EFFECTS=1` kikapcsolja: a tesztek igy hasonlithatjak ossze
/// a generalt fajlokat anelkul, hogy az elo munkamenet portaljait ujrainditanak.
pub fn side_effects_enabled() -> bool {
    std::env::var_os("VELLUM_NO_SIDE_EFFECTS").is_none()
}

/// Az aktiv tema slugja. Ha a bejegyzes hianyzik vagy ervenytelen, az elso
/// elerheto temara esunk vissza -- ugyanugy, ahogy a `theme-read` tette.
pub fn current_slug() -> Option<String> {
    if let Some(slug) = paths::read_line_file(&paths::current_theme_file())
        && paths::theme_conf(&slug).is_file()
    {
        return Some(slug);
    }
    first_available_slug()
}

fn first_available_slug() -> Option<String> {
    let mut slugs: Vec<String> = std::fs::read_dir(paths::themes_dir())
        .ok()?
        .flatten()
        .filter_map(|entry| {
            let slug = entry.file_name().to_string_lossy().to_string();
            paths::theme_conf(&slug).is_file().then_some(slug)
        })
        .collect();
    slugs.sort();
    slugs.into_iter().next()
}

pub fn load(slug: &str) -> Result<Palette> {
    Palette::load(&paths::theme_conf(slug))
}

pub fn load_current() -> Result<Palette> {
    let slug = current_slug().context("nincs egyetlen hasznalhato tema sem")?;
    load(&slug)
}

/// Az osszes tema osszefoglaloja a valaszto szamara. A dinamikus tema mindig
/// elol all, a tobbi nev szerint rendezve -- ez a `theme-list` sorrendje.
pub fn list() -> Vec<ThemeSummary> {
    let current = current_slug();
    let mut dynamic = None;
    let mut statics = Vec::new();

    let Ok(entries) = std::fs::read_dir(paths::themes_dir()) else {
        return Vec::new();
    };

    for entry in entries.flatten() {
        let slug = entry.file_name().to_string_lossy().to_string();
        let Ok(palette) = Palette::load(&paths::theme_conf(&slug)) else {
            continue;
        };
        let summary = summarize(&slug, &palette, current.as_deref());
        if slug == DYNAMIC_SLUG {
            dynamic = Some(summary);
        } else {
            statics.push(summary);
        }
    }

    statics.sort_by(|a, b| a.name.cmp(&b.name));
    dynamic.into_iter().chain(statics).collect()
}

fn summarize(slug: &str, palette: &Palette, current: Option<&str>) -> ThemeSummary {
    ThemeSummary {
        name: palette.text(&["NAME"], slug),
        slug: slug.to_string(),
        background: palette.color(&["BACKGROUND"], "#1e1e2e"),
        foreground: palette.color(&["FOREGROUND"], "#cdd6f4"),
        accent: palette.color(&["ACCENT", "BORDER_FOREGROUND"], "#89b4fa"),
        surface: palette.color(&["SURFACE"], "#181825"),
        // A MUTED-ot a LIGHT_FOREGROUND felulirja, ha kesobb all a fajlban.
        muted: palette.color(&["MUTED", "LIGHT_FOREGROUND"], "#9399b2"),
        kind: if slug == DYNAMIC_SLUG { "dynamic".into() } else { "static".into() },
        icon_theme: generators::icon::resolve(palette),
        current: current == Some(slug),
    }
}

#[derive(Debug, serde::Serialize)]
pub struct ApplyReport {
    pub slug: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub wallpaper: Option<String>,
    pub palette: std::collections::BTreeMap<String, String>,
    pub generators: Vec<generators::Outcome>,
}

/// Egy tema (es opcionalisan hatterkep) alkalmazasa.
///
/// Tranzakciokent fut, mert a felig alkalmazott tema rosszabb, mint a regi:
///
///   1. **ervenyesites** -- letezik-e a tema es a hatterkep;
///   2. **paletta** -- a dinamikus temanal ez maga a generalas;
///   3. **generatorok** -- a kotelezoek hibaja itt megallit;
///   4. **commit** -- az allapotfajlok csak a legvegen, egyszerre irodnak ki.
///
/// Korabban a `current-theme` es a `current-wallpaper` legelol irodott ki. Egy
/// olvashatatlan hatterkep vagy egy elbukott generalas utan is az uj tema
/// maradt bejegyezve, es a kovetkezo indulaskor a shell egy sosem alkalmazott
/// temaval jott fel.
pub fn apply(slug: &str, wallpaper: Option<&str>, include_zen: bool) -> Result<ApplyReport> {
    let conf = paths::theme_conf(slug);
    // A dinamikus tema conf-ja generalt: meg nem letezhet az elso futaskor.
    if slug != DYNAMIC_SLUG && !conf.is_file() {
        anyhow::bail!("ismeretlen tema: {slug}");
    }
    if let Some(wallpaper) = wallpaper
        && !std::path::Path::new(wallpaper).is_file()
    {
        anyhow::bail!("a hatterkep nem letezik: {wallpaper}");
    }

    // Hatterkep nelkul a mar rogzitett allapotra esunk vissza; ez meg a regi
    // ertek, mert a commit csak a vegen jon. Ezt a generatoroknak is atadjuk:
    // maguktol a regi kepet olvasnak ki.
    let source = wallpaper
        .map(str::to_string)
        .or_else(|| paths::read_line_file(&paths::current_wallpaper_file()));

    let palette = if slug == DYNAMIC_SLUG {
        // A dinamikus paletta a hatterkepbol szuletik, ezert eloszor azt kell
        // eloallitani -- kulonben a generatorok az elozo kep szineit irnak ki.
        let source = source.as_deref().context("a dinamikus temahoz hatterkep kell")?;
        material::generate(std::path::Path::new(source))?
    } else {
        Palette::load(&conf)?
    };

    let outcomes =
        generators::run_all(&palette, source.as_deref().map(std::path::Path::new), include_zen);

    // Egy hianyzo Zen profil vagy a root nelkuli SDDM nem hiba. Egy sajat
    // fajlunk kiirhatatlansaga viszont igen: olyankor a tema nem lett
    // alkalmazva, es nem is jegyezzuk be.
    let failures = generators::required_failures(&outcomes);
    if !failures.is_empty() {
        anyhow::bail!("a tema nem alkalmazhato -- {}", failures.join("; "));
    }

    commit_state(slug, wallpaper)?;

    Ok(ApplyReport {
        slug: slug.to_string(),
        wallpaper: wallpaper.map(str::to_string),
        palette: palette.to_json(),
        generators: outcomes,
    })
}

/// A ket allapotfajl egyutt. Eloszor mindketto kiirodik egy ideiglenes fajlba,
/// es a rename-ek csak akkor kovetkeznek, ha mindketto sikerult -- kulonben egy
/// elbukott masodik iras utan a tema es a hatterkep nem ugyanarrol szolna.
fn commit_state(slug: &str, wallpaper: Option<&str>) -> Result<()> {
    let theme_file = paths::current_theme_file();
    let mut staged = vec![render::stage(&theme_file, &format!("{slug}\n"))?];

    if let Some(wallpaper) = wallpaper {
        let wallpaper_file = paths::current_wallpaper_file();
        staged.push(render::stage(&wallpaper_file, &format!("{wallpaper}\n"))?);
    }

    for entry in staged {
        entry.commit()?;
    }
    Ok(())
}

/// A hatterkepbol szarmaztatott paletta, allapotiras es generatorok nelkul.
/// A valaszto ezzel nezi meg elore a dinamikus temat, mielott commitolna.
pub fn preview_dynamic(wallpaper: &str) -> Result<Palette> {
    let path = std::path::Path::new(wallpaper);
    if !path.is_file() {
        anyhow::bail!("a hatterkep nem letezik: {wallpaper}");
    }
    material::palette_for(path)
}

pub fn set_wallpaper(path: &str) -> Result<()> {
    if !std::path::Path::new(path).is_file() {
        anyhow::bail!("a hatterkep nem letezik: {path}");
    }
    write_state(&paths::current_wallpaper_file(), path)?;

    // A greeter sajat masolatot tart a hatterkeprol, mert a `/home` 0700 alatt
    // nem eri el az eredetit. Enelkul a bejelentkezo kepernyo csak a kovetkezo
    // temavaltaskor kovetne a valtozast. Ha nincs paletta, nincs mit frissiteni.
    if let Ok(palette) = load_current() {
        let _ = generators::sddm::generate(&palette, Some(std::path::Path::new(path)));
    }
    Ok(())
}

#[derive(Debug, serde::Serialize)]
pub struct WallpaperEntry {
    pub name: String,
    pub path: String,
    pub current: bool,
}

/// A `~/Pictures/wallpapers` tartalma, ember altal olvashato nevekkel.
pub fn wallpapers() -> Vec<WallpaperEntry> {
    const EXTENSIONS: &[&str] = &["png", "jpg", "jpeg", "webp", "gif"];

    let current = paths::read_line_file(&paths::current_wallpaper_file());
    let dir = paths::home().join("Pictures/wallpapers");

    let Ok(entries) = std::fs::read_dir(&dir) else {
        return Vec::new();
    };

    let mut paths: Vec<PathBuf> = entries
        .flatten()
        .map(|entry| entry.path())
        .filter(|path| {
            path.is_file()
                && path
                    .extension()
                    .and_then(|ext| ext.to_str())
                    .is_some_and(|ext| EXTENSIONS.contains(&ext.to_lowercase().as_str()))
        })
        .collect();
    paths.sort();

    paths
        .into_iter()
        .map(|path| {
            let display = path.to_string_lossy().to_string();
            WallpaperEntry {
                name: humanize(&path),
                current: current.as_deref() == Some(display.as_str()),
                path: display,
            }
        })
        .collect()
}

/// "vellum-tokyo_night.png" -> "Tokyo Night"
fn humanize(path: &std::path::Path) -> String {
    let stem = path.file_stem().map(|s| s.to_string_lossy()).unwrap_or_default();
    let stem = stem.strip_prefix("vellum-").unwrap_or(&stem);

    stem.replace(['_', '-'], " ")
        .split_whitespace()
        .map(|word| {
            let mut chars = word.chars();
            match chars.next() {
                Some(first) => first.to_uppercase().collect::<String>() + chars.as_str(),
                None => String::new(),
            }
        })
        .collect::<Vec<_>>()
        .join(" ")
}

fn write_state(path: &PathBuf, value: &str) -> Result<()> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    std::fs::write(path, format!("{value}\n"))
        .with_context(|| format!("nem irhato: {}", path.display()))?;
    Ok(())
}

//! Fastfetch konfiguracio es logo.
//!
//! A tobbi generatortol elteroen itt `@KULCS@` markerek allnak a `{{KULCS}}`
//! helyorzok helyett: ugyanaz a helyettesites fut a configon es az SVG logon,
//! es az SVG-ben a kapcsos zarojel mast jelentene.
//!
//! A config harom helyrol johet, ebben a sorrendben:
//!   1. `~/.config/fastfetch/config.template.jsonc` -- a felhasznalo sajatja;
//!   2. `backend/templates/fastfetch-config.jsonc.tmpl` -- a repo sablonja;
//!   3. a binarisba forditott valtozat, hogy telepites nelkul is mukodjon.

use crate::theme::palette::Palette;
use crate::theme::paths;
use crate::theme::render::{load_template, write_if_changed};
use anyhow::Result;
use std::path::PathBuf;
use std::process::{Command, Stdio};

const BUILTIN_CONFIG: &str = include_str!("../../../templates/fastfetch-config.jsonc.tmpl");

pub fn generate(palette: &Palette) -> Result<Option<(PathBuf, bool)>> {
    let fastfetch_dir = paths::config_dir().join("fastfetch");

    // A sajat sablon elsobbseget elvez a repoban levo alap logo felett.
    let logo_template = {
        let user = fastfetch_dir.join("vellum.template.svg");
        if user.is_file() { user } else { paths::shell_dir().join("assets/vellum-logo.svg") }
    };
    if !logo_template.is_file() {
        return Ok(None);
    }

    std::fs::create_dir_all(&fastfetch_dir)?;

    let background = palette.color(&["BACKGROUND"], "#1e1e2e");
    let foreground = palette.color(&["FOREGROUND"], "#cdd6f4");
    let accent = palette.color(&["ACCENT", "BORDER_FOREGROUND"], "#89b4fa");
    let muted = palette.color(&["MUTED"], "#9399b2");
    let surface = palette.color(&["SURFACE"], "#181825");

    let recolor =
        |text: &str| recolor_markers(text, &background, &foreground, &accent, &muted, &surface);

    let mut changed = false;

    // A sajat sablon elsobbseget elvez: aki atirta, annak a valtozata nyer.
    let user_template = fastfetch_dir.join("config.template.jsonc");
    let config_source = if user_template.is_file() {
        std::fs::read_to_string(&user_template)?
    } else {
        load_template("fastfetch-config.jsonc.tmpl", BUILTIN_CONFIG)
    };
    changed |= write_if_changed(&fastfetch_dir.join("config.jsonc"), &recolor(&config_source))?;

    let svg_output = fastfetch_dir.join("vellum.svg");
    let rendered = recolor(&std::fs::read_to_string(&logo_template)?);
    // A PNG-t csak a logo valtozasa erinti, a config-e nem.
    let svg_changed = write_if_changed(&svg_output, &rendered)?;
    changed |= svg_changed;

    // A PNG csak akkor kell, ha van ImageMagick; a fastfetch enelkul is elmegy.
    if svg_changed && crate::theme::side_effects_enabled() {
        rasterize(&svg_output, &fastfetch_dir.join("vellum.png"));
    }

    Ok(Some((svg_output, changed)))
}

/// A `@KULCS@` markerek es a logo beegetett alapszinenek csereje.
///
/// Kulon fuggveny, hogy egysegteszttel rogzitheto legyen: a bemenete (az
/// `assets/vellum-logo.svg`) idokozben valtozhat, ezert a golden osszevetes
/// helyett a transzformaciot ellenorizzuk.
fn recolor_markers(
    text: &str,
    background: &str,
    foreground: &str,
    accent: &str,
    muted: &str,
    surface: &str,
) -> String {
    text.replace("@BACKGROUND@", background)
        .replace("@FOREGROUND@", foreground)
        .replace("@ACCENT@", accent)
        .replace("@MUTED@", muted)
        .replace("@SURFACE@", surface)
        // A logo alap kitoltese szo szerint szerepel az SVG-ben.
        .replace("#e8ddc7", foreground)
}

fn rasterize(svg: &std::path::Path, png: &std::path::Path) {
    // Idokorlattal: egy serult SVG-n a magick tud orokre pörögni, es a
    // temaalkalmazas kulonben vele egyutt allna meg.
    let mut command = Command::new("magick");
    command
        .arg("-background")
        .arg("none")
        .arg(svg)
        .args(["-trim", "+repage", "-resize", "768x768", "-strip"])
        .arg(png)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());
    if let Err(err) = crate::proc::run_command(command, "magick", crate::proc::LONG) {
        tracing::debug!(error = format!("{err:#}"), "a logo raszterizalasa kimaradt");
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn replaces_every_marker_and_the_baked_in_fill() {
        let source = r##"<svg fill="#e8ddc7"><rect fill="@ACCENT@"/><g a="@BACKGROUND@" b="@MUTED@" c="@FOREGROUND@" d="@SURFACE@"/></svg>"##;
        let output = recolor_markers(source, "#111111", "#222222", "#333333", "#444444", "#555555");

        assert!(output.contains(r##"fill="#222222""##), "{output}");
        assert!(output.contains(r##"fill="#333333""##), "{output}");
        assert!(output.contains(r##"a="#111111""##), "{output}");
        assert!(output.contains(r##"b="#444444""##), "{output}");
        assert!(output.contains(r##"c="#222222""##), "{output}");
        assert!(output.contains(r##"d="#555555""##), "{output}");
        for marker in ["@BACKGROUND@", "@FOREGROUND@", "@ACCENT@", "@MUTED@", "@SURFACE@"] {
            assert!(!output.contains(marker), "maradt feloldatlan marker: {marker}");
        }
        assert!(!output.contains("#e8ddc7"), "maradt beegetett szin: {output}");
    }

    #[test]
    fn text_without_markers_is_unchanged() {
        let source = "<svg><rect fill=\"#abcdef\"/></svg>";
        assert_eq!(recolor_markers(source, "#1", "#2", "#3", "#4", "#5"), source);
    }

    #[test]
    fn builtin_config_is_fully_rendered() {
        let output =
            recolor_markers(BUILTIN_CONFIG, "#111111", "#222222", "#333333", "#444444", "#555555");

        for marker in ["@BACKGROUND@", "@FOREGROUND@", "@ACCENT@", "@MUTED@", "@SURFACE@"] {
            assert!(!output.contains(marker), "maradt feloldatlan marker: {marker}");
        }
        assert!(output.contains(r#""key": " ""#), "a title kulcsa latszana: {output}");
        assert!(
            output.contains(r#""compactType": "original-with-refresh-rate""#),
            "a kijelzok nem kompaktak: {output}"
        );
    }
}

//! Fastfetch konfiguracio es logo.
//!
//! Ez a generator nem sajat sablonbol dolgozik, hanem a felhasznalo meglevo
//! `config.template.jsonc`-jat es az SVG logot szinezi at `@KULCS@` markerek
//! menten -- ezert tartja meg a script eredeti helyettesitesi szabalyait.

use crate::theme::palette::Palette;
use crate::theme::paths;
use crate::theme::render::write_if_changed;
use anyhow::Result;
use std::path::PathBuf;
use std::process::{Command, Stdio};

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

    let recolor = |text: &str| recolor_markers(text, &background, &foreground, &accent, &muted);

    let config_template = fastfetch_dir.join("config.template.jsonc");
    if config_template.is_file() {
        let rendered = recolor(&std::fs::read_to_string(&config_template)?);
        write_if_changed(&fastfetch_dir.join("config.jsonc"), &rendered)?;
    }

    let svg_output = fastfetch_dir.join("vellum.svg");
    let rendered = recolor(&std::fs::read_to_string(&logo_template)?);
    let changed = write_if_changed(&svg_output, &rendered)?;

    // A PNG csak akkor kell, ha van ImageMagick; a fastfetch enelkul is elmegy.
    if changed && crate::theme::side_effects_enabled() {
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
) -> String {
    text.replace("@BACKGROUND@", background)
        .replace("@FOREGROUND@", foreground)
        .replace("@ACCENT@", accent)
        .replace("@MUTED@", muted)
        // A logo alap kitoltese szo szerint szerepel az SVG-ben.
        .replace("#e8ddc7", foreground)
}

fn rasterize(svg: &std::path::Path, png: &std::path::Path) {
    let _ = Command::new("magick")
        .arg("-background")
        .arg("none")
        .arg(svg)
        .args(["-trim", "+repage", "-resize", "768x768", "-strip"])
        .arg(png)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn replaces_every_marker_and_the_baked_in_fill() {
        let source = r##"<svg fill="#e8ddc7"><rect fill="@ACCENT@"/><g a="@BACKGROUND@" b="@MUTED@" c="@FOREGROUND@"/></svg>"##;
        let output = recolor_markers(source, "#111111", "#222222", "#333333", "#444444");

        assert!(output.contains(r##"fill="#222222""##), "{output}");
        assert!(output.contains(r##"fill="#333333""##), "{output}");
        assert!(output.contains(r##"a="#111111""##), "{output}");
        assert!(output.contains(r##"b="#444444""##), "{output}");
        assert!(output.contains(r##"c="#222222""##), "{output}");
        assert!(!output.contains('@'), "maradt feloldatlan marker: {output}");
        assert!(!output.contains("#e8ddc7"), "maradt beegetett szin: {output}");
    }

    #[test]
    fn text_without_markers_is_unchanged() {
        let source = "<svg><rect fill=\"#abcdef\"/></svg>";
        assert_eq!(recolor_markers(source, "#1", "#2", "#3", "#4"), source);
    }
}

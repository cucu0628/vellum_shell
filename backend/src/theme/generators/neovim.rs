//! Neovim colorscheme (LazyVim es minden mas konfiguracio szamara).
//!
//! A kimenet a Neovim `site` mappajaba kerul, nem a felhasznalo nvim
//! configjaba: az a runtimepath resze, tehat a `:colorscheme vellum` megtalalja,
//! viszont egy generalt fajl nem kerul bele a felhasznalo config-repojaba.

use crate::theme::palette::Palette;
use crate::theme::render::{Vars, load_template, render, write_if_changed};
use crate::theme::{color, paths};
use anyhow::Result;
use std::path::PathBuf;

const BUILTIN: &str = include_str!("../../../templates/nvim-colors.lua.tmpl");

pub fn generate(palette: &Palette) -> Result<Option<(PathBuf, bool)>> {
    // Neovim nelkul a `site/colors` mappa letrehozasa csak szemetet hagyna.
    if !neovim_present() {
        return Ok(None);
    }

    let output = paths::nvim_colorscheme();
    let template = load_template("nvim-colors.lua.tmpl", BUILTIN);
    let changed = write_if_changed(&output, &render(&template, &vars(palette)))?;
    Ok(Some((output, changed)))
}

/// Van-e egyaltalan Neovim ezen a gepen. A konfig- es az adatmappa kozul
/// barmelyik eleg: az elobbi a sajat configot, az utobbi a mar futott Neovimot
/// jelenti.
fn neovim_present() -> bool {
    paths::config_dir().join("nvim").is_dir() || paths::data_dir().join("nvim").is_dir()
}

fn vars(palette: &Palette) -> Vars {
    let background = palette.color(&["BACKGROUND"], "#1e1e2e");
    let foreground = palette.color(&["FOREGROUND"], "#cdd6f4");
    let accent = palette.color(&["ACCENT", "BORDER_FOREGROUND"], "#89b4fa");
    let surface = palette.color(&["SURFACE"], "#181825");
    let muted = palette.color(&["MUTED"], "#9399b2");

    let bg_dark = palette
        .color_opt(&["DARK_BACKGROUND"])
        .unwrap_or_else(|| color::mix(&surface, &background, 70));
    let bg_dark = separated(bg_dark, &background, 88);
    let bg_darker = palette
        .color_opt(&["DARKER_BACKGROUND"])
        .unwrap_or_else(|| color::mix(&bg_dark, "#000000", 80));
    let bg_darker = separated(bg_darker, &bg_dark, 80);
    let bg_light = palette.color_opt(&["LIGHTER_BACKGROUND"]).unwrap_or_else(|| surface.clone());
    let fg_dim = palette.color_opt(&["DARK_FOREGROUND"]).unwrap_or_else(|| muted.clone());
    let fg_bright = palette.color_opt(&["BRIGHT_FOREGROUND"]).unwrap_or_else(|| foreground.clone());

    let blue = palette.color_opt(&["BLUE"]).unwrap_or_else(|| accent.clone());
    let red = palette.color_opt(&["RED"]).unwrap_or_else(|| color::mix("#f38ba8", &accent, 70));
    let yellow =
        palette.color_opt(&["YELLOW"]).unwrap_or_else(|| color::mix("#f9e2af", &accent, 70));
    let orange =
        palette.color_opt(&["ORANGE"]).unwrap_or_else(|| color::mix("#fab387", &accent, 70));
    let green = palette.color_opt(&["GREEN"]).unwrap_or_else(|| color::mix("#a6e3a1", &accent, 70));
    let cyan = palette.color_opt(&["CYAN"]).unwrap_or_else(|| color::mix(&accent, &foreground, 75));
    let magenta =
        palette.color_opt(&["MAGENTA"]).unwrap_or_else(|| color::mix("#cba6f7", &accent, 70));
    let brown = palette.color_opt(&["BROWN"]).unwrap_or_else(|| color::mix(&orange, &muted, 60));

    // A szerkeszto sajat arnyalatai: mindig a hatterbol keverve, hogy vilagos
    // temanal is halvany maradjon a kiemeles, ne pedig sotet folt.
    let selection =
        palette.color_opt(&["SELECTION"]).unwrap_or_else(|| color::mix(&accent, &background, 30));
    let cursorline = color::mix(&bg_light, &background, 45);
    let border = color::mix(&muted, &background, 45);
    let line_nr = color::mix(&fg_dim, &background, 70);
    let comment = fg_dim.clone();
    let search = color::mix(&yellow, &background, 30);

    let bright = |key: &str, base: &str| {
        palette.color_opt(&[key]).unwrap_or_else(|| color::mix(base, &foreground, 80))
    };

    let mut vars = Vars::new();
    vars.insert("MODE".into(), mode(palette));
    vars.insert("BACKGROUND".into(), background.clone());
    vars.insert("BACKGROUND_DARK".into(), bg_dark);
    vars.insert("BACKGROUND_DARKER".into(), bg_darker);
    vars.insert("BACKGROUND_LIGHT".into(), bg_light);
    vars.insert("SURFACE".into(), surface);
    vars.insert("FOREGROUND".into(), foreground.clone());
    vars.insert("FOREGROUND_DIM".into(), fg_dim);
    vars.insert("FOREGROUND_BRIGHT".into(), fg_bright);
    vars.insert("MUTED".into(), muted);
    vars.insert("COMMENT".into(), comment);
    vars.insert("ACCENT".into(), accent);
    vars.insert("SELECTION".into(), selection);
    vars.insert("CURSORLINE".into(), cursorline);
    vars.insert("BORDER".into(), border);
    vars.insert("LINE_NR".into(), line_nr);
    vars.insert("SEARCH".into(), search);
    vars.insert("DIFF_ADD".into(), color::mix(&green, &background, 18));
    vars.insert("DIFF_CHANGE".into(), color::mix(&blue, &background, 15));
    vars.insert("DIFF_DELETE".into(), color::mix(&red, &background, 18));
    vars.insert("DIFF_TEXT".into(), color::mix(&blue, &background, 30));
    vars.insert("BRIGHT_RED".into(), bright("BRIGHT_RED", &red));
    vars.insert("BRIGHT_YELLOW".into(), bright("BRIGHT_YELLOW", &yellow));
    vars.insert("BRIGHT_GREEN".into(), bright("BRIGHT_GREEN", &green));
    vars.insert("BRIGHT_CYAN".into(), bright("BRIGHT_CYAN", &cyan));
    vars.insert("BRIGHT_BLUE".into(), bright("BRIGHT_BLUE", &blue));
    vars.insert("BRIGHT_MAGENTA".into(), bright("BRIGHT_MAGENTA", &magenta));
    vars.insert("RED".into(), red);
    vars.insert("YELLOW".into(), yellow);
    vars.insert("ORANGE".into(), orange);
    vars.insert("GREEN".into(), green);
    vars.insert("CYAN".into(), cyan);
    vars.insert("BLUE".into(), blue);
    vars.insert("MAGENTA".into(), magenta);
    vars.insert("BROWN".into(), brown);
    vars
}

/// A lebego ablak, a statuszsor es a fulek csak akkor valnak el a szovegtol,
/// ha sajat hatteruk van. Nehany paletta -- tipikusan a hatterkepbol
/// szarmaztatott -- ugyanazt az erteket adja a ket kulcsra, ezert olyankor
/// magunk sotetitunk egyet rajta.
fn separated(candidate: String, reference: &str, weight: u32) -> String {
    if candidate == reference { color::mix(reference, "#000000", weight) } else { candidate }
}

/// A `vim.o.background` csak `dark` vagy `light` lehet. A paletta MODE mezoje
/// hianyozhat vagy elirhato: olyankor a hatter vilagossaga dont.
fn mode(palette: &Palette) -> String {
    let declared = palette.text(&["MODE"], "");
    match declared.to_ascii_lowercase().as_str() {
        "light" => "light".into(),
        "dark" => "dark".into(),
        _ => {
            let background = palette.color(&["BACKGROUND"], "#1e1e2e");
            if color::luminance(&background) > 127 { "light".into() } else { "dark".into() }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn render_slug(text: &str) -> String {
        render(BUILTIN, &vars(&Palette::parse(text)))
    }

    #[test]
    fn no_placeholder_survives_rendering() {
        let output = render_slug("NAME=Teszt\nMODE=dark\nBACKGROUND=#1e1e2e\nACCENT=#cba6f7\n");
        assert!(!output.contains("{{"), "feloldatlan helyorzo maradt:\n{output}");
    }

    #[test]
    fn the_palette_colors_reach_the_colorscheme() {
        let output = render_slug("BACKGROUND=#101112\nFOREGROUND=#eeeeee\nACCENT=#abcdef\n");
        assert!(output.contains("bg = \"#101112\""), "{output}");
        assert!(output.contains("fg = \"#eeeeee\""), "{output}");
        assert!(output.contains("accent = \"#abcdef\""), "{output}");
        assert!(output.contains("vim.g.colors_name = \"vellum\""), "{output}");
    }

    /// A hatterkepbol szarmaztatott paletta ugyanazt adja a BACKGROUND-ra es a
    /// DARK_BACKGROUND-ra; ott a lebego ablakok hatter nelkul maradnanak.
    #[test]
    fn a_flat_palette_still_gets_a_distinct_float_background() {
        let output = render_slug("BACKGROUND=#151218\nDARK_BACKGROUND=#151218\n");
        assert!(output.contains("bg = \"#151218\""), "{output}");
        assert!(!output.contains("bg_dark = \"#151218\""), "{output}");
    }

    #[test]
    fn declared_mode_wins() {
        assert!(render_slug("MODE=light\nBACKGROUND=#101112\n").contains("background = \"light\""));
        assert!(render_slug("MODE=dark\nBACKGROUND=#fafafa\n").contains("background = \"dark\""));
    }

    /// MODE nelkul (pl. egy kezzel irt paletta) a hatter vilagossaga dont,
    /// kulonben a vilagos tema sotet `background`-gal indulna.
    #[test]
    fn missing_mode_falls_back_to_the_background_luminance() {
        assert!(render_slug("BACKGROUND=#fafafa\n").contains("background = \"light\""));
        assert!(render_slug("BACKGROUND=#101112\n").contains("background = \"dark\""));
    }
}

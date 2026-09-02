//! Szinmuveletek. Ez valtja ki a `mix()` fuggvenyt, ami szo szerint 5+ bash
//! scriptben duplikalodott.
//!
//! A `mix` szandekosan a bash implementacio szemantikajat koveti -- csonkolo
//! egeszosztassal, nem kerekitessel -- hogy a generatorok kimenete byte-ra
//! egyezzen a korabbi scriptekevel.

/// `#rrggbb` alaku-e (a bash `valid_color()` megfeleloje).
pub fn is_valid(value: &str) -> bool {
    let Some(hex) = value.strip_prefix('#') else {
        return false;
    };
    hex.len() == 6 && hex.chars().all(|c| c.is_ascii_hexdigit())
}

/// Csatornakra bontja a `#rrggbb` szint. Ervenytelen bemenetre `None`.
pub fn to_rgb(value: &str) -> Option<(u32, u32, u32)> {
    if !is_valid(value) {
        return None;
    }
    let hex = &value[1..];
    Some((
        u32::from_str_radix(&hex[0..2], 16).ok()?,
        u32::from_str_radix(&hex[2..4], 16).ok()?,
        u32::from_str_radix(&hex[4..6], 16).ok()?,
    ))
}

pub fn from_rgb(r: u32, g: u32, b: u32) -> String {
    format!("#{r:02x}{g:02x}{b:02x}")
}

/// `first` sulyozott keverese `second`-del: a `weight` az elso szin szazaleka.
///
/// Pontosan a bash valtozat kepletet hasznalja:
/// `(a * weight + b * (100 - weight)) / 100`, csonkolo osztassal.
pub fn mix(first: &str, second: &str, weight: u32) -> String {
    let (Some(a), Some(b)) = (to_rgb(first), to_rgb(second)) else {
        return first.to_string();
    };
    let blend = |x: u32, y: u32| (x * weight + y * (100 - weight)) / 100;
    from_rgb(blend(a.0, b.0), blend(a.1, b.1), blend(a.2, b.2))
}

/// Egyszeru, sulyozott vilagossag 0..255 kozott. A bash generatorok ugyanezt a
/// kepletet hasznaljak a kontraszt-dontesekhez.
pub fn luminance(value: &str) -> u32 {
    match to_rgb(value) {
        Some((r, g, b)) => (r * 299 + g * 587 + b * 114) / 1000,
        None => 0,
    }
}

/// A szin arnyalata fokban (0..359), es a telitettseg delta-ja. Az `icon-theme`
/// script logikaja: nyers RGB-tavolsag helyett arnyalat szerint valaszt, mert a
/// Material paletta vilagos, deszaturalt akcentusai kulonben bezsnek latszanak.
pub fn hue_and_delta(value: &str) -> Option<(i32, u32)> {
    let (r, g, b) = to_rgb(value)?;
    let max = r.max(g).max(b);
    let min = r.min(g).min(b);
    let delta = max - min;
    if delta == 0 {
        return Some((0, 0));
    }

    // Egesz aritmetika, hogy a bash `((...))` kifejezesekkel egyezzen.
    let (r, g, b) = (r as i32, g as i32, b as i32);
    let delta_i = delta as i32;
    let hue = if max == r as u32 {
        let hue = 60 * (g - b) / delta_i;
        if hue < 0 { hue + 360 } else { hue }
    } else if max == g as u32 {
        60 * (b - r) / delta_i + 120
    } else {
        60 * (r - g) / delta_i + 240
    };

    Some((hue, delta))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mix_matches_bash_truncation() {
        // A bash csonkol, nem kerekit: (255*70 + 0*30)/100 = 178.5 -> 178 (0xb2).
        assert_eq!(mix("#ffffff", "#000000", 70), "#b2b2b2");
        assert_eq!(mix("#ffffff", "#000000", 100), "#ffffff");
        assert_eq!(mix("#ffffff", "#000000", 0), "#000000");
        assert_eq!(mix("#123456", "#123456", 50), "#123456");
    }

    #[test]
    fn validity() {
        assert!(is_valid("#aabbcc"));
        assert!(is_valid("#AABBCC"));
        assert!(!is_valid("aabbcc"));
        assert!(!is_valid("#aabbc"));
        assert!(!is_valid("#gggggg"));
        assert!(!is_valid(""));
    }

    #[test]
    fn invalid_mix_falls_back_to_first() {
        assert_eq!(mix("#ffffff", "nem szin", 50), "#ffffff");
    }
}

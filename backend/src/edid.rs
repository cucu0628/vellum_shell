//! Monitor-azonositas EDID-bol, a `/sys/class/drm` alol.
//!
//! Miert kell: a connector nevek megjelenito-szerverenkent kulonboznek. Ugyanaz
//! a kijelzo Waylanden `HDMI-A-1`, az SDDM greeter X szerveren viszont
//! `HDMI-A-0` (amdgpu), es meg az indexeles sem egyezik. Az EDID-bol olvasott
//! sorozatszam viszont mindket oldalon azonos, ezert azzal lehet biztosan
//! parositani.

use std::path::PathBuf;

/// Amit egy kijelzorol biztosan tudunk, fuggetlenul a megjelenito-szervertol.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct MonitorIdentity {
    /// Harombetus PnP gyartokod, pl. "AOC".
    pub manufacturer: String,
    /// A kijelzo neve az EDID leirobol, pl. "24G2W1G4".
    pub model: String,
    /// Sorozatszam az EDID leirobol. Ez az egyetlen mezo, ami ket azonos
    /// tipusu monitort is megkulonboztet.
    pub serial: String,
}

impl MonitorIdentity {
    /// Van-e barmi, amivel parositani lehet.
    pub fn is_usable(&self) -> bool {
        !self.serial.is_empty() || !self.model.is_empty()
    }
}

/// Egy kernel connector (pl. "HDMI-A-1") EDID-je.
pub fn identity_for_connector(connector: &str) -> Option<MonitorIdentity> {
    let path = edid_path(connector)?;
    // A sysfs binaris attributumok 0 meretet jelentenek, de olvashatoak, ezert
    // a meret alapjan sosem szabad kihagyni oket.
    let bytes = std::fs::read(&path).ok()?;
    parse(&bytes)
}

fn edid_path(connector: &str) -> Option<PathBuf> {
    let entries = std::fs::read_dir("/sys/class/drm").ok()?;
    for entry in entries.flatten() {
        let name = entry.file_name();
        // Egy nem-UTF8 bejegyzes csak ot magat ejtse ki, ne allitsa meg a
        // tobbi connector vizsgalatat.
        let Some(name) = name.to_str() else { continue };
        // A bejegyzesek "card<N>-<connector>" alakuak.
        let Some((_, suffix)) = name.split_once('-') else {
            continue;
        };
        if suffix == connector {
            let path = entry.path().join("edid");
            if path.exists() {
                return Some(path);
            }
        }
    }
    None
}

/// EDID 1.x fejlec + leirok. Csak azt olvassuk ki, amivel parositani lehet.
pub fn parse(edid: &[u8]) -> Option<MonitorIdentity> {
    if edid.len() < 128 {
        return None;
    }

    // A gyartokod harom 5 bites betu egy big-endian 16 bites szoban.
    let packed = u16::from_be_bytes([edid[8], edid[9]]);
    let letter = |shift: u16| (((packed >> shift) & 0x1f) as u8 + b'@') as char;
    let manufacturer: String =
        [letter(10), letter(5), letter(0)].into_iter().filter(|c| c.is_ascii_uppercase()).collect();

    let mut identity = MonitorIdentity { manufacturer, ..Default::default() };

    // Negy 18 bajtos leiro az 54. bajttol. A nullaval kezdodok szoveges
    // leirok; a tipus a 3. bajt: 0xFC = kijelzonev, 0xFF = sorozatszam.
    for chunk in edid[54..126].as_chunks::<18>().0 {
        if chunk[0..3] != [0, 0, 0] {
            continue;
        }
        let text = descriptor_text(&chunk[5..18]);
        match chunk[3] {
            0xfc => identity.model = text,
            0xff => identity.serial = text,
            _ => {}
        }
    }

    Some(identity)
}

/// A leiro szovege 0x0A-val zarul, es szokozokkel van feltoltve.
fn descriptor_text(bytes: &[u8]) -> String {
    bytes
        .iter()
        .take_while(|&&byte| byte != 0x0a)
        .map(|&byte| byte as char)
        .collect::<String>()
        .trim()
        .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Szintetikus EDID. Szandekosan nem valodi eszkoz adata: a repo nyilvanos,
    /// es egy sorozatszam azonositja a konkret peldanyt.
    fn synthetic_edid(model: &str, serial: &str) -> Vec<u8> {
        let mut edid = vec![0u8; 128];
        // "AOC" = A(1), O(15), C(3) -> 0b00001_01111_00011
        let packed: u16 = (1 << 10) | (15 << 5) | 3;
        edid[8..10].copy_from_slice(&packed.to_be_bytes());

        let mut write = |offset: usize, kind: u8, text: &str| {
            edid[offset + 3] = kind;
            let bytes = text.as_bytes();
            edid[offset + 5..offset + 5 + bytes.len()].copy_from_slice(bytes);
            if bytes.len() < 13 {
                edid[offset + 5 + bytes.len()] = 0x0a;
            }
        };
        write(54, 0xfc, model);
        write(72, 0xff, serial);
        edid
    }

    #[test]
    fn reads_manufacturer_model_and_serial() {
        let identity = parse(&synthetic_edid("24G2W1G4", "ABC123")).unwrap();
        assert_eq!(identity.manufacturer, "AOC");
        assert_eq!(identity.model, "24G2W1G4");
        assert_eq!(identity.serial, "ABC123");
        assert!(identity.is_usable());
    }

    #[test]
    fn descriptor_text_stops_at_terminator_and_trims() {
        assert_eq!(descriptor_text(b"ABC\x0a        "), "ABC");
        assert_eq!(descriptor_text(b"  PAD  \x0a     "), "PAD");
    }

    #[test]
    fn short_or_empty_edid_is_rejected() {
        assert!(parse(&[]).is_none());
        assert!(parse(&[0u8; 64]).is_none());
    }

    /// Ket azonos tipusu monitort csak a sorozatszam kulonboztet meg -- ez a
    /// gepen valoban elofordul, ezert kulon rogzitjuk.
    #[test]
    fn same_model_is_distinguished_by_serial() {
        let first = parse(&synthetic_edid("SAME", "SERIAL-1")).unwrap();
        let second = parse(&synthetic_edid("SAME", "SERIAL-2")).unwrap();
        assert_eq!(first.model, second.model);
        assert_ne!(first.serial, second.serial);
    }

    #[test]
    fn identity_without_any_text_is_not_usable() {
        assert!(!MonitorIdentity::default().is_usable());
    }
}

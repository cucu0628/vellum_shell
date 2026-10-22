//! A vagolap-elozmeny tarolasa.
//!
//! Felepites a lemezen (`$XDG_STATE_HOME/vellum-shell/clipboard/`):
//!   * `index.json`  -- a bejegyzesek leirasa, legujabb elol;
//!   * `blobs/<id>`  -- a nyers tartalom, pontosan ugy, ahogy a forras adta;
//!   * `thumbs/<id>.png` -- kepeknel egy kicsinyitett elonezet a panelnek.
//!
//! A tartalom kulon fajlban van, hogy az index kicsi maradjon: a panelnek csak
//! az elonezet kell, a teljes tartalmat csak masolaskor olvassuk vissza.

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

/// Ennyi nem rogzitett bejegyzest tartunk meg; a legregebbi esik ki.
pub const MAX_HISTORY: usize = 100;
/// Ennyi bejegyzes rogzitheto. A rogzitett elem nem esik ki az elozmenybol.
pub const MAX_PINNED: usize = 25;
/// Ennel nagyobb tartalmat nem tarolunk (pl. egy tobb szaz MB-os kep).
pub const MAX_ENTRY_BYTES: usize = 5 * 1024 * 1024;
/// A szoveges elonezet hossza karakterben.
const PREVIEW_CHARS: usize = 300;
/// A kep-elonezet maximalis merete (a panel 2x-es felbontasahoz).
const THUMB_WIDTH: u32 = 272;
const THUMB_HEIGHT: u32 = 224;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Kind {
    Text,
    Image,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Entry {
    pub id: u64,
    pub kind: Kind,
    pub mime: String,
    pub size: u64,
    /// A tartalom ujjlenyomata: ugyanaz a tartalom nem kerul be ketszer.
    pub hash: u64,
    /// Utoljara masolva (unix masodperc).
    pub time: u64,
    pub pinned: bool,
    /// Szovegnel az elso sorok egy sorba vonva; kepnel ures.
    pub preview: String,
    /// Kepnel a meret pixelben.
    #[serde(default)]
    pub width: u32,
    #[serde(default)]
    pub height: u32,
}

pub struct Store {
    dir: PathBuf,
    entries: Vec<Entry>,
    next_id: u64,
}

/// Mit tett egy uj tartalom a tarolassal.
#[derive(Debug, PartialEq, Eq)]
pub enum Added {
    New(u64),
    /// Mar bent volt: csak az elejere kerult.
    Moved(u64),
    /// Nem tarolando (ures vagy tul nagy).
    Skipped,
}

impl Store {
    pub fn default_dir() -> PathBuf {
        crate::theme::paths::state_dir().join("vellum-shell/clipboard")
    }

    /// Betolti az elozmenyt. Serult vagy hianyzo index ures elozmenyt ad, nem
    /// hibat: a vagolap-kezelonek akkor is el kell indulnia.
    pub fn open(dir: impl Into<PathBuf>) -> Self {
        let dir = dir.into();
        let entries: Vec<Entry> = std::fs::read(dir.join("index.json"))
            .ok()
            .and_then(|bytes| serde_json::from_slice(&bytes).ok())
            .unwrap_or_default();
        // Olyan bejegyzes, aminek eltunt a tartalma, nem masolhato vissza.
        let entries: Vec<Entry> = entries
            .into_iter()
            .filter(|entry| dir.join("blobs").join(entry.id.to_string()).exists())
            .collect();
        let next_id = entries.iter().map(|entry| entry.id).max().map_or(1, |id| id + 1);
        Self { dir, entries, next_id }
    }

    pub fn entries(&self) -> &[Entry] {
        &self.entries
    }

    fn blob_path(&self, id: u64) -> PathBuf {
        self.dir.join("blobs").join(id.to_string())
    }

    pub fn thumb_path(&self, id: u64) -> PathBuf {
        self.dir.join("thumbs").join(format!("{id}.png"))
    }

    /// Uj tartalom a vagolaprol.
    pub fn add(&mut self, mime: &str, data: &[u8]) -> Result<Added> {
        let kind = if mime.starts_with("image/") { Kind::Image } else { Kind::Text };
        if data.is_empty() || data.len() > MAX_ENTRY_BYTES {
            return Ok(Added::Skipped);
        }
        if kind == Kind::Text && String::from_utf8_lossy(data).trim().is_empty() {
            return Ok(Added::Skipped);
        }

        let hash = fingerprint(data);
        if let Some(index) = self
            .entries
            .iter()
            .position(|entry| entry.hash == hash && entry.size == data.len() as u64)
        {
            let mut entry = self.entries.remove(index);
            entry.time = now();
            let id = entry.id;
            self.entries.insert(0, entry);
            self.save()?;
            return Ok(Added::Moved(id));
        }

        let id = self.next_id;
        self.next_id += 1;

        std::fs::create_dir_all(self.dir.join("blobs"))?;
        write_atomic(&self.blob_path(id), data)?;

        let mut entry = Entry {
            id,
            kind,
            mime: mime.to_string(),
            size: data.len() as u64,
            hash,
            time: now(),
            pinned: false,
            preview: String::new(),
            width: 0,
            height: 0,
        };

        match kind {
            Kind::Text => entry.preview = text_preview(data),
            Kind::Image => match self.write_thumbnail(id, data) {
                Ok((width, height)) => {
                    entry.width = width;
                    entry.height = height;
                }
                // Egy nem dekodolhato kep is masolhato marad, csak elonezet nelkul.
                Err(err) => tracing::debug!(%err, "a vagolap-kep elonezete nem keszult el"),
            },
        }

        self.entries.insert(0, entry);
        self.trim();
        self.save()?;
        Ok(Added::New(id))
    }

    /// A legregebbi nem rogzitett bejegyzesek kiesnek a korlat felett.
    fn trim(&mut self) {
        let mut unpinned = 0;
        let mut drop = Vec::new();
        for entry in &self.entries {
            if entry.pinned {
                continue;
            }
            unpinned += 1;
            if unpinned > MAX_HISTORY {
                drop.push(entry.id);
            }
        }
        for id in drop {
            self.remove_files(id);
            self.entries.retain(|entry| entry.id != id);
        }
    }

    pub fn get(&self, id: u64) -> Option<&Entry> {
        self.entries.iter().find(|entry| entry.id == id)
    }

    pub fn data(&self, id: u64) -> Result<Vec<u8>> {
        std::fs::read(self.blob_path(id))
            .with_context(|| format!("a {id}. bejegyzes nem olvashato"))
    }

    pub fn delete(&mut self, id: u64) -> Result<bool> {
        let before = self.entries.len();
        self.entries.retain(|entry| entry.id != id);
        if self.entries.len() == before {
            return Ok(false);
        }
        self.remove_files(id);
        self.save()?;
        Ok(true)
    }

    /// Az elozmeny torlese. A rogzitett elemek maradnak -- ezert rogzitettek.
    pub fn clear(&mut self) -> Result<usize> {
        let removed: Vec<u64> =
            self.entries.iter().filter(|entry| !entry.pinned).map(|entry| entry.id).collect();
        for id in &removed {
            self.remove_files(*id);
        }
        self.entries.retain(|entry| entry.pinned);
        self.save()?;
        Ok(removed.len())
    }

    /// Rogzites vagy feloldas. Hibaval ter vissza, ha a rogzitesi keret betelt.
    pub fn set_pinned(&mut self, id: u64, pinned: bool) -> Result<bool, PinError> {
        let pinned_count = self.entries.iter().filter(|entry| entry.pinned).count();
        let entry =
            self.entries.iter_mut().find(|entry| entry.id == id).ok_or(PinError::NotFound)?;
        if entry.pinned == pinned {
            return Ok(false);
        }
        if pinned && pinned_count >= MAX_PINNED {
            return Err(PinError::Full);
        }
        entry.pinned = pinned;
        // Egy feloldott elem visszakerul a korlat ala.
        if !pinned {
            self.trim();
        }
        self.save().map_err(PinError::Io)?;
        Ok(true)
    }

    fn remove_files(&self, id: u64) {
        let _ = std::fs::remove_file(self.blob_path(id));
        let _ = std::fs::remove_file(self.thumb_path(id));
    }

    fn write_thumbnail(&self, id: u64, data: &[u8]) -> Result<(u32, u32)> {
        let image = image::load_from_memory(data)?;
        let (width, height) = (image.width(), image.height());
        let thumb = image.thumbnail(THUMB_WIDTH, THUMB_HEIGHT);
        std::fs::create_dir_all(self.dir.join("thumbs"))?;
        let path = self.thumb_path(id);
        let tmp = path.with_extension("png.tmp");
        thumb.save_with_format(&tmp, image::ImageFormat::Png)?;
        std::fs::rename(&tmp, &path)?;
        Ok((width, height))
    }

    fn save(&self) -> Result<()> {
        std::fs::create_dir_all(&self.dir)?;
        write_atomic(&self.dir.join("index.json"), &serde_json::to_vec(&self.entries)?)
    }

    /// A topic allapota: amit a panel megjelenit.
    pub fn snapshot(&self, available: bool) -> Value {
        let entries: Vec<Value> = self
            .entries
            .iter()
            .map(|entry| {
                let thumb = self.thumb_path(entry.id);
                json!({
                    "id": entry.id,
                    "kind": entry.kind,
                    "mime": entry.mime,
                    "size": entry.size,
                    "time": entry.time,
                    "pinned": entry.pinned,
                    "preview": entry.preview,
                    "width": entry.width,
                    "height": entry.height,
                    "thumb": if entry.kind == Kind::Image && thumb.exists() {
                        thumb.to_string_lossy().into_owned()
                    } else {
                        String::new()
                    },
                })
            })
            .collect();
        json!({
            "available": available,
            "maxHistory": MAX_HISTORY,
            "maxPinned": MAX_PINNED,
            "entries": entries,
        })
    }
}

#[derive(Debug, thiserror::Error)]
pub enum PinError {
    #[error("nincs ilyen bejegyzes")]
    NotFound,
    #[error("legfeljebb {MAX_PINNED} elem rogzitheto")]
    Full,
    #[error(transparent)]
    Io(anyhow::Error),
}

/// FNV-1a: futasok kozott stabil (a `DefaultHasher` nem az), es a cel csak a
/// duplikatumok felismerese, nem kriptografia.
fn fingerprint(data: &[u8]) -> u64 {
    let mut hash: u64 = 0xcbf2_9ce4_8422_2325;
    for byte in data {
        hash ^= u64::from(*byte);
        hash = hash.wrapping_mul(0x0100_0000_01b3);
    }
    hash
}

fn text_preview(data: &[u8]) -> String {
    // Csak az elejet nezzuk: egy 5 MB-os szoveg elonezetehez nem kell az egesz.
    let head = &data[..data.len().min(PREVIEW_CHARS * 4)];
    let text = String::from_utf8_lossy(head);
    let collapsed = text.split_whitespace().collect::<Vec<_>>().join(" ");
    collapsed.chars().take(PREVIEW_CHARS).collect()
}

fn now() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map_or(0, |duration| duration.as_secs())
}

fn write_atomic(path: &Path, data: &[u8]) -> Result<()> {
    let tmp = path.with_extension("tmp");
    std::fs::write(&tmp, data)?;
    std::fs::rename(&tmp, path)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_store() -> (Store, PathBuf) {
        let dir = std::env::temp_dir().join(format!(
            "vellum-clipboard-test-{}-{}",
            std::process::id(),
            fingerprint(format!("{:?}", std::thread::current().id()).as_bytes())
        ));
        let _ = std::fs::remove_dir_all(&dir);
        (Store::open(&dir), dir)
    }

    #[test]
    fn duplicates_move_to_the_top() {
        let (mut store, dir) = temp_store();
        let first = store.add("text/plain", b"alma").unwrap();
        store.add("text/plain", b"korte").unwrap();
        let again = store.add("text/plain", b"alma").unwrap();
        let Added::New(id) = first else { panic!("{first:?}") };
        assert_eq!(again, Added::Moved(id));
        assert_eq!(store.entries().len(), 2);
        assert_eq!(store.entries()[0].preview, "alma");
        let _ = std::fs::remove_dir_all(dir);
    }

    #[test]
    fn empty_and_blank_text_is_skipped() {
        let (mut store, dir) = temp_store();
        assert_eq!(store.add("text/plain", b"").unwrap(), Added::Skipped);
        assert_eq!(store.add("text/plain", b"  \n\t").unwrap(), Added::Skipped);
        assert!(store.entries().is_empty());
        let _ = std::fs::remove_dir_all(dir);
    }

    #[test]
    fn history_is_capped_but_pinned_entries_stay() {
        let (mut store, dir) = temp_store();
        let Added::New(pinned) = store.add("text/plain", b"rogzitett").unwrap() else { panic!() };
        store.set_pinned(pinned, true).unwrap();
        for i in 0..MAX_HISTORY + 5 {
            store.add("text/plain", format!("elem {i}").as_bytes()).unwrap();
        }
        assert_eq!(store.entries().iter().filter(|entry| !entry.pinned).count(), MAX_HISTORY);
        assert!(store.get(pinned).is_some());
        let _ = std::fs::remove_dir_all(dir);
    }

    #[test]
    fn clear_keeps_pinned_and_survives_reopen() {
        let (mut store, dir) = temp_store();
        let Added::New(keep) = store.add("text/plain", b"marad").unwrap() else { panic!() };
        store.add("text/plain", b"megy").unwrap();
        store.set_pinned(keep, true).unwrap();
        assert_eq!(store.clear().unwrap(), 1);
        let reopened = Store::open(&dir);
        assert_eq!(reopened.entries().len(), 1);
        assert_eq!(reopened.data(keep).unwrap(), b"marad");
        let _ = std::fs::remove_dir_all(dir);
    }

    #[test]
    fn images_get_a_thumbnail() {
        let (mut store, dir) = temp_store();
        let mut png = Vec::new();
        image::RgbImage::from_pixel(640, 480, image::Rgb([200, 40, 90]))
            .write_to(&mut std::io::Cursor::new(&mut png), image::ImageFormat::Png)
            .unwrap();
        let Added::New(id) = store.add("image/png", &png).unwrap() else { panic!() };
        let entry = store.get(id).unwrap();
        assert_eq!((entry.kind, entry.width, entry.height), (Kind::Image, 640, 480));
        assert!(store.thumb_path(id).exists());
        let _ = std::fs::remove_dir_all(dir);
    }

    #[test]
    fn preview_collapses_whitespace() {
        assert_eq!(text_preview(b"  egy\n\n  ketto\tharom "), "egy ketto harom");
    }
}

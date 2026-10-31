//! Sajat vagolap-kezelo: elozmeny, rogzites, visszamasolas.
//!
//! A DMS vagolap-kezelojenek mintajara a daemon maga figyeli a Wayland
//! vagolapot (`wlr-data-control`), es maga tarolja az elozmenyt -- nincs
//! szukseg cliphistre, `wl-paste --watch`-ra vagy `wl-copy`-ra.
//!
//! Ez az egyetlen `always_on` modul: az elozmenynek akkor is gyulnie kell,
//! amikor a shell eppen nem nezi.
//!
//! Ha a compositor jelzi, hogy a forras alkalmazas kilepett es a vagolap
//! kiurult, a legutobbi bejegyzest a daemon maga kinalja fel tovabb. A Hyprland
//! (0.56) ezt a jelzest a data-control eszkozoknek nem kuldi el, ott ez az ag
//! nem fut le; a teljes megoldas az lenne, ha a daemon minden masolaskor
//! atvenne a vagolapot az osszes formatummal -- ez viszont pl. a fajlkezelok
//! masolasat ronthatja el, ezert szandekosan nincs benne.

mod store;
mod wayland;

use crate::module::{MethodDescription, Module, ModuleDescription, ModuleError, StateSink};
use anyhow::Result;
use async_trait::async_trait;
use serde_json::{Value, json};
use std::sync::{Arc, Mutex};
use store::{Added, Kind, PinError, Store};
use tokio::sync::mpsc;
use wayland::{Command, Control, TEXT_MIMES, WatchEvent};

pub struct Clipboard {
    store: Arc<Mutex<Store>>,
    control: Mutex<Option<Control>>,
}

impl Default for Clipboard {
    fn default() -> Self {
        Self::new()
    }
}

impl Clipboard {
    pub fn new() -> Self {
        Self {
            store: Arc::new(Mutex::new(Store::open(Store::default_dir()))),
            control: Mutex::new(None),
        }
    }

    fn available(&self) -> bool {
        self.control.lock().map(|control| control.is_some()).unwrap_or(false)
    }

    fn snapshot(&self) -> Value {
        let available = self.available();
        match self.store.lock() {
            Ok(store) => store.snapshot(available),
            Err(_) => json!({ "available": available, "entries": [] }),
        }
    }

    /// A tarolo muveletei fajlt irnak: a tokio-szalon kivul futnak.
    async fn with_store<T: Send + 'static>(
        &self,
        work: impl FnOnce(&mut Store) -> T + Send + 'static,
    ) -> Result<T> {
        let store = Arc::clone(&self.store);
        tokio::task::spawn_blocking(move || {
            let mut store =
                store.lock().map_err(|_| anyhow::anyhow!("a vagolap-tarolo zarolasa serult"))?;
            Ok(work(&mut store))
        })
        .await?
    }

    /// Egy tarolt bejegyzes visszatetele a vagolapra.
    async fn copy(&self, id: u64) -> Result<()> {
        let (kind, mime, data) = self
            .with_store(move |store| -> Result<_> {
                let entry = store
                    .get(id)
                    .ok_or_else(|| ModuleError::not_found(format!("nincs {id}. bejegyzes")))?;
                Ok((entry.kind, entry.mime.clone(), store.data(id)?))
            })
            .await??;

        let mimes = match kind {
            Kind::Text => TEXT_MIMES.iter().map(|mime| mime.to_string()).collect(),
            Kind::Image => vec![mime],
        };

        let control =
            self.control.lock().ok().and_then(|control| control.clone()).ok_or_else(|| {
                ModuleError::failed("a vagolap nem erheto el (nincs Wayland-kapcsolat)")
            })?;
        control.send(Command::SetSelection { mimes, data: Arc::new(data) })
    }

    fn id_param(params: &Value) -> Result<u64> {
        params
            .get("id")
            .and_then(Value::as_u64)
            .ok_or_else(|| ModuleError::invalid_params("hianyzik az 'id'").into())
    }
}

#[async_trait]
impl Module for Clipboard {
    fn name(&self) -> &'static str {
        "clipboard"
    }

    fn always_on(&self) -> bool {
        true
    }

    fn describe(&self) -> ModuleDescription {
        ModuleDescription {
            topic: "clipboard",
            summary: "Vagolap-elozmeny szoveggel es kepekkel, rogzitheto elemekkel.",
            streams: true,
            methods: vec![
                MethodDescription::new("history", "A teljes elozmeny (ugyanaz, mint a topic)."),
                MethodDescription::new("copy", "Egy bejegyzes visszatetele a vagolapra.").param(
                    "id",
                    "number",
                    true,
                    "A bejegyzes azonositoja.",
                ),
                MethodDescription::new("delete", "Egy bejegyzes torlese.").param(
                    "id",
                    "number",
                    true,
                    "A bejegyzes azonositoja.",
                ),
                MethodDescription::new(
                    "clear",
                    "Az elozmeny torlese; a rogzitett elemek maradnak.",
                ),
                MethodDescription::new("pin", "Bejegyzes rogzitese: nem esik ki az elozmenybol.")
                    .param("id", "number", true, "A bejegyzes azonositoja."),
                MethodDescription::new("unpin", "A rogzites feloldasa.").param(
                    "id",
                    "number",
                    true,
                    "A bejegyzes azonositoja.",
                ),
            ],
        }
    }

    async fn run(self: Arc<Self>, sink: StateSink) -> Result<()> {
        let (tx, mut rx) = mpsc::unbounded_channel();
        let started = wayland::spawn(tx);

        let (control, thread) = match started {
            Ok(pair) => pair,
            Err(err) => {
                // Az elozmeny Wayland nelkul is olvashato; az ujraprobalkozast a
                // hub vegzi novekvo kozokkel.
                sink.push(self.snapshot());
                return Err(err);
            }
        };
        if let Ok(mut slot) = self.control.lock() {
            *slot = Some(control);
        }
        sink.push(self.snapshot());

        while let Some(event) = rx.recv().await {
            match event {
                WatchEvent::Captured { mime, data } => {
                    let added = self.with_store(move |store| store.add(&mime, &data)).await?;
                    match added {
                        Ok(Added::Skipped) => {}
                        Ok(_) => sink.push(self.snapshot()),
                        Err(err) => tracing::warn!(%err, "a vagolap tartalma nem tarolhato"),
                    }
                }
                WatchEvent::Cleared => {
                    // A legutobbi bejegyzest kinaljuk fel tovabb.
                    let newest = self
                        .with_store(|store| store.entries().first().map(|entry| entry.id))
                        .await?;
                    if let Some(id) = newest
                        && let Err(err) = self.copy(id).await
                    {
                        tracing::debug!(%err, "a vagolap nem allithato vissza");
                    }
                }
            }
        }

        if let Ok(mut slot) = self.control.lock() {
            *slot = None;
        }
        sink.push(self.snapshot());
        match thread.join() {
            Ok(Err(err)) => Err(err),
            _ => Err(anyhow::anyhow!("a vagolap-figyelo varatlanul leallt")),
        }
    }

    async fn call(self: Arc<Self>, method: &str, params: Value, sink: &StateSink) -> Result<Value> {
        let result = match method {
            "history" => return Ok(self.snapshot()),
            "copy" => {
                let id = Self::id_param(&params)?;
                self.copy(id).await?;
                json!({ "copied": id })
            }
            "delete" => {
                let id = Self::id_param(&params)?;
                if !self.with_store(move |store| store.delete(id)).await?? {
                    return Err(ModuleError::not_found(format!("nincs {id}. bejegyzes")).into());
                }
                json!({ "deleted": id })
            }
            "clear" => {
                let removed = self.with_store(|store| store.clear()).await??;
                json!({ "removed": removed })
            }
            "pin" | "unpin" => {
                let id = Self::id_param(&params)?;
                let pinned = method == "pin";
                match self.with_store(move |store| store.set_pinned(id, pinned)).await? {
                    Ok(_) => json!({ "id": id, "pinned": pinned }),
                    Err(PinError::NotFound) => {
                        return Err(ModuleError::not_found(format!("nincs {id}. bejegyzes")).into());
                    }
                    Err(err @ PinError::Full) => {
                        return Err(ModuleError::failed(err.to_string()).into());
                    }
                    Err(PinError::Io(err)) => return Err(err),
                }
            }
            other => return Err(ModuleError::UnknownMethod(other.to_string()).into()),
        };
        sink.push(self.snapshot());
        Ok(result)
    }
}

//! A hub koti ossze a modulokat a kliensekkel.
//!
//! Feladatai:
//!   * topiconkent tarolja az utolso allapotot (snapshot), hogy egy uj kliens
//!     azonnal teljes kepet kapjon -- ne legyen hidegindulasi lyuk;
//!   * szetszorja a valtozasokat a feliratkozoknak;
//!   * **lazy topicok**: egy modul streamelo hurka csak akkor fut, ha van
//!     feliratkozoja. Ez tartja ~0%-on a CPU-t idle-ben.

use crate::ipc::protocol::Event;
use crate::module::{Module, ModuleDescription, ModuleError, StateSink};
use anyhow::Result;
use serde_json::Value;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::{Mutex, RwLock, broadcast, mpsc};
use tokio::task::JoinHandle;

/// Mennyi eventet tartunk vissza egy lassu kliensnek, mielott lemaradna.
/// Lemaradas eseten a kliens ujrakuldi magat a snapshotokkal (lasd server.rs).
const BROADCAST_CAPACITY: usize = 256;

struct TopicRuntime {
    subscribers: usize,
    task: Option<JoinHandle<()>>,
}

pub struct Hub {
    modules: HashMap<&'static str, Arc<dyn Module>>,
    snapshots: RwLock<HashMap<String, Value>>,
    events: broadcast::Sender<Event>,
    sink_tx: mpsc::UnboundedSender<(String, Value)>,
    runtimes: Mutex<HashMap<&'static str, TopicRuntime>>,
}

impl Hub {
    /// Letrehozza a hubot es elinditja a publikalo hurkot.
    pub fn new(modules: Vec<Arc<dyn Module>>) -> Arc<Self> {
        let (events, _) = broadcast::channel(BROADCAST_CAPACITY);
        let (sink_tx, mut sink_rx) = mpsc::unbounded_channel::<(String, Value)>();

        let mut map = HashMap::new();
        for module in modules {
            let name = module.name();
            if map.insert(name, module).is_some() {
                // Programozoi hiba a registryben; hangosan jelezzuk.
                panic!("ket modul ugyanazzal a nevvel: {name}");
            }
        }

        let hub = Arc::new(Self {
            modules: map,
            snapshots: RwLock::new(HashMap::new()),
            events,
            sink_tx,
            runtimes: Mutex::new(HashMap::new()),
        });

        // Publikalo hurok: a modulok pusholt allapota itt lesz snapshot + event.
        let publisher = Arc::clone(&hub);
        tokio::spawn(async move {
            while let Some((topic, data)) = sink_rx.recv().await {
                publisher.snapshots.write().await.insert(topic.clone(), data.clone());
                // Hiba csak akkor van, ha nincs egy feliratkozo sem -- ez normalis.
                let _ = publisher.events.send(Event { topic, data });
            }
        });

        hub
    }

    pub fn subscribe_events(&self) -> broadcast::Receiver<Event> {
        self.events.subscribe()
    }

    pub fn has_topic(&self, topic: &str) -> bool {
        self.modules.contains_key(topic)
    }

    pub async fn snapshot(&self, topic: &str) -> Option<Value> {
        self.snapshots.read().await.get(topic).cloned()
    }

    pub fn describe(&self) -> Vec<ModuleDescription> {
        let mut out: Vec<_> = self.modules.values().map(|m| m.describe()).collect();
        out.sort_by_key(|d| d.topic);
        out
    }

    fn sink_for(&self, topic: &'static str) -> StateSink {
        StateSink::new(topic, self.sink_tx.clone())
    }

    /// Egy parancs kiszolgalasa. Fut akkor is, ha a topicra senki nem iratkozott
    /// fel -- a CLI (`vellum theme apply ...`) pont igy hasznalja.
    pub async fn call(&self, domain: &str, method: &str, params: Value) -> Result<Value> {
        let module = self
            .modules
            .get(domain)
            .ok_or_else(|| ModuleError::not_found(format!("ismeretlen domain: {domain}")))?;
        let sink = self.sink_for(module.name());
        Arc::clone(module).call(method, params, &sink).await
    }

    /// Feliratkozas: ha ez az elso erdeklodo, elinditja a modul streamelo hurkat.
    pub async fn acquire(self: &Arc<Self>, topic: &str) -> Result<()> {
        let module = self
            .modules
            .get(topic)
            .ok_or_else(|| ModuleError::not_found(format!("ismeretlen topic: {topic}")))?;
        let name = module.name();

        let mut runtimes = self.runtimes.lock().await;
        let entry = runtimes
            .entry(name)
            .or_insert(TopicRuntime { subscribers: 0, task: None });
        entry.subscribers += 1;

        if entry.subscribers == 1 && entry.task.is_none() {
            let module = Arc::clone(module);
            let sink = self.sink_for(name);
            tracing::debug!(topic = name, "streamelo hurok indul");
            entry.task = Some(tokio::spawn(async move {
                if let Err(err) = module.run(sink).await {
                    tracing::error!(topic = name, error = format!("{err:#}"), "modul hurok hibaval allt le");
                }
            }));
        }

        Ok(())
    }

    /// Leiratkozas: az utolso feliratkozo utan leallitja a streamelo hurkot.
    pub async fn release(&self, topic: &str) {
        let Some(module) = self.modules.get(topic) else {
            return;
        };
        let name = module.name();

        let mut runtimes = self.runtimes.lock().await;
        let Some(entry) = runtimes.get_mut(name) else {
            return;
        };
        entry.subscribers = entry.subscribers.saturating_sub(1);

        if entry.subscribers == 0
            && let Some(task) = entry.task.take()
        {
            tracing::debug!(topic = name, "streamelo hurok leall (nincs feliratkozo)");
            task.abort();
        }
    }
}

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
use serde_json::{Value, json};
use std::collections::{BTreeMap, HashMap};
use std::sync::{Arc, LazyLock, RwLock as StdRwLock};
use std::time::Duration;
use tokio::sync::{Mutex, RwLock, broadcast, mpsc};
use tokio::task::JoinHandle;

/// Mennyi eventet tartunk vissza egy lassu kliensnek, mielott lemaradna.
/// Lemaradas eseten a kliens ujrakuldi magat a snapshotokkal (lasd server.rs).
const BROADCAST_CAPACITY: usize = 256;

/// A modulok allapot-sora. Kotott: lasd `StateSink::push`.
const SINK_CAPACITY: usize = 1024;

/// Egy hibaval leallt modul ujrainditasi hatarai. Az elso ujraindulas gyors,
/// egy tartosan halott fuggoseget viszont nem pergetunk masodpercenkent.
const RESTART_MIN: Duration = Duration::from_secs(1);
const RESTART_MAX: Duration = Duration::from_secs(60);

/// Modulonkenti egeszseg: mit csinal a streamelo hurok, es ha elszallt, miert.
///
/// Processzenkent egy hub van, ezert ez globalis: igy a `health` modul el tudja
/// erni anelkul, hogy a registry-nek at kellene adni egy hub-referenciat, amit
/// a hub letrejotte elott meg senki nem tudna megadni.
static MODULE_HEALTH: LazyLock<StdRwLock<BTreeMap<&'static str, Value>>> =
    LazyLock::new(|| StdRwLock::new(BTreeMap::new()));

/// A modulok jelenlegi allapota, a `health` topic szamara.
pub fn module_health() -> Value {
    match MODULE_HEALTH.read() {
        Ok(map) => json!(map.clone()),
        Err(_) => json!({}),
    }
}

fn set_module_health(topic: &'static str, state: &str, error: Option<String>) {
    let mut entry = json!({ "state": state });
    if let Some(error) = error {
        entry["error"] = json!(error);
    }
    if let Ok(mut map) = MODULE_HEALTH.write() {
        map.insert(topic, entry);
    }
}

struct TopicRuntime {
    subscribers: usize,
    task: Option<JoinHandle<()>>,
}

pub struct Hub {
    modules: HashMap<&'static str, Arc<dyn Module>>,
    snapshots: RwLock<HashMap<String, Value>>,
    events: broadcast::Sender<Event>,
    sink_tx: mpsc::Sender<(String, Value)>,
    runtimes: Mutex<HashMap<&'static str, TopicRuntime>>,
}

impl Hub {
    /// Letrehozza a hubot es elinditja a publikalo hurkot.
    pub fn new(modules: Vec<Arc<dyn Module>>) -> Arc<Self> {
        let (events, _) = broadcast::channel(BROADCAST_CAPACITY);
        let (sink_tx, mut sink_rx) = mpsc::channel::<(String, Value)>(SINK_CAPACITY);

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
        let entry = runtimes.entry(name).or_insert(TopicRuntime { subscribers: 0, task: None });
        entry.subscribers += 1;

        if entry.subscribers == 1 && entry.task.is_none() {
            let module = Arc::clone(module);
            let sink = self.sink_for(name);
            let hub = Arc::clone(self);
            tracing::debug!(topic = name, "streamelo hurok indul");
            entry.task = Some(tokio::spawn(hub.supervise(module, sink, name)));
        }

        Ok(())
    }

    /// Egy modul streamelo hurkanak felugyelete.
    ///
    /// Korabban egy hibaval leallt hurok halott maradt, amig volt feliratkozoja:
    /// a topic befagyott, es a shell az utolso -- immar hazug -- snapshotot
    /// mutatta a vegtelensegig. Most novekvo varakozassal ujraindul, es az
    /// allapota lathato a `health` topicon.
    ///
    /// A taszkot a `release` abortalja, amikor az utolso feliratkozo is elment,
    /// tehat a hurok nem el tul a rá valo igenyen.
    async fn supervise(
        self: Arc<Self>,
        module: Arc<dyn Module>,
        sink: StateSink,
        name: &'static str,
    ) {
        let mut backoff = RESTART_MIN;

        loop {
            set_module_health(name, "running", None);
            self.publish_health().await;

            match Arc::clone(&module).run(sink.clone()).await {
                Ok(()) => {
                    // Egy nem streamelo modul (alapertelmezett `run`) rendben
                    // vegzett: nincs mit ujrainditani.
                    set_module_health(name, "idle", None);
                    self.publish_health().await;
                    return;
                }
                Err(err) => {
                    let message = format!("{err:#}");
                    tracing::error!(
                        topic = name,
                        error = %message,
                        retry_in_ms = backoff.as_millis() as u64,
                        "modul hurok hibaval allt le, ujraindul"
                    );
                    set_module_health(name, "restarting", Some(message));
                    self.publish_health().await;
                }
            }

            tokio::time::sleep(backoff).await;
            backoff = (backoff * 2).min(RESTART_MAX);
        }
    }

    /// A `health` snapshot ujrakuldese, ha valaki figyeli. A modulallapotot a
    /// health modul olvassa be a globalis terkepbol, ezert eleg ujrakerni tole.
    async fn publish_health(&self) {
        if self.snapshots.read().await.contains_key("health")
            && let Ok(data) = self.call("health", "ping", Value::Null).await
        {
            self.sink_for("health").push(data);
        }
    }

    /// Hany elo feliratkozoja van a topicnak. A szerver oldali szamlalas
    /// helyesseget ez teszi ellenorizhetove.
    pub async fn subscriber_count(&self, topic: &str) -> usize {
        self.runtimes.lock().await.get(topic).map_or(0, |entry| entry.subscribers)
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::module::{MethodDescription, ModuleDescription, StateSink};
    use std::sync::atomic::{AtomicUsize, Ordering};

    /// Modul, ami az elso ket futasan elszall, aztan megall streamelni.
    struct Flaky {
        topic: &'static str,
        runs: Arc<AtomicUsize>,
    }

    #[async_trait::async_trait]
    impl Module for Flaky {
        fn name(&self) -> &'static str {
            self.topic
        }

        fn describe(&self) -> ModuleDescription {
            ModuleDescription {
                topic: self.topic,
                summary: "teszt modul",
                streams: true,
                methods: vec![MethodDescription::new("ping", "teszt")],
            }
        }

        async fn run(self: Arc<Self>, sink: StateSink) -> Result<()> {
            let attempt = self.runs.fetch_add(1, Ordering::SeqCst);
            if attempt < 2 {
                anyhow::bail!("szandekos hiba a {attempt}. futasban");
            }
            sink.push(json!({ "ok": true }));
            std::future::pending::<()>().await;
            Ok(())
        }
    }

    /// Modul, aminek nincs streamje: az alapertelmezett `run` azonnal vegez.
    struct Quiet;

    #[async_trait::async_trait]
    impl Module for Quiet {
        fn name(&self) -> &'static str {
            "quiet"
        }

        fn describe(&self) -> ModuleDescription {
            ModuleDescription {
                topic: "quiet",
                summary: "teszt modul",
                streams: false,
                methods: Vec::new(),
            }
        }
    }

    /// Egy hibaval leallt hurok korabban halott maradt, amig volt feliratkozoja:
    /// a topic befagyott es a shell a regi allapotot mutatta tovabb.
    #[tokio::test(start_paused = true)]
    async fn a_failing_module_is_restarted_until_it_holds() {
        let runs = Arc::new(AtomicUsize::new(0));
        let hub = Hub::new(vec![
            Arc::new(Flaky { topic: "flaky", runs: Arc::clone(&runs) }) as Arc<dyn Module>
        ]);

        hub.acquire("flaky").await.unwrap();
        tokio::time::sleep(Duration::from_secs(30)).await;

        assert!(runs.load(Ordering::SeqCst) >= 3, "a modul nem indult ujra");
        assert_eq!(
            module_health().get("flaky").and_then(|entry| entry["state"].as_str()),
            Some("running"),
            "a harmadik futas mar megall, tehat futonak kell latszania"
        );
        assert!(hub.snapshot("flaky").await.is_some(), "az ujraindult modul nem tolt allapotot");
    }

    /// Egy nem streamelo modul rendben befejezi a `run`-t; ezt nem indítjuk
    /// ujra a vegtelensegig.
    #[tokio::test(start_paused = true)]
    async fn a_module_without_a_stream_is_not_restarted() {
        let hub = Hub::new(vec![Arc::new(Quiet) as Arc<dyn Module>]);

        hub.acquire("quiet").await.unwrap();
        tokio::time::sleep(Duration::from_secs(30)).await;

        assert_eq!(
            module_health().get("quiet").and_then(|entry| entry["state"].as_str()),
            Some("idle")
        );
    }

    /// Az utolso feliratkozo utan a felugyelo taszk is elmegy.
    #[tokio::test(start_paused = true)]
    async fn releasing_the_last_subscriber_stops_the_supervisor() {
        let runs = Arc::new(AtomicUsize::new(0));
        let hub =
            Hub::new(vec![Arc::new(Flaky { topic: "flaky-release", runs: Arc::clone(&runs) })
                as Arc<dyn Module>]);

        hub.acquire("flaky-release").await.unwrap();
        tokio::time::sleep(Duration::from_secs(5)).await;
        hub.release("flaky-release").await;

        let after_release = runs.load(Ordering::SeqCst);
        tokio::time::sleep(Duration::from_secs(120)).await;
        assert_eq!(
            runs.load(Ordering::SeqCst),
            after_release,
            "a hurok a leiratkozas utan is futott"
        );
    }
}

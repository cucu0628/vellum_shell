//! A modul absztrakcio: ez adja a bovithetoseget.
//!
//! Egy uj kepesseg hozzaadasa = egy uj fajl a `modules/` alatt, ami implementalja
//! a [`Module`] traitet, plusz egy sor a `modules::registry()` fuggvenyben.
//!
//! A modulok `Arc<Self>`-en dolgoznak, mert a streamelo [`Module::run`] es a
//! parancsokat kiszolgalo [`Module::call`] parhuzamosan fut. Ahol egy modulnak
//! mutalhato allapotra van szuksege, ott sajat `Mutex`-et hasznal -- igy a
//! zarolas lokalis marad es nem blokkolja a tobbi modult.

use async_trait::async_trait;
use serde::Serialize;
use serde_json::Value;
use std::sync::Arc;
use tokio::sync::mpsc;

/// Egy modul onleirasa a `describe` protokoll-muvelethez. Ez a szerzodes egy
/// jovobeli settings app fele: a kliensek ebbol tudjak meg, mi elerheto,
/// ahelyett hogy bedrotoznak metodusneveket.
#[derive(Debug, Clone, Serialize)]
pub struct ModuleDescription {
    pub topic: &'static str,
    pub summary: &'static str,
    /// Tol-e allapotot magatol (van-e ertelme feliratkozni ra).
    pub streams: bool,
    pub methods: Vec<MethodDescription>,
}

#[derive(Debug, Clone, Serialize)]
pub struct MethodDescription {
    pub name: &'static str,
    pub summary: &'static str,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub params: Vec<ParamDescription>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ParamDescription {
    pub name: &'static str,
    /// "string" | "number" | "bool" | "object" | "array"
    pub kind: &'static str,
    pub required: bool,
    pub summary: &'static str,
}

impl MethodDescription {
    pub fn new(name: &'static str, summary: &'static str) -> Self {
        Self { name, summary, params: Vec::new() }
    }

    pub fn param(
        mut self,
        name: &'static str,
        kind: &'static str,
        required: bool,
        summary: &'static str,
    ) -> Self {
        self.params.push(ParamDescription { name, kind, required, summary });
        self
    }
}

/// Strukturalt modulhiba. A `code` az, amit a kliens gepileg vizsgalhat; az
/// uzenet embernek szol. A protokoll sosem bukik nemaan.
#[derive(Debug, thiserror::Error)]
pub enum ModuleError {
    #[error("unknown method: {0}")]
    UnknownMethod(String),
    #[error("invalid params: {0}")]
    InvalidParams(String),
    #[error("not found: {0}")]
    NotFound(String),
    #[error("{0}")]
    Failed(String),
}

impl ModuleError {
    pub fn code(&self) -> &'static str {
        match self {
            Self::UnknownMethod(_) => "unknown_method",
            Self::InvalidParams(_) => "invalid_params",
            Self::NotFound(_) => "not_found",
            Self::Failed(_) => "failed",
        }
    }

    pub fn invalid_params(msg: impl Into<String>) -> Self {
        Self::InvalidParams(msg.into())
    }

    pub fn not_found(msg: impl Into<String>) -> Self {
        Self::NotFound(msg.into())
    }

    pub fn failed(msg: impl Into<String>) -> Self {
        Self::Failed(msg.into())
    }
}

/// Ezen keresztul tol egy modul allapotot. A hub veszi at a masik vegen:
/// eltarolja snapshotkent es szetszorja a feliratkozoknak.
#[derive(Clone)]
pub struct StateSink {
    topic: &'static str,
    tx: mpsc::Sender<(String, Value)>,
}

impl StateSink {
    pub fn new(topic: &'static str, tx: mpsc::Sender<(String, Value)>) -> Self {
        Self { topic, tx }
    }

    pub fn topic(&self) -> &'static str {
        self.topic
    }

    /// Kozzeteszi az uj allapotot. Ha a hub mar leallt, csendben elnyelodik --
    /// egy leallas alatti push nem hiba.
    ///
    /// A csatorna kotott. A publikalo hurok csak egy map-beirast es egy
    /// broadcastot vegez, tehat a sor gyakorlatilag sosem all -- ha megis
    /// megtelik, egy elszabadult modul all mogotte, es akkor jobb egy koztes
    /// allapotot eldobni (a kovetkezo push amugy is felulirna), mint korlatlanul
    /// noni. Hangosan naplozzuk, mert ez sosem normalis.
    pub fn push(&self, data: Value) {
        if let Err(mpsc::error::TrySendError::Full(_)) =
            self.tx.try_send((self.topic.to_string(), data))
        {
            tracing::error!(topic = self.topic, "az allapot-sor megtelt, a push eldobva");
        }
    }
}

#[async_trait]
pub trait Module: Send + Sync + 'static {
    /// A topic neve, pl. "network". Egyben a `call` domain neve is.
    fn name(&self) -> &'static str;

    /// Onleiras a `describe` muvelethez.
    fn describe(&self) -> ModuleDescription;

    /// Hosszu eletu streamelo hurok. **Csak akkor indul el, ha van feliratkozo**,
    /// es leall, amikor az utolso is elment (lazy topic) -- ez tartja nullan a
    /// CPU-hasznalatot idle-ben.
    ///
    /// Az elso dolga legyen egy snapshot kitolasa, hogy a kliensnek ne legyen
    /// hidegindulasi lyuka.
    async fn run(self: Arc<Self>, _sink: StateSink) -> anyhow::Result<()> {
        Ok(())
    }

    /// Parancsok. A `sink` azert van itt is, hogy egy parancs (pl. `theme.apply`)
    /// azonnal kozzetehesse az uj allapotot.
    async fn call(
        self: Arc<Self>,
        method: &str,
        _params: Value,
        _sink: &StateSink,
    ) -> anyhow::Result<Value> {
        Err(ModuleError::UnknownMethod(method.to_string()).into())
    }
}

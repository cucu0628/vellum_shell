//! Newline-delimited JSON protokoll.
//!
//! Kliens -> daemon:
//! ```json
//! {"v":1,"id":1,"op":"subscribe","topics":["theme","network"]}
//! {"v":1,"id":2,"op":"call","domain":"theme","method":"apply","params":{...}}
//! {"v":1,"id":3,"op":"unsubscribe","topics":["network"]}
//! {"v":1,"id":4,"op":"describe"}
//! ```
//!
//! Daemon -> kliens:
//! ```json
//! {"id":1,"ok":true}
//! {"topic":"theme","data":{...}}
//! {"id":2,"ok":false,"error":{"code":"not_found","message":"..."}}
//! ```

use serde::{Deserialize, Serialize};
use serde_json::Value;

pub const PROTOCOL_VERSION: u32 = 1;

/// Szandekosan lapos struct es nem `#[serde(tag = "op")]` enum: igy egy
/// ismeretlen `op` eseten is megmarad az `id`, tehat tudunk ra parositott
/// hibat valaszolni ahelyett, hogy az egesz sor parse-olasa bukna.
/// Az ismeretlen mezoket eldobjuk -- ez adja az elore-kompatibilitast.
#[derive(Debug, Deserialize)]
pub struct RawRequest {
    #[serde(default)]
    pub v: Option<u32>,
    #[serde(default)]
    pub id: Option<u64>,
    pub op: String,
    #[serde(default)]
    pub topics: Vec<String>,
    #[serde(default)]
    pub domain: Option<String>,
    #[serde(default)]
    pub method: Option<String>,
    #[serde(default)]
    pub params: Value,
}

#[derive(Debug, Clone, Serialize)]
pub struct ProtoError {
    pub code: String,
    pub message: String,
}

impl ProtoError {
    pub fn new(code: impl Into<String>, message: impl Into<String>) -> Self {
        Self { code: code.into(), message: message.into() }
    }

    /// Egy `anyhow::Error`-bol strukturalt hibat csinal. Ha modulhiba volt,
    /// atveszi a gepileg vizsgalhato kodjat, kulonben "internal".
    pub fn from_anyhow(err: &anyhow::Error) -> Self {
        match err.downcast_ref::<crate::module::ModuleError>() {
            Some(module_err) => Self::new(module_err.code(), module_err.to_string()),
            None => Self::new("internal", format!("{err:#}")),
        }
    }
}

/// Egy keresre adott valasz, `id`-vel parositva.
#[derive(Debug, Serialize)]
pub struct Reply {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub id: Option<u64>,
    pub ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<ProtoError>,
}

impl Reply {
    pub fn ok(id: Option<u64>) -> Self {
        Self { id, ok: true, data: None, error: None }
    }

    pub fn data(id: Option<u64>, data: Value) -> Self {
        Self { id, ok: true, data: Some(data), error: None }
    }

    pub fn error(id: Option<u64>, error: ProtoError) -> Self {
        Self { id, ok: false, data: None, error: Some(error) }
    }
}

/// Egy topic uj allapota. Nincs `id`-je: nem keresre valasz, hanem push.
#[derive(Debug, Clone, Serialize)]
pub struct Event {
    pub topic: String,
    pub data: Value,
}

/// Amit a szerver a kliensnek kuld -- vagy valasz, vagy event.
#[derive(Debug, Serialize)]
#[serde(untagged)]
pub enum Outgoing {
    Reply(Reply),
    Event(Event),
}

impl Outgoing {
    /// Egy sorra szerializal, lezaro newline-nal.
    pub fn to_line(&self) -> String {
        match serde_json::to_string(self) {
            Ok(mut line) => {
                line.push('\n');
                line
            }
            // Egy nem szerializalhato ertek nem donthet ki egy kapcsolatot.
            Err(err) => {
                tracing::error!(%err, "kimeno uzenet szerializalasa sikertelen");
                format!(
                    "{}\n",
                    serde_json::json!({
                        "ok": false,
                        "error": { "code": "internal", "message": "serialization failed" }
                    })
                )
            }
        }
    }
}

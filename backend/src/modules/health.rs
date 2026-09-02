//! Minimalis modul, ami a protokoll huzalozasat teszi ellenorizhetove: van
//! snapshotja (feliratkozaskor azonnal erkezik) es van parancsa is.

use crate::module::{MethodDescription, Module, ModuleDescription, ModuleError, StateSink};
use anyhow::Result;
use async_trait::async_trait;
use serde_json::{Value, json};
use std::sync::Arc;
use std::time::Instant;

pub struct Health {
    started: Instant,
}

impl Default for Health {
    fn default() -> Self {
        Self::new()
    }
}

impl Health {
    pub fn new() -> Self {
        Self { started: Instant::now() }
    }

    fn snapshot(&self) -> Value {
        json!({
            "version": env!("CARGO_PKG_VERSION"),
            // A forditaskor beegetett git revizio: igy ellenorizheto, hogy a
            // futo peldany tenyleg a repo aktualis allapotabol keszult-e.
            "revision": env!("VELLUM_REVISION"),
            "binary": std::env::current_exe().ok().map(|path| path.display().to_string()),
            "pid": std::process::id(),
            "uptimeSeconds": self.started.elapsed().as_secs(),
            // Modulonkenti allapot: "running", "idle" vagy "restarting" a
            // legutobbi hibaval. Enelkul egy befagyott topic ugyanugy nez ki,
            // mint egy csendes.
            "modules": crate::ipc::hub::module_health(),
        })
    }
}

#[async_trait]
impl Module for Health {
    fn name(&self) -> &'static str {
        "health"
    }

    fn describe(&self) -> ModuleDescription {
        ModuleDescription {
            topic: "health",
            summary: "A daemon allapota: verzio, pid, uptime.",
            streams: true,
            methods: vec![MethodDescription::new(
                "ping",
                "Elerheto-e a daemon, es mit csinalnak a modulok.",
            )],
        }
    }

    async fn run(self: Arc<Self>, sink: StateSink) -> Result<()> {
        sink.push(self.snapshot());
        // Nincs mit pollozni: a hurok alszik, amig van feliratkozo. A hub
        // megszakitja, amint az utolso is elmegy.
        std::future::pending::<()>().await;
        Ok(())
    }

    async fn call(
        self: Arc<Self>,
        method: &str,
        _params: Value,
        _sink: &StateSink,
    ) -> Result<Value> {
        match method {
            "ping" => Ok(self.snapshot()),
            other => Err(ModuleError::UnknownMethod(other.to_string()).into()),
        }
    }
}

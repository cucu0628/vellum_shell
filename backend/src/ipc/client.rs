//! CLI kliens: ugyanaz a binaris, ami daemonkent fut, kliensként is beszel a
//! sockethez. Ettol marad scriptelheto a backend (Hyprland bindings, setup.sh),
//! es ettol tud egy jovobeli settings app is ugyanerre a feluletre epulni.

use crate::ipc::protocol::PROTOCOL_VERSION;
use anyhow::{Context, Result, bail};
use serde_json::{Value, json};
use std::path::Path;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::UnixStream;

pub struct Client {
    lines: tokio::io::Lines<BufReader<tokio::net::unix::OwnedReadHalf>>,
    write_half: tokio::net::unix::OwnedWriteHalf,
    next_id: u64,
}

impl Client {
    pub async fn connect(path: &Path) -> Result<Self> {
        let stream = UnixStream::connect(path).await.with_context(|| {
            format!(
                "nem sikerult csatlakozni ide: {} (fut a daemon? `vellum daemon`)",
                path.display()
            )
        })?;
        let (read_half, write_half) = stream.into_split();
        Ok(Self { lines: BufReader::new(read_half).lines(), write_half, next_id: 1 })
    }

    async fn send(&mut self, mut request: Value) -> Result<u64> {
        let id = self.next_id;
        self.next_id += 1;
        request["v"] = json!(PROTOCOL_VERSION);
        request["id"] = json!(id);
        let mut line = serde_json::to_string(&request)?;
        line.push('\n');
        self.write_half.write_all(line.as_bytes()).await?;
        Ok(id)
    }

    /// Elkuld egy kerest es megvarja a hozza tartozo valaszt. A kozben erkezo
    /// eventeket atugorja -- azokat a `watch` kezeli.
    async fn request(&mut self, request: Value) -> Result<Value> {
        let id = self.send(request).await?;

        while let Some(line) = self.lines.next_line().await? {
            let value: Value = match serde_json::from_str(&line) {
                Ok(value) => value,
                Err(_) => continue,
            };
            if value.get("id").and_then(Value::as_u64) != Some(id) {
                continue;
            }
            if value.get("ok").and_then(Value::as_bool) == Some(false) {
                let error = &value["error"];
                bail!(
                    "{}: {}",
                    error["code"].as_str().unwrap_or("error"),
                    error["message"].as_str().unwrap_or("ismeretlen hiba")
                );
            }
            return Ok(value.get("data").cloned().unwrap_or(Value::Null));
        }

        bail!("a kapcsolat lezarult valasz nelkul")
    }

    pub async fn describe(&mut self) -> Result<Value> {
        self.request(json!({ "op": "describe" })).await
    }

    pub async fn call(&mut self, domain: &str, method: &str, params: Value) -> Result<Value> {
        self.request(json!({
            "op": "call",
            "domain": domain,
            "method": method,
            "params": params,
        }))
        .await
    }

    /// Feliratkozik es a stdoutra irja az erkezo eventeket, amig a kapcsolat el.
    pub async fn watch(&mut self, topics: &[String]) -> Result<()> {
        self.send(json!({ "op": "subscribe", "topics": topics })).await?;

        while let Some(line) = self.lines.next_line().await? {
            let Ok(value) = serde_json::from_str::<Value>(&line) else {
                continue;
            };
            if value.get("topic").is_some() {
                println!("{line}");
            } else if value.get("ok").and_then(Value::as_bool) == Some(false) {
                let error = &value["error"];
                bail!(
                    "{}: {}",
                    error["code"].as_str().unwrap_or("error"),
                    error["message"].as_str().unwrap_or("ismeretlen hiba")
                );
            }
        }

        Ok(())
    }
}

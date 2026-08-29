//! Unix socket szerver: kapcsolatonkent egy olvaso, egy iro es egy
//! event-tovabbito taszk.

use crate::ipc::hub::Hub;
use crate::ipc::protocol::{Outgoing, PROTOCOL_VERSION, ProtoError, RawRequest, Reply};
use anyhow::{Context, Result};
use serde_json::json;
use std::collections::HashSet;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{UnixListener, UnixStream};
use tokio::sync::{Mutex, mpsc};

/// A socket helye. `XDG_RUNTIME_DIR` mar eleve csak a felhasznalonak olvashato.
pub fn socket_path() -> PathBuf {
    match std::env::var_os("XDG_RUNTIME_DIR") {
        Some(dir) if !dir.is_empty() => PathBuf::from(dir).join("vellum-shell.sock"),
        _ => PathBuf::from(format!("/tmp/vellum-shell-{}.sock", unsafe { libc_getuid() })),
    }
}

// A getuid() az egyetlen dolog, amiert nem eri meg behuzni a libc cratet.
unsafe fn libc_getuid() -> u32 {
    unsafe extern "C" {
        fn getuid() -> u32;
    }
    unsafe { getuid() }
}

/// Elindul a socketen. Ha maradt egy arva socket-fajl egy korabbi futasbol,
/// eltavolitja -- de csak ha tenyleg nem figyel rajta senki.
pub async fn listen(hub: Arc<Hub>, path: &Path) -> Result<()> {
    if path.exists() {
        match UnixStream::connect(path).await {
            Ok(_) => anyhow::bail!(
                "mar fut egy peldany ezen a socketen: {}",
                path.display()
            ),
            Err(_) => {
                tracing::warn!(socket = %path.display(), "arva socket eltavolitasa");
                std::fs::remove_file(path).with_context(|| {
                    format!("arva socket nem torolheto: {}", path.display())
                })?;
            }
        }
    }

    let listener = UnixListener::bind(path)
        .with_context(|| format!("nem sikerult a socketre kotni: {}", path.display()))?;

    // Ovintezkedes arra az esetre, ha a socket nem XDG_RUNTIME_DIR-ben landolna.
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600))?;
    }

    tracing::info!(socket = %path.display(), "figyeles elindult");

    loop {
        match listener.accept().await {
            Ok((stream, _)) => {
                let hub = Arc::clone(&hub);
                tokio::spawn(async move {
                    if let Err(err) = serve_client(hub, stream).await {
                        tracing::debug!(error = format!("{err:#}"), "kliens kapcsolat vege");
                    }
                });
            }
            Err(err) => {
                tracing::error!(%err, "accept sikertelen");
                tokio::time::sleep(std::time::Duration::from_millis(100)).await;
            }
        }
    }
}

async fn serve_client(hub: Arc<Hub>, stream: UnixStream) -> Result<()> {
    let (read_half, mut write_half) = stream.into_split();
    let mut lines = BufReader::new(read_half).lines();

    let (out_tx, mut out_rx) = mpsc::unbounded_channel::<String>();
    let subscriptions: Arc<Mutex<HashSet<String>>> = Arc::new(Mutex::new(HashSet::new()));

    // Iro taszk: egyetlen hely, ahol a socketre irunk.
    let writer = tokio::spawn(async move {
        while let Some(line) = out_rx.recv().await {
            if write_half.write_all(line.as_bytes()).await.is_err() {
                break;
            }
        }
    });

    // Az event-vevot MAR MOST letrehozzuk, meg a feliratkozasok elott. Igy nincs
    // versenyhelyzet: egy modul altal a subscribe kozben pusholt allapot sem
    // veszhet el.
    let mut events = hub.subscribe_events();
    let forwarder = {
        let subscriptions = Arc::clone(&subscriptions);
        let out_tx = out_tx.clone();
        let hub = Arc::clone(&hub);
        tokio::spawn(async move {
            loop {
                match events.recv().await {
                    Ok(event) => {
                        if subscriptions.lock().await.contains(&event.topic)
                            && out_tx.send(Outgoing::Event(event).to_line()).is_err()
                        {
                            break;
                        }
                    }
                    Err(tokio::sync::broadcast::error::RecvError::Lagged(skipped)) => {
                        // A kliens lemaradt. Nem hagyjuk elavult allapottal:
                        // ujrakuldjuk a friss snapshotot minden topicjara.
                        tracing::warn!(skipped, "kliens lemaradt, snapshot ujrakuldese");
                        let topics = subscriptions.lock().await.clone();
                        for topic in topics {
                            if let Some(data) = hub.snapshot(&topic).await {
                                let event = crate::ipc::protocol::Event { topic, data };
                                if out_tx.send(Outgoing::Event(event).to_line()).is_err() {
                                    return;
                                }
                            }
                        }
                    }
                    Err(tokio::sync::broadcast::error::RecvError::Closed) => break,
                }
            }
        })
    };

    while let Some(line) = lines.next_line().await? {
        if line.trim().is_empty() {
            continue;
        }
        handle_line(&hub, &line, &subscriptions, &out_tx).await;
    }

    // Takaritas: a lazy topicok elengedese, kulonben orokre futnanak.
    for topic in subscriptions.lock().await.iter() {
        hub.release(topic).await;
    }
    forwarder.abort();
    drop(out_tx);
    let _ = writer.await;
    Ok(())
}

async fn handle_line(
    hub: &Arc<Hub>,
    line: &str,
    subscriptions: &Arc<Mutex<HashSet<String>>>,
    out_tx: &mpsc::UnboundedSender<String>,
) {
    let request: RawRequest = match serde_json::from_str(line) {
        Ok(request) => request,
        Err(err) => {
            let reply = Reply::error(
                None,
                ProtoError::new("bad_request", format!("ervenytelen JSON: {err}")),
            );
            let _ = out_tx.send(Outgoing::Reply(reply).to_line());
            return;
        }
    };

    let id = request.id;

    if let Some(v) = request.v
        && v != PROTOCOL_VERSION
    {
        let reply = Reply::error(
            id,
            ProtoError::new(
                "unsupported_version",
                format!("a protokoll verzioja {PROTOCOL_VERSION}, a kliense {v}"),
            ),
        );
        let _ = out_tx.send(Outgoing::Reply(reply).to_line());
        return;
    }

    match request.op.as_str() {
        "subscribe" => {
            let mut failed = Vec::new();
            for topic in &request.topics {
                if let Err(err) = hub.acquire(topic).await {
                    failed.push(format!("{err:#}"));
                    continue;
                }
                subscriptions.lock().await.insert(topic.clone());
                // Azonnali snapshot, ha van mar. Ha meg nincs, a modul run()-ja
                // fogja kitolni, es az eventen keresztul erkezik meg.
                if let Some(data) = hub.snapshot(topic).await {
                    let event = crate::ipc::protocol::Event { topic: topic.clone(), data };
                    let _ = out_tx.send(Outgoing::Event(event).to_line());
                }
            }

            let reply = if failed.is_empty() {
                Reply::ok(id)
            } else {
                Reply::error(id, ProtoError::new("not_found", failed.join("; ")))
            };
            let _ = out_tx.send(Outgoing::Reply(reply).to_line());
        }

        "unsubscribe" => {
            for topic in &request.topics {
                if subscriptions.lock().await.remove(topic) {
                    hub.release(topic).await;
                }
            }
            let _ = out_tx.send(Outgoing::Reply(Reply::ok(id)).to_line());
        }

        "call" => {
            let (Some(domain), Some(method)) = (request.domain, request.method) else {
                let reply = Reply::error(
                    id,
                    ProtoError::new("bad_request", "a call-hoz kell 'domain' es 'method'"),
                );
                let _ = out_tx.send(Outgoing::Reply(reply).to_line());
                return;
            };

            // Kulon taszkban, hogy egy lassu parancs ne blokkolja a tobbi kerest.
            let hub = Arc::clone(hub);
            let out_tx = out_tx.clone();
            let params = request.params;
            tokio::spawn(async move {
                let reply = match hub.call(&domain, &method, params).await {
                    Ok(data) => Reply::data(id, data),
                    Err(err) => Reply::error(id, ProtoError::from_anyhow(&err)),
                };
                let _ = out_tx.send(Outgoing::Reply(reply).to_line());
            });
        }

        "describe" => {
            let data = json!({
                "version": PROTOCOL_VERSION,
                "modules": hub.describe(),
            });
            let _ = out_tx.send(Outgoing::Reply(Reply::data(id, data)).to_line());
        }

        other => {
            let reply = Reply::error(
                id,
                ProtoError::new("unknown_op", format!("ismeretlen muvelet: {other}")),
            );
            let _ = out_tx.send(Outgoing::Reply(reply).to_line());
        }
    }
}

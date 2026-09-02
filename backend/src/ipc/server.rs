//! Unix socket szerver: kapcsolatonkent egy olvaso, egy iro es egy
//! event-tovabbito taszk.

use crate::ipc::hub::Hub;
use crate::ipc::protocol::{Outgoing, PROTOCOL_VERSION, ProtoError, RawRequest, Reply};
use anyhow::{Context, Result};
use serde_json::json;
use std::collections::HashSet;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::unix::OwnedReadHalf;
use tokio::net::{UnixListener, UnixStream};
use tokio::sync::{Mutex, Semaphore, mpsc};

/// Egyszerre kiszolgalt kapcsolatok felso hatara. A socket csak a
/// felhasznaloe, tehat ez nem tamadasi felulet, hanem egy elszabadult kliens
/// elleni biztositek.
const MAX_CONNECTIONS: usize = 64;

/// Kapcsolatonkent egyszerre futo `call` taszkok. Ennel tobb egyideju parancs
/// mar nem parhuzamossag, hanem egy ciklusba ragadt hivo.
const MAX_INFLIGHT_CALLS: usize = 16;

/// Kapcsolatonkenti kimeneti sor. Ha egy lassu olvaso ennyivel lemarad,
/// bontunk: ujracsatlakozni olcsobb, mint korlatlanul gyujteni neki a
/// kimenetet.
const CLIENT_QUEUE: usize = 512;

/// Egy keres maximalis hossza. A protokoll sorai kicsik; ennel nagyobb csak
/// hiba lehet, es addig sem gyujtunk memoriat, amig ki nem derul.
const MAX_LINE_BYTES: usize = 1 << 20;

/// A socket helye. `XDG_RUNTIME_DIR` mar eleve csak a felhasznalonak olvashato.
///
/// A `VELLUM_SOCKET` mindent felulir. Ez a kozos kapcsolo a QML kliens fele is:
/// XDG_RUNTIME_DIR nelkul az itteni uid-suffixes /tmp utvonalat a shell nem
/// tudna kiszamolni, ezert ilyen munkamenetben a `shell-start` mindkettonek
/// beallitja.
pub fn socket_path() -> PathBuf {
    if let Some(explicit) = std::env::var_os("VELLUM_SOCKET")
        && !explicit.is_empty()
    {
        return PathBuf::from(explicit);
    }
    match std::env::var_os("XDG_RUNTIME_DIR") {
        Some(dir) if !dir.is_empty() => PathBuf::from(dir).join("vellum-shell.sock"),
        // SAFETY: a getuid() nem nyul megosztott allapothoz es sosem bukik.
        _ => PathBuf::from(format!("/tmp/vellum-shell-{}.sock", unsafe { libc::getuid() })),
    }
}

/// Elindul a socketen. Ha maradt egy arva socket-fajl egy korabbi futasbol,
/// eltavolitja -- de csak ha tenyleg nem figyel rajta senki.
pub async fn listen(hub: Arc<Hub>, path: &Path) -> Result<()> {
    if path.exists() {
        match UnixStream::connect(path).await {
            Ok(_) => anyhow::bail!("mar fut egy peldany ezen a socketen: {}", path.display()),
            Err(_) => {
                tracing::warn!(socket = %path.display(), "arva socket eltavolitasa");
                std::fs::remove_file(path)
                    .with_context(|| format!("arva socket nem torolheto: {}", path.display()))?;
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

    let slots = Arc::new(Semaphore::new(MAX_CONNECTIONS));

    loop {
        match listener.accept().await {
            Ok((stream, _)) => {
                // A permitet meg a taszk elott vesszuk fel: tele hazzal a
                // kapcsolat azonnal zarul, nem gyulnek fel a felig kiszolgalt
                // kliensek.
                let Ok(slot) = Arc::clone(&slots).try_acquire_owned() else {
                    tracing::warn!(limit = MAX_CONNECTIONS, "kapcsolat elutasitva: betelt");
                    drop(stream);
                    continue;
                };
                let hub = Arc::clone(&hub);
                tokio::spawn(async move {
                    if let Err(err) = serve_client(hub, stream).await {
                        tracing::debug!(error = format!("{err:#}"), "kliens kapcsolat vege");
                    }
                    drop(slot);
                });
            }
            Err(err) => {
                tracing::error!(%err, "accept sikertelen");
                tokio::time::sleep(std::time::Duration::from_millis(100)).await;
            }
        }
    }
}

/// Egy kliens kapcsolatanak kimenete.
///
/// A queue kotott: ha megtelik, a kliens lemaradt, es inkabb bontunk. A
/// `closed` flag az, ami errol a tobbi taszkot is ertesiti -- a csatorna
/// sender oldalarol nem lehet lezarni.
#[derive(Clone)]
struct ClientOut {
    tx: mpsc::Sender<String>,
    closed: Arc<AtomicBool>,
}

impl ClientOut {
    fn send(&self, line: String) -> bool {
        if self.closed.load(Ordering::Relaxed) {
            return false;
        }
        match self.tx.try_send(line) {
            Ok(()) => true,
            Err(mpsc::error::TrySendError::Full(_)) => {
                tracing::warn!(limit = CLIENT_QUEUE, "a kliens kimeneti sora megtelt, bontunk");
                self.closed.store(true, Ordering::Relaxed);
                false
            }
            Err(mpsc::error::TrySendError::Closed(_)) => {
                self.closed.store(true, Ordering::Relaxed);
                false
            }
        }
    }

    fn is_closed(&self) -> bool {
        self.closed.load(Ordering::Relaxed)
    }
}

/// Egy sor beolvasasa felso hatarral.
///
/// A `read_until` addig gyujtene, amig a masik oldal ujsort nem kuld: egy
/// vegtelen sor igy elfogyasztana a daemon memoriajat. Chunkonkent olvasunk,
/// es a limit atlepesekor hibaval bontunk.
async fn read_line_bounded(
    reader: &mut BufReader<OwnedReadHalf>,
    buf: &mut Vec<u8>,
    limit: usize,
) -> Result<bool> {
    buf.clear();
    loop {
        let taken = {
            let available = reader.fill_buf().await?;
            if available.is_empty() {
                // EOF. Egy ujsor nelkul zarult utolso sort meg feldolgozunk.
                return Ok(!buf.is_empty());
            }
            match available.iter().position(|byte| *byte == b'\n') {
                Some(index) => {
                    if buf.len() + index > limit {
                        anyhow::bail!("a kliens sora hosszabb, mint {limit} bajt");
                    }
                    buf.extend_from_slice(&available[..index]);
                    let taken = index + 1;
                    reader.consume(taken);
                    return Ok(true);
                }
                None => {
                    if buf.len() + available.len() > limit {
                        anyhow::bail!("a kliens sora hosszabb, mint {limit} bajt");
                    }
                    buf.extend_from_slice(available);
                    available.len()
                }
            }
        };
        reader.consume(taken);
    }
}

async fn serve_client(hub: Arc<Hub>, stream: UnixStream) -> Result<()> {
    let (read_half, mut write_half) = stream.into_split();
    let mut reader = BufReader::new(read_half);

    let (queue_tx, mut out_rx) = mpsc::channel::<String>(CLIENT_QUEUE);
    let out_tx = ClientOut { tx: queue_tx, closed: Arc::new(AtomicBool::new(false)) };
    let subscriptions: Arc<Mutex<HashSet<String>>> = Arc::new(Mutex::new(HashSet::new()));
    let calls = Arc::new(Semaphore::new(MAX_INFLIGHT_CALLS));

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
                            && !out_tx.send(Outgoing::Event(event).to_line())
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
                                if !out_tx.send(Outgoing::Event(event).to_line()) {
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

    // A ciklus eredmenyet elkapjuk: egy olvasasi hiba nem ugorhatja at a
    // takaritast, kulonben a lazy topicok feliratkozoja orokre bennragad, es a
    // modul hurka a kliens nelkul is tovabb futna.
    let outcome: Result<()> = async {
        let mut buf = Vec::new();
        while read_line_bounded(&mut reader, &mut buf, MAX_LINE_BYTES).await? {
            if out_tx.is_closed() {
                break;
            }
            let line = String::from_utf8_lossy(&buf).into_owned();
            if line.trim().is_empty() {
                continue;
            }
            handle_line(&hub, &line, &subscriptions, &out_tx, &calls).await;
        }
        Ok(())
    }
    .await;

    // Takaritas: a lazy topicok elengedese, kulonben orokre futnanak.
    for topic in subscriptions.lock().await.iter() {
        hub.release(topic).await;
    }
    forwarder.abort();
    drop(out_tx);
    let _ = writer.await;
    outcome
}

async fn handle_line(
    hub: &Arc<Hub>,
    line: &str,
    subscriptions: &Arc<Mutex<HashSet<String>>>,
    out_tx: &ClientOut,
    calls: &Arc<Semaphore>,
) {
    let request: RawRequest = match serde_json::from_str(line) {
        Ok(request) => request,
        Err(err) => {
            let reply = Reply::error(
                None,
                ProtoError::new("bad_request", format!("ervenytelen JSON: {err}")),
            );
            out_tx.send(Outgoing::Reply(reply).to_line());
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
        out_tx.send(Outgoing::Reply(reply).to_line());
        return;
    }

    match request.op.as_str() {
        "subscribe" => {
            let mut failed = Vec::new();
            for topic in &request.topics {
                // Egy kapcsolaton belul topiconkent csak egyszer szamolunk
                // feliratkozot. A takaritas topiconkent egyetlen release-t kuld
                // (a `subscriptions` halmaz), tehat egy masodik acquire orokre
                // fenntartana a lazy hurkot -- akkor is, ha a kliens mar elment.
                if !subscriptions.lock().await.contains(topic) {
                    if let Err(err) = hub.acquire(topic).await {
                        failed.push(format!("{err:#}"));
                        continue;
                    }
                    subscriptions.lock().await.insert(topic.clone());
                }
                // Azonnali snapshot, ha van mar. Ha meg nincs, a modul run()-ja
                // fogja kitolni, es az eventen keresztul erkezik meg.
                if let Some(data) = hub.snapshot(topic).await {
                    let event = crate::ipc::protocol::Event { topic: topic.clone(), data };
                    out_tx.send(Outgoing::Event(event).to_line());
                }
            }

            let reply = if failed.is_empty() {
                Reply::ok(id)
            } else {
                Reply::error(id, ProtoError::new("not_found", failed.join("; ")))
            };
            out_tx.send(Outgoing::Reply(reply).to_line());
        }

        "unsubscribe" => {
            for topic in &request.topics {
                if subscriptions.lock().await.remove(topic) {
                    hub.release(topic).await;
                }
            }
            out_tx.send(Outgoing::Reply(Reply::ok(id)).to_line());
        }

        "call" => {
            let (Some(domain), Some(method)) = (request.domain, request.method) else {
                let reply = Reply::error(
                    id,
                    ProtoError::new("bad_request", "a call-hoz kell 'domain' es 'method'"),
                );
                out_tx.send(Outgoing::Reply(reply).to_line());
                return;
            };

            // Kulon taszkban, hogy egy lassu parancs ne blokkolja a tobbi
            // kerest -- de kotott szammal, kulonben egy ciklusba ragadt kliens
            // korlatlanul szaporitana oket.
            let Ok(slot) = Arc::clone(calls).try_acquire_owned() else {
                let reply = Reply::error(
                    id,
                    ProtoError::new(
                        "busy",
                        format!("egyszerre legfeljebb {MAX_INFLIGHT_CALLS} parancs futhat"),
                    ),
                );
                out_tx.send(Outgoing::Reply(reply).to_line());
                return;
            };

            let hub = Arc::clone(hub);
            let out_tx = out_tx.clone();
            let params = request.params;
            tokio::spawn(async move {
                let reply = match hub.call(&domain, &method, params).await {
                    Ok(data) => Reply::data(id, data),
                    Err(err) => Reply::error(id, ProtoError::from_anyhow(&err)),
                };
                out_tx.send(Outgoing::Reply(reply).to_line());
                drop(slot);
            });
        }

        "describe" => {
            let data = json!({
                "version": PROTOCOL_VERSION,
                "modules": hub.describe(),
            });
            out_tx.send(Outgoing::Reply(Reply::data(id, data)).to_line());
        }

        other => {
            let reply = Reply::error(
                id,
                ProtoError::new("unknown_op", format!("ismeretlen muvelet: {other}")),
            );
            out_tx.send(Outgoing::Reply(reply).to_line());
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::module::{Module, ModuleDescription, StateSink};

    /// Streamelo modul, ami sosem all le maga -- igy a feliratkozo-szamlalas a
    /// megfigyelheto viselkedes.
    struct Dummy;

    #[async_trait::async_trait]
    impl Module for Dummy {
        fn name(&self) -> &'static str {
            "dummy"
        }

        fn describe(&self) -> ModuleDescription {
            ModuleDescription {
                topic: "dummy",
                summary: "teszt modul",
                streams: true,
                methods: Vec::new(),
            }
        }

        async fn run(self: Arc<Self>, sink: StateSink) -> Result<()> {
            sink.push(json!({ "ok": true }));
            std::future::pending::<()>().await;
            Ok(())
        }
    }

    async fn serve_lines(hub: &Arc<Hub>, lines: &str) {
        let (client, server) = UnixStream::pair().unwrap();
        let served = {
            let hub = Arc::clone(hub);
            tokio::spawn(async move { serve_client(hub, server).await })
        };

        let (read_half, mut write_half) = client.into_split();
        write_half.write_all(lines.as_bytes()).await.unwrap();
        // A bontas EOF-ot ad: az olvaso hurok a mar bufferelt sorokat meg
        // feldolgozza, majd lefuttatja a takaritast.
        drop(write_half);
        drop(read_half);
        served.await.unwrap().unwrap();
    }

    /// Ugyanarra a topicra ketszer feliratkozva a kapcsolat bontasa utan sem
    /// maradhat elo feliratkozo. A takaritas topiconkent egyetlen release-t
    /// kuld, ezert egy masodik acquire orokre futni hagyna a lazy hurkot.
    #[tokio::test]
    async fn duplicate_subscribe_is_counted_once() {
        let hub = Hub::new(vec![Arc::new(Dummy) as Arc<dyn Module>]);

        serve_lines(
            &hub,
            "{\"v\":1,\"op\":\"subscribe\",\"topics\":[\"dummy\"]}\n\
             {\"v\":1,\"op\":\"subscribe\",\"topics\":[\"dummy\"]}\n",
        )
        .await;

        assert_eq!(
            hub.subscriber_count("dummy").await,
            0,
            "a dupla feliratkozas utan feliratkozo maradt a topicon"
        );
    }

    /// Ket kulon kapcsolat viszont ket kulon feliratkozo: az elso bontasa nem
    /// veheti el a masodiktol a streamet.
    #[tokio::test]
    async fn separate_connections_are_counted_separately() {
        let hub = Hub::new(vec![Arc::new(Dummy) as Arc<dyn Module>]);
        let line = "{\"v\":1,\"op\":\"subscribe\",\"topics\":[\"dummy\"]}\n";

        serve_lines(&hub, line).await;
        assert_eq!(hub.subscriber_count("dummy").await, 0);

        serve_lines(&hub, line).await;
        assert_eq!(hub.subscriber_count("dummy").await, 0);
    }

    /// Egy tulmeretes sor bontja a kapcsolatot -- de a takaritasnak akkor is
    /// le kell futnia, kulonben a lazy topic feliratkozoja bennragad, es a
    /// modul hurka a kliens nelkul is tovabb futna.
    #[tokio::test]
    async fn an_oversized_line_disconnects_but_still_releases_subscriptions() {
        let hub = Hub::new(vec![Arc::new(Dummy) as Arc<dyn Module>]);
        let (client, server) = UnixStream::pair().unwrap();

        let served = {
            let hub = Arc::clone(&hub);
            tokio::spawn(async move { serve_client(hub, server).await })
        };

        let (read_half, mut write_half) = client.into_split();
        tokio::spawn(async move {
            let _ = write_half
                .write_all(b"{\"v\":1,\"op\":\"subscribe\",\"topics\":[\"dummy\"]}\n")
                .await;
            // Ujsor nelkuli, a limitnel hosszabb szemet.
            let flood = vec![b'x'; MAX_LINE_BYTES + 4096];
            let _ = write_half.write_all(&flood).await;
        });

        let outcome = served.await.unwrap();
        drop(read_half);

        assert!(outcome.is_err(), "a tulmeretes sor nem bontotta a kapcsolatot");
        assert_eq!(
            hub.subscriber_count("dummy").await,
            0,
            "olvasasi hiba utan feliratkozo maradt a topicon"
        );
    }

    /// Egy kapcsolaton belul kotott szamu parancs futhat egyszerre; a tobbi
    /// nem taszkot kap, hanem `busy` valaszt.
    #[tokio::test]
    async fn too_many_concurrent_calls_are_refused_not_queued() {
        let hub = Hub::new(vec![Arc::new(Dummy) as Arc<dyn Module>]);
        let subscriptions: Arc<Mutex<HashSet<String>>> = Arc::new(Mutex::new(HashSet::new()));
        let (queue_tx, mut out_rx) = mpsc::channel::<String>(CLIENT_QUEUE);
        let out_tx = ClientOut { tx: queue_tx, closed: Arc::new(AtomicBool::new(false)) };

        // Minden permit elfogy, mielott a hivas beerkezne.
        let calls = Arc::new(Semaphore::new(MAX_INFLIGHT_CALLS));
        let mut held = Vec::new();
        for _ in 0..MAX_INFLIGHT_CALLS {
            held.push(Arc::clone(&calls).try_acquire_owned().unwrap());
        }

        handle_line(
            &hub,
            "{\"v\":1,\"op\":\"call\",\"id\":7,\"domain\":\"dummy\",\"method\":\"ping\"}",
            &subscriptions,
            &out_tx,
            &calls,
        )
        .await;

        let line = out_rx.recv().await.expect("nem erkezett valasz");
        assert!(line.contains("\"busy\""), "{line}");
    }

    /// Az explicit leiratkozas ugyanugy egyetlen release, es a bontas utana
    /// nem vonhat le megegyszer.
    #[tokio::test]
    async fn unsubscribe_then_disconnect_does_not_underflow() {
        let hub = Hub::new(vec![Arc::new(Dummy) as Arc<dyn Module>]);

        serve_lines(
            &hub,
            "{\"v\":1,\"op\":\"subscribe\",\"topics\":[\"dummy\"]}\n\
             {\"v\":1,\"op\":\"unsubscribe\",\"topics\":[\"dummy\"]}\n",
        )
        .await;

        assert_eq!(hub.subscriber_count("dummy").await, 0);
    }
}

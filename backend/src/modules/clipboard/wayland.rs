//! A Wayland vagolap figyelese a `wlr-data-control` protokollal.
//!
//! Ez ugyanaz a protokoll, amire a `wl-paste --watch` es a cliphist is epul,
//! csak itt a daemon maga beszeli: nincs kulso folyamat, nincs shell-pipe.
//!
//! Egy kulon szalon fut, mert a Wayland esemenyhurok blokkolo. Ket iranyban
//! kommunikal a modullal:
//!   * kifele [`WatchEvent`]: uj tartalom a vagolapon, vagy kiurult;
//!   * befele [`Command`]: legyen ez a vagolap tartalma (visszamasolas).
//!
//! A tartalom kiolvasasa es kiszolgalasa egy-egy rovid eletu szalon tortenik.
//! Igy akkor sem akad meg semmi, ha a forras mi magunk vagyunk: a compositor a
//! sajat forrasunktol kert adatot ugyanezen a hurkon keresztul keri el.

use anyhow::{Context, Result, anyhow};
use std::collections::HashMap;
use std::io::{Read, Write};
use std::os::fd::{AsFd, AsRawFd, FromRawFd, OwnedFd};
use std::sync::Arc;
use std::sync::mpsc as std_mpsc;
use tokio::sync::mpsc;
use wayland_client::backend::ObjectId;
use wayland_client::globals::{GlobalListContents, registry_queue_init};
use wayland_client::protocol::{wl_registry, wl_seat::WlSeat};
use wayland_client::{Connection, Dispatch, Proxy, QueueHandle, event_created_child};
use wayland_protocols_wlr::data_control::v1::client::{
    zwlr_data_control_device_v1::{self, ZwlrDataControlDeviceV1},
    zwlr_data_control_manager_v1::ZwlrDataControlManagerV1,
    zwlr_data_control_offer_v1::{self, ZwlrDataControlOfferV1},
    zwlr_data_control_source_v1::{self, ZwlrDataControlSourceV1},
};

use super::store::MAX_ENTRY_BYTES;

/// A szoveg tipusai, preferencia-sorrendben. Visszamasolaskor mindet
/// felkinaljuk, mert a regi X11-es alkalmazasok csak a `UTF8_STRING`-et ertik.
pub const TEXT_MIMES: &[&str] =
    &["text/plain;charset=utf-8", "text/plain", "UTF8_STRING", "STRING", "TEXT"];
/// A tarolhato kepformatumok (a backend ezeket tudja elonezetre dekodolni).
const IMAGE_MIMES: &[&str] = &["image/png", "image/jpeg", "image/webp", "image/gif"];
/// A jelszokezelok ezzel jelzik, hogy a tartalom titkos: ilyet nem tarolunk.
const SECRET_HINT: &str = "x-kde-passwordManagerHint";

#[derive(Debug)]
pub enum WatchEvent {
    Captured {
        mime: String,
        data: Vec<u8>,
    },
    /// A forras alkalmazas kilepett, a vagolap kiurult.
    Cleared,
}

pub enum Command {
    SetSelection { mimes: Vec<String>, data: Arc<Vec<u8>> },
}

/// A futo figyelo vezerloje: ezen at kerheto a visszamasolas.
#[derive(Clone)]
pub struct Control {
    tx: std_mpsc::Sender<Command>,
    wake: Arc<OwnedFd>,
}

impl Control {
    pub fn send(&self, command: Command) -> Result<()> {
        self.tx.send(command).map_err(|_| anyhow!("a vagolap-figyelo leallt"))?;
        // Egy bajt a pipe-ba: felebreszti a pollt a Wayland-szalon.
        let byte = [1u8];
        // SAFETY: ervenyes, nyitott fd, egy bajtos buffer.
        unsafe { libc::write(self.wake.as_raw_fd(), byte.as_ptr().cast(), 1) };
        Ok(())
    }
}

/// Elinditja a figyelo szalat. Ha nincs Wayland-kapcsolat vagy a compositor
/// nem tamogatja a protokollt, azonnal hibat ad.
pub fn spawn(
    events: mpsc::UnboundedSender<WatchEvent>,
) -> Result<(Control, std::thread::JoinHandle<Result<()>>)> {
    let conn = Connection::connect_to_env().context("nincs Wayland-kapcsolat")?;
    let (globals, mut queue) =
        registry_queue_init::<State>(&conn).context("a Wayland registry nem olvashato")?;
    let qh = queue.handle();

    let manager: ZwlrDataControlManagerV1 = globals
        .bind(&qh, 1..=2, ())
        .context("a compositor nem tamogatja a wlr-data-control protokollt")?;
    let seat: WlSeat = globals.bind(&qh, 1..=8, ()).context("nincs Wayland seat")?;
    let device = manager.get_data_device(&seat, &qh, ());

    let (wake_read, wake_write) = pipe()?;
    let (tx, rx) = std_mpsc::channel();

    let mut state = State {
        events,
        offers: HashMap::new(),
        source: None,
        had_selection: false,
        finished: false,
    };
    // Az elso korben a compositor elkuldi a mostani vagolapot is.
    queue.roundtrip(&mut state).context("Wayland roundtrip")?;

    let control = Control { tx, wake: Arc::new(wake_write) };
    let handle = std::thread::Builder::new().name("vellum-clipboard".into()).spawn(move || {
        let result =
            event_loop(&conn, &mut queue, &mut state, &manager, &device, &qh, &wake_read, &rx);
        if let Err(err) = &result {
            tracing::warn!(%err, "a vagolap-figyelo leallt");
        }
        result
    })?;

    Ok((control, handle))
}

#[allow(clippy::too_many_arguments)]
fn event_loop(
    conn: &Connection,
    queue: &mut wayland_client::EventQueue<State>,
    state: &mut State,
    manager: &ZwlrDataControlManagerV1,
    device: &ZwlrDataControlDeviceV1,
    qh: &QueueHandle<State>,
    wake: &OwnedFd,
    commands: &std_mpsc::Receiver<Command>,
) -> Result<()> {
    loop {
        queue.dispatch_pending(state)?;
        conn.flush()?;
        if state.finished {
            return Err(anyhow!("a compositor lezarta a vagolap-eszkozt"));
        }

        let Some(guard) = queue.prepare_read() else {
            continue;
        };

        let mut fds = [
            libc::pollfd {
                fd: guard.connection_fd().as_raw_fd(),
                events: libc::POLLIN,
                revents: 0,
            },
            libc::pollfd { fd: wake.as_raw_fd(), events: libc::POLLIN, revents: 0 },
        ];
        // SAFETY: ket ervenyes pollfd, vegtelen varakozas.
        let ready = unsafe { libc::poll(fds.as_mut_ptr(), fds.len() as libc::nfds_t, -1) };
        if ready < 0 {
            let err = std::io::Error::last_os_error();
            if err.kind() == std::io::ErrorKind::Interrupted {
                continue;
            }
            return Err(err.into());
        }

        if fds[0].revents & (libc::POLLHUP | libc::POLLERR) != 0 {
            return Err(anyhow!("a Wayland-kapcsolat megszakadt"));
        }
        if fds[0].revents & libc::POLLIN != 0 {
            // A WouldBlock nem hiba: ilyenkor egyszeruen nincs mit olvasni.
            if let Err(err) = guard.read()
                && !matches!(&err, wayland_client::backend::WaylandError::Io(io) if io.kind() == std::io::ErrorKind::WouldBlock)
            {
                return Err(err.into());
            }
        } else {
            drop(guard);
        }

        if fds[1].revents & libc::POLLIN != 0 {
            drain(wake);
            while let Ok(command) = commands.try_recv() {
                match command {
                    Command::SetSelection { mimes, data } => {
                        let source = manager.create_data_source(qh, ());
                        for mime in &mimes {
                            source.offer(mime.clone());
                        }
                        device.set_selection(Some(&source));
                        // Az elozo forrasunkat a compositor `cancelled`-del zarja.
                        state.source = Some((source.id(), data));
                    }
                }
            }
        }
    }
}

struct State {
    events: mpsc::UnboundedSender<WatchEvent>,
    /// Az eppen ismert ajanlatok es a felkinalt tipusaik.
    offers: HashMap<ObjectId, Vec<String>>,
    /// A sajat, eppen aktiv forrasunk es a kiszolgalando tartalom.
    source: Option<(ObjectId, Arc<Vec<u8>>)>,
    /// Lattunk-e mar tartalmat ebben a munkamenetben (kiurulas felismeresehez).
    had_selection: bool,
    /// A compositor visszavonta az eszkozt (pl. a seat megszunt).
    finished: bool,
}

impl State {
    fn on_selection(&mut self, offer: Option<ZwlrDataControlOfferV1>) {
        let Some(offer) = offer else {
            if self.had_selection {
                let _ = self.events.send(WatchEvent::Cleared);
            }
            return;
        };
        self.had_selection = true;

        let mimes = self.offers.remove(&offer.id()).unwrap_or_default();
        let Some(mime) = choose_mime(&mimes) else {
            offer.destroy();
            return;
        };

        let Ok((read_end, write_end)) = pipe() else {
            offer.destroy();
            return;
        };
        offer.receive(mime.clone(), write_end.as_fd());
        // A sajat peldanyunkat bezarjuk: igy a forras lezarasa EOF-ot ad.
        drop(write_end);
        offer.destroy();

        let events = self.events.clone();
        let _ = std::thread::Builder::new().name("vellum-clipboard-read".into()).spawn(move || {
            if let Some(data) = read_all(read_end) {
                let _ = events.send(WatchEvent::Captured { mime, data });
            }
        });
    }
}

/// Melyik tipusban kerjuk el a tartalmat. Titkos tartalomnal semmilyenben.
fn choose_mime(mimes: &[String]) -> Option<String> {
    if mimes.iter().any(|mime| mime == SECRET_HINT) {
        return None;
    }
    let has = |wanted: &str| mimes.iter().any(|mime| mime == wanted);
    // Szoveg az elsodleges: egy bongeszobol masolt szoveg mellett gyakran ott
    // egy kep-ikon is, de a felhasznalo a szoveget masolta.
    TEXT_MIMES.iter().chain(IMAGE_MIMES.iter()).find(|mime| has(mime)).map(|mime| mime.to_string())
}

fn read_all(fd: OwnedFd) -> Option<Vec<u8>> {
    let mut file = std::fs::File::from(fd);
    let mut data = Vec::new();
    // Eggyel tobbet olvasunk a korlatnal: igy tudjuk, hogy tullepte-e.
    let mut limited = (&mut file).take(MAX_ENTRY_BYTES as u64 + 1);
    limited.read_to_end(&mut data).ok()?;
    if data.len() > MAX_ENTRY_BYTES {
        return None;
    }
    Some(data)
}

fn pipe() -> Result<(OwnedFd, OwnedFd)> {
    let mut fds = [0; 2];
    // SAFETY: ket elemu tomb; siker eseten mindket fd a mienk.
    if unsafe { libc::pipe2(fds.as_mut_ptr(), libc::O_CLOEXEC) } != 0 {
        return Err(std::io::Error::last_os_error().into());
    }
    // SAFETY: a pipe2 most adta oket, mas nem birtokolja.
    Ok(unsafe { (OwnedFd::from_raw_fd(fds[0]), OwnedFd::from_raw_fd(fds[1])) })
}

fn drain(fd: &OwnedFd) {
    let mut buffer = [0u8; 64];
    // A wake-pipe nem blokkolo olvasas nelkul is biztonsagos: a poll szerint
    // van benne adat; egyszeri olvasas eleg, a tobbit a kovetkezo kor viszi.
    // SAFETY: ervenyes fd es buffer.
    unsafe { libc::read(fd.as_raw_fd(), buffer.as_mut_ptr().cast(), buffer.len()) };
}

// -- Wayland diszpecserek ---------------------------------------------------

impl Dispatch<wl_registry::WlRegistry, GlobalListContents> for State {
    fn event(
        _: &mut Self,
        _: &wl_registry::WlRegistry,
        _: wl_registry::Event,
        _: &GlobalListContents,
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<WlSeat, ()> for State {
    fn event(
        _: &mut Self,
        _: &WlSeat,
        _: <WlSeat as Proxy>::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<ZwlrDataControlManagerV1, ()> for State {
    fn event(
        _: &mut Self,
        _: &ZwlrDataControlManagerV1,
        _: <ZwlrDataControlManagerV1 as Proxy>::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<ZwlrDataControlDeviceV1, ()> for State {
    fn event(
        state: &mut Self,
        _: &ZwlrDataControlDeviceV1,
        event: zwlr_data_control_device_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        match event {
            zwlr_data_control_device_v1::Event::DataOffer { id } => {
                state.offers.insert(id.id(), Vec::new());
            }
            zwlr_data_control_device_v1::Event::Selection { id } => state.on_selection(id),
            zwlr_data_control_device_v1::Event::Finished => state.finished = true,
            // Az elsodleges (kozepso gombos) kijelolest nem taroljuk.
            zwlr_data_control_device_v1::Event::PrimarySelection { id: Some(offer) } => {
                state.offers.remove(&offer.id());
                offer.destroy();
            }
            _ => {}
        }
    }

    event_created_child!(State, ZwlrDataControlDeviceV1, [
        zwlr_data_control_device_v1::EVT_DATA_OFFER_OPCODE => (ZwlrDataControlOfferV1, ()),
    ]);
}

impl Dispatch<ZwlrDataControlOfferV1, ()> for State {
    fn event(
        state: &mut Self,
        offer: &ZwlrDataControlOfferV1,
        event: zwlr_data_control_offer_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        if let zwlr_data_control_offer_v1::Event::Offer { mime_type } = event {
            state.offers.entry(offer.id()).or_default().push(mime_type);
        }
    }
}

impl Dispatch<ZwlrDataControlSourceV1, ()> for State {
    fn event(
        state: &mut Self,
        source: &ZwlrDataControlSourceV1,
        event: zwlr_data_control_source_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        match event {
            zwlr_data_control_source_v1::Event::Send { fd, .. } => {
                let Some((_, data)) = state.source.as_ref().filter(|(id, _)| *id == source.id())
                else {
                    return;
                };
                let data = Arc::clone(data);
                // Kulon szalon irjuk: egy lassan olvaso alkalmazas ne allitsa meg
                // a hurkot.
                let _ = std::thread::Builder::new().name("vellum-clipboard-send".into()).spawn(
                    move || {
                        let mut file = std::fs::File::from(fd);
                        let _ = file.write_all(&data);
                    },
                );
            }
            zwlr_data_control_source_v1::Event::Cancelled => {
                if state.source.as_ref().is_some_and(|(id, _)| *id == source.id()) {
                    state.source = None;
                }
                source.destroy();
            }
            _ => {}
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn mimes(list: &[&str]) -> Vec<String> {
        list.iter().map(|mime| mime.to_string()).collect()
    }

    #[test]
    fn text_wins_over_image() {
        assert_eq!(
            choose_mime(&mimes(&["image/png", "text/html", "text/plain"])).as_deref(),
            Some("text/plain")
        );
    }

    #[test]
    fn image_only_offers_are_images() {
        assert_eq!(choose_mime(&mimes(&["image/png", "text/html"])).as_deref(), Some("image/png"));
    }

    #[test]
    fn secrets_are_never_read() {
        assert_eq!(choose_mime(&mimes(&["text/plain", SECRET_HINT])), None);
    }

    #[test]
    fn unknown_types_are_ignored() {
        assert_eq!(choose_mime(&mimes(&["application/x-custom"])), None);
    }
}

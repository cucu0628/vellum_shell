//! Zarolas alvas elott (logind).
//!
//! A `lock suspend` IPC sajat maga zarol, mielott altat. Ha viszont a fedel
//! lecsukasa, a `systemctl suspend` vagy egy idle-demon altat, a shell nem tud
//! rola, es a gep zaratlanul ebred. Ez a modul egy logind "delay" inhibitort
//! tart: a `PrepareForSleep(true)` jelre kitolja a `sleeping` allapotot, a shell
//! zarol, es amikor a compositor visszaigazolta a lock feluletet, a
//! `sleepReady` hivassal elengedjuk az inhibitort -- csak ekkor alszik el a gep.
//!
//! Ha a shell nem valaszol, a `READY_TIMEOUT` utan magunktol engedunk: a
//! logind amugy is csak `InhibitDelayMaxSec` (alapbol 5 s) ideig var, es egy
//! beragadt kliens nem tarthatja ebren a gepet.
//!
//! A topic lazy: inhibitor csak addig el, amig a shell feliratkozik. Ha a shell
//! elmegy (vagy osszeomlik), a hurok leall, es az inhibitor vele zarodik.
//!
//! Ugyanitt figyeljuk a munkamenet logind `Lock` jelzeset is: a
//! `loginctl lock-session` (es az erre epulo idle-demonok, pl. a hypridle)
//! igy a Vellum zarolokepernyojet kapcsoljak be. A `lockRequests` szamlalo
//! minden ilyen kerelemnel no; a shell a novekedesre zarol. A shell a
//! `setLocked` hivassal visszajelzi a zarolt allapotot (logind `LockedHint`).

use crate::dbus;
use crate::login::{self, LoginManagerProxy, LoginSessionProxy};
use crate::module::{MethodDescription, Module, ModuleDescription, ModuleError, StateSink};
use anyhow::{Result, anyhow};
use async_trait::async_trait;
use futures_util::StreamExt;
use serde_json::{Value, json};
use std::os::fd::OwnedFd;
use std::sync::{Arc, Mutex};
use std::time::Duration;
use zbus::zvariant::OwnedObjectPath;

/// Ennyit varunk a shell `sleepReady` hivasara. A logind alapertelmezett
/// `InhibitDelayMaxSec` erteke (5 s) alatt marad.
const READY_TIMEOUT: Duration = Duration::from_millis(4500);

/// Az alvasi ciklus allapota, D-Bus nelkul, hogy tesztelheto legyen.
#[derive(Default)]
struct SleepState {
    /// A logind inhibitor leiroja. A lezarasa engedi el a kesleltetest.
    inhibitor: Option<OwnedFd>,
    sleeping: bool,
    /// Alvasi ciklusonkent no; a lejart idokorlat ebbol tudja, hogy meg a
    /// sajat ciklusahoz tartozik-e.
    cycle: u64,
    /// A logind `Lock` jelzesek szama a daemon indulasa ota.
    lock_requests: u64,
}

impl SleepState {
    fn begin_sleep(&mut self) -> u64 {
        self.sleeping = true;
        self.cycle += 1;
        self.cycle
    }

    /// A shell zarolt. Alvason kivul nincs mit elengedni: az inhibitor a
    /// kovetkezo alvashoz kell.
    fn ready(&mut self) -> bool {
        if !self.sleeping {
            return false;
        }
        self.inhibitor.take().is_some()
    }

    /// A biztonsagi idokorlat lejart. Egy korabbi ciklus kesve futo idozitoje
    /// nem engedheti el az ebredes utan ujra felvett inhibitort.
    fn timed_out(&mut self, cycle: u64) -> bool {
        if !self.sleeping || self.cycle != cycle {
            return false;
        }
        self.inhibitor.take().is_some()
    }

    fn resumed(&mut self) {
        self.sleeping = false;
        self.inhibitor = None;
    }
}

pub struct Session {
    state: Mutex<SleepState>,
    /// A grafikus munkamenet logind objektuma, ha megtalaltuk.
    session_path: Mutex<Option<OwnedObjectPath>>,
}

impl Default for Session {
    fn default() -> Self {
        Self::new()
    }
}

impl Session {
    pub fn new() -> Self {
        Self { state: Mutex::new(SleepState::default()), session_path: Mutex::new(None) }
    }

    fn state(&self) -> std::sync::MutexGuard<'_, SleepState> {
        self.state.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
    }

    async fn acquire(&self, manager: &LoginManagerProxy<'_>) {
        match manager
            .inhibit("sleep", "Vellum Shell", "A kepernyo zarolasa alvas elott", "delay")
            .await
        {
            Ok(fd) => self.state().inhibitor = Some(fd.into()),
            Err(err) => tracing::warn!(%err, "a logind alvasi inhibitor nem veheto fel"),
        }
    }

    fn publish(&self, sink: &StateSink) {
        let (sleeping, lock_requests) = {
            let state = self.state();
            (state.sleeping, state.lock_requests)
        };
        sink.push(json!({
            "available": true,
            "sleeping": sleeping,
            "lockRequests": lock_requests,
        }));
    }
}

/// A hurok leallasakor (utolso leiratkozas, hiba) elengedi az inhibitort, hogy
/// figyelo shell nelkul ne kesleltessunk minden alvast.
struct ReleaseOnDrop(Arc<Session>);

impl Drop for ReleaseOnDrop {
    fn drop(&mut self) {
        let mut state = self.0.state();
        state.inhibitor = None;
        state.sleeping = false;
    }
}

#[async_trait]
impl Module for Session {
    fn name(&self) -> &'static str {
        "session"
    }

    fn describe(&self) -> ModuleDescription {
        ModuleDescription {
            topic: "session",
            summary: "Alvas elotti zarolas: logind PrepareForSleep, kesleltetett alvassal.",
            streams: true,
            methods: vec![
                MethodDescription::new(
                    "sleepReady",
                    "A shell zarolt; a folyamatban levo alvas mehet.",
                ),
                MethodDescription::new(
                    "setLocked",
                    "A zarolokepernyo allapota a logind `LockedHint`-be.",
                )
                .param("locked", "bool", true, "Zarolva van-e a kepernyo."),
            ],
        }
    }

    async fn run(self: Arc<Self>, sink: StateSink) -> Result<()> {
        let _release = ReleaseOnDrop(self.clone());
        let connection = dbus::system().await?;
        let manager = LoginManagerProxy::new(&connection).await?;
        // Elobb a jelzesre iratkozunk fel, csak utana vesszuk fel az
        // inhibitort: igy a kettejuk kozott indulo alvas sem csuszik at.
        let mut signals = manager.receive_prepare_for_sleep().await?;

        // A `Lock` jelzes opcionalis: nelkule az alvas elotti zarolas meg mukodik.
        let mut lock_signals = match login::graphical_session(&connection, &manager).await {
            Ok(session) => {
                *self.session_path.lock().unwrap_or_else(|p| p.into_inner()) =
                    Some(session.inner().path().to_owned().into());
                Some(session.receive_lock().await?)
            }
            Err(err) => {
                tracing::warn!(%err, "nincs logind munkamenet, a lock-session nem mukodik");
                None
            }
        };

        self.acquire(&manager).await;
        self.publish(&sink);

        loop {
            let lock_request = async {
                match lock_signals.as_mut() {
                    Some(stream) => stream.next().await,
                    None => std::future::pending().await,
                }
            };
            let signal = tokio::select! {
                signal = signals.next() => signal,
                Some(_) = lock_request => {
                    self.state().lock_requests += 1;
                    self.publish(&sink);
                    continue;
                }
            };
            let Some(signal) = signal else { break };

            if signal.args()?.start {
                let cycle = self.state().begin_sleep();
                self.publish(&sink);
                let session = self.clone();
                tokio::spawn(async move {
                    tokio::time::sleep(READY_TIMEOUT).await;
                    if session.state().timed_out(cycle) {
                        tracing::warn!("a shell nem zarolt idoben, az alvas zarolas nelkul indul");
                    }
                });
            } else {
                self.state().resumed();
                self.acquire(&manager).await;
                self.publish(&sink);
            }
        }

        Err(anyhow!("a logind jelzesfolyama lezarult"))
    }

    async fn call(
        self: Arc<Self>,
        method: &str,
        params: Value,
        _sink: &StateSink,
    ) -> Result<Value> {
        match method {
            "sleepReady" => {
                let released = self.state().ready();
                Ok(json!({ "released": released }))
            }
            "setLocked" => {
                let locked = params
                    .get("locked")
                    .and_then(Value::as_bool)
                    .ok_or_else(|| ModuleError::invalid_params("a `locked` bool kotelezo"))?;
                let path = self.session_path.lock().unwrap_or_else(|p| p.into_inner()).clone();
                let Some(path) = path else {
                    return Err(ModuleError::failed("nincs logind munkamenet").into());
                };
                let connection = dbus::system().await?;
                let session = LoginSessionProxy::builder(&connection).path(path)?.build().await?;
                session.set_locked_hint(locked).await?;
                Ok(Value::Null)
            }
            other => Err(ModuleError::UnknownMethod(other.to_string()).into()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn inhibitor() -> OwnedFd {
        std::fs::File::open("/dev/null").unwrap().into()
    }

    #[test]
    fn ready_outside_sleep_keeps_the_inhibitor() {
        let mut state = SleepState { inhibitor: Some(inhibitor()), ..Default::default() };
        assert!(!state.ready());
        assert!(state.inhibitor.is_some());
    }

    #[test]
    fn ready_during_sleep_releases_it() {
        let mut state = SleepState { inhibitor: Some(inhibitor()), ..Default::default() };
        state.begin_sleep();
        assert!(state.ready());
        assert!(state.inhibitor.is_none());
    }

    #[test]
    fn a_stale_timeout_does_not_release_the_next_cycle() {
        let mut state = SleepState { inhibitor: Some(inhibitor()), ..Default::default() };
        let first = state.begin_sleep();
        state.resumed();
        state.inhibitor = Some(inhibitor());
        state.begin_sleep();

        assert!(!state.timed_out(first));
        assert!(state.inhibitor.is_some());
    }

    #[test]
    fn the_current_timeout_releases_it() {
        let mut state = SleepState { inhibitor: Some(inhibitor()), ..Default::default() };
        let cycle = state.begin_sleep();
        assert!(state.timed_out(cycle));
        assert!(state.inhibitor.is_none());
    }
}

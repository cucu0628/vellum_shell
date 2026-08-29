//! ProtonVPN allapot es vezerles.
//!
//! A megosztas ugyanaz, mint a korabbi QML controllerben, es jo okkal: minden
//! `protonvpn` hivas ~2,5 masodperc python-indulas, ezert
//!
//!   * az "fel van-e huzva az alagut" kerdes a NetworkManagertol jon (ezredmasodperc),
//!   * a CLI-t csak reszletekhez es muveletekhez hivjuk, gyorsitotarazva.
//!
//! A parserek szandekosan kulon, tiszta fuggvenyek: a csatlakoztatott allapot
//! kimenetet nem lehet minden gepen eloallitani, igy legalabb egysegteszttel
//! rogzitheto a formatum.

use crate::dbus;
use crate::module::{MethodDescription, Module, ModuleDescription, ModuleError, StateSink};
use crate::nm;
use anyhow::Result;
use async_trait::async_trait;
use futures_util::StreamExt;
use serde::Serialize;
use serde_json::{Value, json};
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::Mutex;

/// Ennyi ideig hisszuk el a CLI-tol kapott reszleteket.
const DETAIL_TTL: Duration = Duration::from_secs(60);

#[derive(Debug, Clone, Default, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct VpnState {
    /// A NetworkManager lat-e alagutat.
    pub active: bool,
    /// A kapcsolat neve a NetworkManagerben, pl. "ProtonVPN NL-FREE#113".
    pub raw_name: String,
    /// Ugyanaz, a "ProtonVPN " elotag nelkul.
    pub name: String,
    /// A CLI szerint csatlakozva vagyunk-e.
    pub cli_connected: bool,
    pub cli_available: bool,

    pub server: String,
    pub location: String,
    pub load: String,
    pub protocol: String,
    pub public_ip: String,
    pub kill_switch: String,
    pub location_selection: bool,
    pub plan_known: bool,
    pub countries: Vec<Country>,
}

impl VpnState {
    /// Az alagut akkor is all, ha a CLI mast mond: a Proton app a CLI hata
    /// mogott is tud csatlakozni, es olyankor csak a NetworkManager latja.
    fn proton_active(&self) -> bool {
        self.raw_name.starts_with("ProtonVPN") || self.cli_connected
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Country {
    pub name: String,
    pub code: String,
}

#[derive(Default)]
struct Cache {
    state: VpnState,
    details_at: Option<Instant>,
    details_key: String,
    config_loaded: bool,
}

pub struct Vpn {
    cache: Mutex<Cache>,
}

impl Vpn {
    pub fn new() -> Self {
        Self { cache: Mutex::new(Cache { state: VpnState { cli_available: true, ..Default::default() }, ..Default::default() }) }
    }

    async fn publish(&self, sink: &StateSink) {
        let cache = self.cache.lock().await;
        sink.push(snapshot(&cache.state));
    }
}

fn snapshot(state: &VpnState) -> Value {
    let mut value = json!(state);
    // Szarmaztatott mezo, hogy a QML ne szamolja ujra.
    value["protonActive"] = json!(state.proton_active());
    value
}

#[async_trait]
impl Module for Vpn {
    fn name(&self) -> &'static str {
        "vpn"
    }

    fn describe(&self) -> ModuleDescription {
        ModuleDescription {
            topic: "vpn",
            summary: "ProtonVPN allapot. Az alagut megletet a NetworkManager adja, a reszleteket a CLI.",
            streams: true,
            methods: vec![
                MethodDescription::new("details", "A CLI reszletei (status). Gyorsitotarazva.")
                    .param("force", "bool", false, "Hagyja figyelmen kivul a gyorsitotarat."),
                MethodDescription::new("config", "Beallitasok (kill switch, csomag).")
                    .param("force", "bool", false, "Hagyja figyelmen kivul a gyorsitotarat."),
                MethodDescription::new("countries", "Valaszthato orszagok. Csak fizetos csomagnal."),
                MethodDescription::new("connect", "Csatlakozas.")
                    .param("country", "string", false, "Orszagkod, pl. NL. Elhagyva a leggyorsabb."),
                MethodDescription::new("disconnect", "Bontas."),
                MethodDescription::new("openApp", "A Proton VPN alkalmazas inditasa."),
            ],
        }
    }

    async fn run(self: Arc<Self>, sink: StateSink) -> Result<()> {
        {
            let mut cache = self.cache.lock().await;
            cache.state.cli_available = which("protonvpn");
        }

        let connection = dbus::system().await?;
        let manager = nm::NetworkManagerProxy::new(&connection).await?;
        let mut active_changes = manager.receive_active_connections_changed().await;
        let mut state_changes = manager.receive_state_changed().await?;

        // Az elso korben mindenkeppen kikuldunk egy snapshotot, kulonben egy
        // frissen feliratkozo kliens addig nem kapna semmit, amig a VPN
        // allapota nem valtozik -- ami akar sosem.
        let mut first = true;

        loop {
            let tunnel = nm::active_links(&connection, &manager)
                .await
                .into_iter()
                .find(nm::ActiveLink::is_tunnel)
                .map(|link| link.id);

            let changed = {
                let mut cache = self.cache.lock().await;
                let raw = tunnel.clone().unwrap_or_default();
                if cache.state.raw_name == raw {
                    false
                } else {
                    cache.state.raw_name = raw.clone();
                    cache.state.active = !raw.is_empty();
                    cache.state.name = match raw.strip_prefix("ProtonVPN") {
                        Some(rest) => rest.trim().to_string(),
                        None => raw,
                    };

                    // Uj szerver: a regi reszletek mar nem rola szolnak. Amit a
                    // NetworkManager tud (a nev), azt megtartjuk.
                    if cache.state.name != cache.details_key {
                        cache.state.server = cache.state.name.clone();
                        cache.state.location.clear();
                        cache.state.load.clear();
                        cache.state.protocol.clear();
                        cache.state.public_ip.clear();
                        cache.details_at = None;
                    }
                    if !cache.state.active {
                        cache.state.cli_connected = false;
                    }
                    true
                }
            };

            if changed || first {
                self.publish(&sink).await;
                first = false;
            }

            tokio::select! {
                _ = active_changes.next() => {}
                _ = state_changes.next() => {}
            }
            tokio::time::sleep(Duration::from_millis(150)).await;
        }
    }

    async fn call(
        self: Arc<Self>,
        method: &str,
        params: Value,
        sink: &StateSink,
    ) -> Result<Value> {
        let force = params.get("force").and_then(Value::as_bool).unwrap_or(false);

        match method {
            "details" => {
                {
                    let cache = self.cache.lock().await;
                    if !cache.state.cli_available {
                        return Err(ModuleError::failed("nincs protonvpn parancs").into());
                    }
                    // Friss adat: nem fizetunk ujabb 2,5 masodpercet.
                    let fresh = cache.details_at.is_some_and(|at| at.elapsed() < DETAIL_TTL)
                        && cache.details_key == cache.state.name;
                    if !force && fresh {
                        return Ok(snapshot(&cache.state));
                    }
                }

                let output = run_cli(&["status"]).await?;
                let status = parse_status(&output);

                let mut cache = self.cache.lock().await;
                cache.details_key = cache.state.name.clone();
                cache.details_at = Some(Instant::now());
                cache.state.cli_connected = status.connected;

                if status.connected {
                    cache.state.server = status.server;
                    cache.state.location = status.location;
                    cache.state.load = status.load;
                    cache.state.protocol = status.protocol;
                } else {
                    cache.state.location.clear();
                    cache.state.load.clear();
                    cache.state.protocol.clear();
                    cache.state.public_ip.clear();
                    // A NetworkManager meg lathatja az alagutat; olyankor a nev
                    // az egyetlen, amink van rola.
                    if !cache.state.raw_name.starts_with("ProtonVPN") {
                        cache.state.server.clear();
                    }
                }

                let value = snapshot(&cache.state);
                drop(cache);
                sink.push(value.clone());
                Ok(value)
            }

            "config" => {
                {
                    let cache = self.cache.lock().await;
                    if !cache.state.cli_available {
                        return Err(ModuleError::failed("nincs protonvpn parancs").into());
                    }
                    if !force && cache.config_loaded {
                        return Ok(snapshot(&cache.state));
                    }
                }

                let output = run_cli(&["config", "list"]).await?;
                let config = parse_config(&output);

                let mut cache = self.cache.lock().await;
                cache.state.kill_switch = config.kill_switch;
                cache.state.location_selection = config.location_selection;
                cache.state.plan_known = config.plan_known;
                cache.config_loaded = config.plan_known;

                let value = snapshot(&cache.state);
                drop(cache);
                sink.push(value.clone());
                Ok(value)
            }

            "countries" => {
                {
                    let cache = self.cache.lock().await;
                    // Ingyenes csomagnal a CLI nem enged helyet valasztani, ezert
                    // meg sem kerdezzuk.
                    if !cache.state.location_selection {
                        return Ok(snapshot(&cache.state));
                    }
                    if !cache.state.countries.is_empty() {
                        return Ok(snapshot(&cache.state));
                    }
                }

                let output = run_cli(&["countries", "list"]).await?;
                let mut cache = self.cache.lock().await;
                cache.state.countries = parse_countries(&output);

                let value = snapshot(&cache.state);
                drop(cache);
                sink.push(value.clone());
                Ok(value)
            }

            "connect" | "disconnect" => {
                let mut args: Vec<String> = vec![method.to_string()];
                if method == "connect"
                    && let Some(country) = params.get("country").and_then(Value::as_str)
                {
                    args.push("--country".into());
                    args.push(country.to_string());
                }

                let borrowed: Vec<&str> = args.iter().map(String::as_str).collect();
                let output = run_cli_result(&borrowed).await;

                let mut cache = self.cache.lock().await;
                let result = match output {
                    Ok(text) => {
                        apply_action_output(&mut cache, &text);
                        Ok(())
                    }
                    Err(text) => Err(action_error(&text)),
                };

                let value = snapshot(&cache.state);
                drop(cache);
                sink.push(value.clone());

                match result {
                    Ok(()) => Ok(value),
                    Err(message) => Err(ModuleError::failed(message).into()),
                }
            }

            "openApp" => {
                // Sajat sessionbe tesszuk, hogy a daemon leallasa ne vigye
                // magaval a meg indulo alkalmazast.
                let _ = tokio::process::Command::new("setsid")
                    .arg("protonvpn-app")
                    .stdin(std::process::Stdio::null())
                    .stdout(std::process::Stdio::null())
                    .stderr(std::process::Stdio::null())
                    .spawn();
                Ok(json!({ "launched": true }))
            }

            other => Err(ModuleError::UnknownMethod(other.to_string()).into()),
        }
    }
}

fn which(program: &str) -> bool {
    std::env::var_os("PATH").is_some_and(|paths| {
        std::env::split_paths(&paths).any(|dir| dir.join(program).is_file())
    })
}

async fn run_cli(args: &[&str]) -> Result<String> {
    run_cli_result(args).await.map_err(|text| ModuleError::failed(action_error(&text)).into())
}

/// `Ok(stdout)` sikeres futasnal, `Err(stderr vagy stdout)` egyebkent.
async fn run_cli_result(args: &[&str]) -> std::result::Result<String, String> {
    let output = tokio::process::Command::new("protonvpn")
        .args(args)
        // A python figyelmeztetesei kulonben belekeverednek a kimenetbe.
        .env("PYTHONWARNINGS", "ignore")
        .output()
        .await
        .map_err(|err| err.to_string())?;

    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    if output.status.success() {
        Ok(stdout)
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();
        Err(if stderr.trim().is_empty() { stdout } else { stderr })
    }
}

#[derive(Debug, Default, PartialEq)]
struct StatusInfo {
    connected: bool,
    server: String,
    location: String,
    load: String,
    protocol: String,
}

/// A `protonvpn status` kimenete `Kulcs: ertek` sorok. A szerver sora
/// "NL-FREE#113 in Amsterdam, Netherlands" alaku.
fn parse_status(output: &str) -> StatusInfo {
    let mut info = StatusInfo::default();

    for line in output.lines() {
        let Some((key, value)) = line.trim().split_once(':') else {
            continue;
        };
        let value = value.trim();
        match key.trim().to_lowercase().as_str() {
            "status" => info.connected = value.eq_ignore_ascii_case("connected"),
            "server" => match value.split_once(" in ") {
                Some((server, location)) => {
                    info.server = server.to_string();
                    info.location = location.to_string();
                }
                None => info.server = value.to_string(),
            },
            "load" => info.load = value.to_string(),
            "protocol" => info.protocol = value.to_string(),
            _ => {}
        }
    }

    info
}

#[derive(Debug, Default, PartialEq)]
struct ConfigInfo {
    kill_switch: String,
    location_selection: bool,
    plan_known: bool,
}

/// A `protonvpn config list` egy tablazat. Az ingyenes csomag a fizetos
/// beallitasokat "Upgrade to enable"-kent mutatja -- es pont akkor tagadja meg
/// a CLI a helyvalasztast is.
fn parse_config(output: &str) -> ConfigInfo {
    let trimmed = output.trim();
    let kill_switch = output
        .lines()
        .find_map(|line| line.trim().strip_prefix("kill-switch"))
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .unwrap_or_default()
        .to_string();

    ConfigInfo {
        kill_switch,
        location_selection: !trimmed.is_empty() && !trimmed.contains("Upgrade to enable"),
        plan_known: !trimmed.is_empty(),
    }
}

/// A `protonvpn countries list` sorai: nev, legalabb ket szokoz, ketbetus kod.
fn parse_countries(output: &str) -> Vec<Country> {
    output
        .lines()
        .filter_map(|line| {
            if line.starts_with("---") || line.trim().is_empty() {
                return None;
            }
            let (name, code) = line.rsplit_once("  ")?;
            let (name, code) = (name.trim(), code.trim());
            if name.is_empty() || name == "Country" {
                return None;
            }
            let is_code = code.len() == 2 && code.chars().all(|c| c.is_ascii_uppercase());
            is_code.then(|| Country { name: name.to_string(), code: code.to_string() })
        })
        .collect()
}

/// A `connect` mar megmondja, hova kotott ki, igy a panel azonnal beallhat egy
/// ujabb status hivas nelkul.
fn apply_action_output(cache: &mut Cache, output: &str) {
    for line in clean_output(output) {
        if let Some((server, location)) = parse_connected_to(&line) {
            cache.state.server = server.clone();
            cache.state.location = location;
            cache.state.raw_name = format!("ProtonVPN {server}");
            cache.state.name = server.clone();
            cache.state.active = true;
            cache.state.cli_connected = true;
            cache.details_key = server;
            cache.details_at = Some(Instant::now());
        }

        if let Some(address) = parse_public_ip(&line) {
            cache.state.public_ip = address;
        }

        if line.starts_with("Disconnected") {
            cache.state = VpnState {
                cli_available: cache.state.cli_available,
                kill_switch: std::mem::take(&mut cache.state.kill_switch),
                location_selection: cache.state.location_selection,
                plan_known: cache.state.plan_known,
                countries: std::mem::take(&mut cache.state.countries),
                ..Default::default()
            };
            cache.details_key.clear();
            cache.details_at = None;
        }
    }
}

/// "Connected to NL-FREE#113 in Amsterdam, Netherlands."
fn parse_connected_to(line: &str) -> Option<(String, String)> {
    let rest = line.strip_prefix("Connected to ")?;
    let (server, location) = rest.split_once(" in ")?;
    let location = location.trim_end_matches('.').trim();
    Some((server.trim().to_string(), location.to_string()))
}

/// "Your new IP address is 1.2.3.4."
fn parse_public_ip(line: &str) -> Option<String> {
    let index = line.find("IP address is ")?;
    let rest = &line[index + "IP address is ".len()..];
    let address: String = rest
        .chars()
        .take_while(|c| c.is_ascii_hexdigit() || *c == '.' || *c == ':')
        .collect();
    (!address.is_empty()).then(|| address.trim_end_matches('.').to_string())
}

/// A python figyelmeztetesei nem tartoznak a valaszhoz.
fn clean_output(output: &str) -> Vec<String> {
    output
        .lines()
        .map(str::trim)
        .filter(|line| {
            !line.is_empty()
                && !line.to_lowercase().contains("eventlet")
                && !line.contains("warnings.warn")
        })
        .map(str::to_string)
        .collect()
}

fn action_error(output: &str) -> String {
    let lines = clean_output(output);
    if let Some(error) = lines.iter().find_map(|line| line.strip_prefix("Error:")) {
        return error.trim().to_string();
    }
    lines
        .iter()
        .rev()
        .find(|line| !line.starts_with("Try '") && !line.starts_with("Usage:"))
        .cloned()
        .unwrap_or_else(|| "The Proton VPN CLI reported an error".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    // A csatlakoztatott allapotot nem lehet minden gepen eloallitani, ezert a
    // formatumot itt rogzitjuk.
    #[test]
    fn status_connected() {
        let info = parse_status(
            "Status: Connected\nServer: NL-FREE#113 in Amsterdam, Netherlands\nLoad: 45%\nProtocol: WireGuard\n",
        );
        assert!(info.connected);
        assert_eq!(info.server, "NL-FREE#113");
        assert_eq!(info.location, "Amsterdam, Netherlands");
        assert_eq!(info.load, "45%");
        assert_eq!(info.protocol, "WireGuard");
    }

    /// Ez a gep valodi kimenete kikapcsolt allapotban.
    #[test]
    fn status_disconnected() {
        let info = parse_status("Status: Disconnected\n");
        assert!(!info.connected);
        assert_eq!(info.server, "");
    }

    #[test]
    fn server_without_location() {
        let info = parse_status("Status: Connected\nServer: NL-FREE#113\n");
        assert_eq!(info.server, "NL-FREE#113");
        assert_eq!(info.location, "");
    }

    /// Ez a gep valodi `config list` kimenete (ingyenes csomag).
    #[test]
    fn config_free_plan() {
        let output = "\nCurrent configuration\nSetting                  Value\n\
                      -----------------------  -----------------\n\
                      netshield                Upgrade to enable\n\
                      kill-switch              off\n\
                      port-forwarding          Upgrade to enable\n\
                      ipv6                     on\n";
        let config = parse_config(output);
        assert_eq!(config.kill_switch, "off");
        assert!(config.plan_known);
        // Az "Upgrade to enable" jelenlete pont azt jelzi, hogy nincs helyvalasztas.
        assert!(!config.location_selection);
    }

    #[test]
    fn config_paid_plan_allows_location_selection() {
        let output = "Setting      Value\nkill-switch  on\nnetshield    f2\n";
        let config = parse_config(output);
        assert_eq!(config.kill_switch, "on");
        assert!(config.location_selection);
    }

    #[test]
    fn config_empty_output_is_unknown() {
        let config = parse_config("");
        assert!(!config.plan_known);
        assert!(!config.location_selection);
    }

    #[test]
    fn countries_are_parsed_and_header_skipped() {
        let output = "Country          Code\n---------------  ----\nNetherlands      NL\nUnited States    US\n";
        let countries = parse_countries(output);
        assert_eq!(
            countries,
            vec![
                Country { name: "Netherlands".into(), code: "NL" .into() },
                Country { name: "United States".into(), code: "US".into() },
            ]
        );
    }

    #[test]
    fn connected_to_line() {
        assert_eq!(
            parse_connected_to("Connected to NL-FREE#113 in Amsterdam, Netherlands."),
            Some(("NL-FREE#113".into(), "Amsterdam, Netherlands".into()))
        );
        assert_eq!(parse_connected_to("valami mas"), None);
    }

    #[test]
    fn public_ip_line() {
        assert_eq!(parse_public_ip("Your new IP address is 1.2.3.4."), Some("1.2.3.4".into()));
        assert_eq!(parse_public_ip("nincs benne cim"), None);
    }

    #[test]
    fn action_error_prefers_explicit_error_line() {
        assert_eq!(action_error("Error: something broke\nTry 'protonvpn --help'"), "something broke");
    }

    #[test]
    fn action_error_falls_back_to_last_useful_line() {
        assert_eq!(action_error("bajban vagyunk\nUsage: protonvpn"), "bajban vagyunk");
    }

    #[test]
    fn python_noise_is_dropped() {
        let lines = clean_output("eventlet monkey patching\n\nConnected to X in Y.\nwarnings.warn(...)");
        assert_eq!(lines, vec!["Connected to X in Y."]);
    }

    #[test]
    fn proton_active_when_only_network_manager_sees_the_tunnel() {
        // A Proton app a CLI hata mogott is tud csatlakozni.
        let state = VpnState {
            raw_name: "ProtonVPN NL-FREE#113".into(),
            cli_connected: false,
            ..Default::default()
        };
        assert!(state.proton_active());
    }
}

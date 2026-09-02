//! Hyprland beallitasok: monitorok es kompozitor-opciok.
//!
//! Ez a modul a settings app Display / Windows / Input oldalait szolgalja ki.
//! Harom reteget tart szinkronban, mert mindharomra szukseg van:
//!
//!   1. `~/.config/hypr/vellum-settings.json` -- az igazsag forrasa. Csak az
//!      kerul bele, amit a felhasznalo *kifejezetten* allitott a settings
//!      appban. Semas, ezert visszaolvashato Lua-parse-olas nelkul.
//!   2. Generalt Lua modulok (`vellum_display.lua`, `vellum_tuning.lua`). Ezek
//!      a `hyprland.lua` require-listajanak a vegen ulnek, ugyanugy, mint a
//!      tema `colors.lua`-ja, igy felulirjak a felhasznalo kezzel irt
//!      `monitors.lua` / `appearance.lua` fajljait -- azokhoz sosem nyulunk.
//!   3. Elo allapot: `hyprctl eval` + a nativ Lua API, hogy a valtozas reload
//!      nelkul lassszon.
//!
//! A `read` szandekosan az **elo** erteket adja vissza (`hyprctl getoption`) es
//! nem a store-t: igy a csuszkak akkor is a valosagot mutatjak, ha a
//! felhasznalo a sajat konfigjaban allitott valamit.

use crate::edid;
use crate::module::{MethodDescription, Module, ModuleDescription, ModuleError, StateSink};
use crate::theme::paths;
use crate::theme::render::write_if_changed;
use anyhow::{Context, Result};
use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use serde_json::{Map, Value, json};
use std::collections::{BTreeMap, BTreeSet};
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;

/// Amit a settings app olvasni es allitani tud. A lista szandekosan zart: egy
/// ismeretlen kulcs elgepelesbol is szarmazhat, es a Lua API-nak sem adunk at
/// tetszoleges kodot a kliensbol.
const OPTION_KEYS: &[&str] = &[
    "general:gaps_in",
    "general:gaps_out",
    "general:border_size",
    "general:layout",
    "general:resize_on_border",
    "decoration:rounding",
    "decoration:active_opacity",
    "decoration:inactive_opacity",
    "decoration:blur:enabled",
    "decoration:blur:size",
    "decoration:blur:passes",
    "decoration:shadow:enabled",
    "decoration:shadow:range",
    "animations:enabled",
    "input:kb_layout",
    "input:kb_variant",
    "input:repeat_rate",
    "input:repeat_delay",
    "input:sensitivity",
    "input:follow_mouse",
    "input:touchpad:natural_scroll",
    "input:touchpad:tap-to-click",
];

/// A Quickshell `FloatingWindow` egy rendes xdg-toplevel, amit Hyprland
/// alapesetben ugyanugy csempez, mint barmely mas alkalmazast. Ez a szabaly
/// csak a Vellum Settings pontos cimere illeszkedik; a tobbi Quickshell ablakot
/// es layer surface-t nem erinti.
const SETTINGS_WINDOW_RULE: &str = r#"hl.window_rule({
    name = "vellum-settings",
    match = {
        class = "^org\\.quickshell$",
        title = "^Vellum Settings$",
    },
    size = { 1040, 700 },
    float = true,
    center = true,
})
"#;

/// Egy monitor perzisztalt beallitasa. Minden mezo opcionalis: amit a
/// felhasznalo nem allitott, azt nem irjuk ki, hogy a Hyprland alapertelmezese
/// (`preferred` / `auto`) ervenyben maradhasson.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct MonitorSetting {
    pub output: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub mode: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub position: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub scale: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub transform: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub vrr: Option<u32>,
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub disabled: bool,
}

/// A lemezen tarolt beallitasok. Ures store eseten a kijelzomodul csak a
/// fejleckommentet, a tuning modul pedig a Settings ablakszabalyt tartalmazza.
/// Letezniuk mindig kell, mert a Lua `require` hibaval all meg egy hianyzo
/// modulon.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct Store {
    #[serde(default)]
    pub monitors: Vec<MonitorSetting>,
    #[serde(default)]
    pub options: BTreeMap<String, Value>,
}

impl Store {
    pub fn load() -> Self {
        let path = paths::hypr_settings_file();
        let Ok(text) = std::fs::read_to_string(&path) else {
            return Self::default();
        };
        match serde_json::from_str(&text) {
            Ok(store) => store,
            Err(err) => {
                // Egy serult store nem allithatja meg a daemont: ures
                // beallitasokkal indulunk, a felhasznalo konfigja megmarad.
                tracing::warn!(%err, path = %path.display(), "a hypr store nem olvashato");
                Self::default()
            }
        }
    }

    pub fn save(&self) -> Result<()> {
        let text = serde_json::to_string_pretty(self)?;
        write_if_changed(&paths::hypr_settings_file(), &format!("{text}\n"))?;
        Ok(())
    }

    /// Kiirja a ket generalt Lua modult. Mindig mindkettot, hogy egy torolt
    /// beallitas is eltunjon a konfigbol.
    pub fn render(&self) -> Result<()> {
        write_if_changed(&paths::hypr_display_module(), &render_display_lua(&self.monitors))?;
        write_if_changed(&paths::hypr_tuning_module(), &render_tuning_lua(&self.options))?;
        Ok(())
    }

    fn upsert_monitor(&mut self, setting: MonitorSetting) {
        match self.monitors.iter_mut().find(|item| item.output == setting.output) {
            Some(existing) => *existing = setting,
            None => self.monitors.push(setting),
        }
    }
}

/// Meddig el egy meg nem erositett kijelzo-elonezet. Ennyi ido utan a backend
/// magatol visszaall -- akkor is, ha a settings ablak vagy az egesz shell
/// addigra eltunt.
const PREVIEW_TIMEOUT_MS: u64 = 12_000;

/// Ertelmes skalahatarok. A Hyprland ennel szelsosegesebbet is elfogad, de
/// olyat mar nem lehet visszakattintani.
const MIN_SCALE: f64 = 0.25;
const MAX_SCALE: f64 = 8.0;

/// Egy folyamatban levo, meg meg nem erositett kijelzovaltas.
///
/// Szandekosan a backend birtokolja es nem a settings app: egy rossz mod vagy
/// pozicio pont azt a felulet teszi hasznalhatatlanna, aminek vissza kellene
/// vonnia. Igy a visszaallitas akkor is lefut, ha a kliens oldal kozben
/// megsemmisult -- oldalvaltas, ablakbezaras vagy shell-osszeomlas eseten is.
struct Preview {
    token: String,
    /// Az elonezet elott ervenyes elo allapot, teljes egeszeben.
    previous: Vec<MonitorSetting>,
    /// Amit meg kell erositeni. Csak `confirmMonitors` utan kerul a store-ba.
    requested: Vec<MonitorSetting>,
    /// Az automatikus visszaallitast vegzo task. Confirm/revert leallitja.
    guard: tokio::task::JoinHandle<()>,
}

#[derive(Default)]
struct HyprState {
    preview: Option<Preview>,
}

pub struct Hypr {
    /// Minden modositast sorbaallit. A `setOptions` es a `setMonitors` kulonben
    /// egymas ala olvashatna be a store-t es veszthetne el a masik irasat.
    /// Ugyanez a zar vedi az elonezet allapotat is, igy nincs zarolasi sorrend,
    /// amit el lehetne rontani.
    state: tokio::sync::Mutex<HyprState>,
}

impl Default for Hypr {
    fn default() -> Self {
        Self::new()
    }
}

impl Hypr {
    pub fn new() -> Self {
        Self { state: tokio::sync::Mutex::new(HyprState::default()) }
    }

    fn snapshot() -> Value {
        json!({
            "available": hyprctl(&["version"]).is_ok(),
            "monitors": monitors(),
            "options": read_options(),
        })
    }

    /// Elonezet inditasa: ervenyesites, elo alkalmazas, es egy fegyverbe
    /// allitott visszaallitas. A store-hoz **nem** nyulunk -- az csak a
    /// megerositeskor valtozik.
    async fn begin_preview(
        self: &Arc<Self>,
        state: &mut HyprState,
        requested: Vec<MonitorSetting>,
        sink: &StateSink,
    ) -> Result<Value> {
        let live = tokio::task::spawn_blocking(live_monitors).await??;
        validate_layout(&requested, &live)?;

        // Egymast koveto finomhangolasok mind az utolso *megerositett*
        // allapotra allnak vissza, nem az elozo elonezetre.
        let previous = match state.preview.take() {
            Some(pending) => {
                pending.guard.abort();
                pending.previous
            }
            None => snapshot_settings(&live),
        };

        let attempt = requested.clone();
        let rollback = previous.clone();
        if let Err(err) = tokio::task::spawn_blocking(move || apply_live(&attempt)).await? {
            // A felig alkalmazott elrendezes nem maradhat itt: ez az az eset,
            // amikor a felhasznalonak mar nincs mivel visszakattintania.
            let _ = tokio::task::spawn_blocking(move || apply_live(&rollback)).await?;
            return Err(err);
        }

        let token = next_token();
        let guard = tokio::spawn({
            let module = Arc::clone(self);
            let token = token.clone();
            let sink = sink.clone();
            async move {
                tokio::time::sleep(Duration::from_millis(PREVIEW_TIMEOUT_MS)).await;
                module.expire_preview(&token, &sink).await;
            }
        });

        state.preview =
            Some(Preview { token: token.clone(), previous, requested: requested.clone(), guard });

        Ok(json!({
            "token": token,
            "timeoutMs": PREVIEW_TIMEOUT_MS,
            "monitors": requested,
        }))
    }

    /// Megerosites: a mar elo elrendezes lemezre kerul.
    async fn confirm_preview(&self, state: &mut HyprState, token: &str) -> Result<Value> {
        let preview = take_preview(state, token)?;
        let requested = preview.requested;
        let store = tokio::task::spawn_blocking(move || persist_monitors(requested)).await??;
        Ok(json!({ "monitors": store.monitors }))
    }

    /// Azonnali visszavonas, a lejaratra varas nelkul.
    async fn revert_preview(&self, state: &mut HyprState, token: &str) -> Result<Value> {
        let preview = take_preview(state, token)?;
        let previous = preview.previous;
        let restore = previous.clone();
        tokio::task::spawn_blocking(move || apply_live(&restore)).await??;
        Ok(json!({ "monitors": previous }))
    }

    /// A lejarati task teste. Nem `take_preview`-t hasznal, mert itt nincs mit
    /// abortalni: ez maga a fegyverben allo task.
    async fn expire_preview(&self, token: &str, sink: &StateSink) {
        let mut state = self.state.lock().await;
        let Some(preview) = state.preview.take_if(|pending| pending.token == token) else {
            return;
        };

        let previous = preview.previous;
        match tokio::task::spawn_blocking(move || apply_live(&previous)).await {
            Ok(Ok(())) => tracing::info!(token, "a kijelzo-elonezet lejart, visszaallitva"),
            Ok(Err(err)) => tracing::error!(%err, "a kijelzo-elonezet nem allithato vissza"),
            Err(err) => tracing::error!(%err, "a visszaallito task elszallt"),
        }
        drop(state);

        if let Ok(snapshot) = tokio::task::spawn_blocking(Hypr::snapshot).await {
            sink.push(snapshot);
        }
    }
}

#[async_trait]
impl Module for Hypr {
    fn name(&self) -> &'static str {
        "hypr"
    }

    fn describe(&self) -> ModuleDescription {
        ModuleDescription {
            topic: "hypr",
            summary: "Hyprland monitorok es kompozitor-opciok, elo es perzisztalt allitassal.",
            streams: true,
            methods: vec![
                MethodDescription::new("monitors", "A kijelzok, EDID-azonositoval."),
                MethodDescription::new("read", "Az ismert kompozitor-opciok elo ertekei."),
                MethodDescription::new(
                    "prepare",
                    "A Vellum Settings ablak Hyprland-szabalyanak elokeszitese.",
                ),
                MethodDescription::new("stored", "Amit a settings app eddig perzisztalt."),
                MethodDescription::new("setOptions", "Opciok allitasa eloben es a konfigban.")
                    .param("values", "object", true, "Kulcs -> ertek parok."),
                MethodDescription::new("setMonitors", "Monitorok allitasa eloben es a konfigban.")
                    .param("monitors", "array", true, "MonitorSetting objektumok listaja."),
                MethodDescription::new(
                    "previewMonitors",
                    "Kijelzovaltas elonezetben: eloben alkalmaz, de nem ment. \
                     Megerosites nelkul a backend magatol visszaallitja.",
                )
                .param(
                    "monitors",
                    "array",
                    true,
                    "MonitorSetting objektumok listaja.",
                ),
                MethodDescription::new(
                    "confirmMonitors",
                    "Egy fuggo elonezet veglegesitese es perzisztalasa.",
                )
                .param("token", "string", true, "A previewMonitors adta token."),
                MethodDescription::new(
                    "revertMonitors",
                    "Egy fuggo elonezet azonnali visszavonasa.",
                )
                .param("token", "string", true, "A previewMonitors adta token."),
                MethodDescription::new("reset", "Perzisztalt beallitasok eldobasa a store-bol.")
                    .param("scope", "string", true, "options, monitors vagy all."),
            ],
        }
    }

    async fn run(self: Arc<Self>, sink: StateSink) -> Result<()> {
        // A generalt modulok mar az elso feliratkozaskor letezzenek, kulonben a
        // setup altal beirt `require` egy friss gepen hibara futna.
        if let Err(err) = tokio::task::spawn_blocking(|| Store::load().render()).await? {
            tracing::warn!(%err, "a hypr Lua modulok nem irhatoak");
        }

        sink.push(tokio::task::spawn_blocking(Hypr::snapshot).await?);

        let Some(path) = event_socket_path() else {
            // Nem Hyprland session: a snapshot megvan, streamelni nincs mit.
            std::future::pending::<()>().await;
            return Ok(());
        };

        loop {
            if let Err(err) = watch_events(&path, &sink).await {
                tracing::debug!(%err, "a Hyprland event socket megszakadt");
            }
            tokio::time::sleep(Duration::from_secs(2)).await;
        }
    }

    async fn call(self: Arc<Self>, method: &str, params: Value, sink: &StateSink) -> Result<Value> {
        match method {
            "monitors" => Ok(tokio::task::spawn_blocking(monitors).await?),

            "read" => Ok(tokio::task::spawn_blocking(read_options).await?),

            "prepare" => Ok(tokio::task::spawn_blocking(prepare).await??),

            "stored" => Ok(serde_json::to_value(tokio::task::spawn_blocking(Store::load).await?)?),

            "setOptions" => {
                let values = params
                    .get("values")
                    .and_then(Value::as_object)
                    .ok_or_else(|| ModuleError::invalid_params("hianyzik a 'values' objektum"))?
                    .clone();

                for key in values.keys() {
                    if !OPTION_KEYS.contains(&key.as_str()) {
                        return Err(ModuleError::invalid_params(format!(
                            "ismeretlen opcio: {key}"
                        ))
                        .into());
                    }
                }

                let _state = self.state.lock().await;
                let applied = tokio::task::spawn_blocking(move || set_options(values)).await??;
                sink.push(tokio::task::spawn_blocking(Hypr::snapshot).await?);
                Ok(applied)
            }

            "setMonitors" => {
                let monitors = parse_monitors(&params)?;
                let _state = self.state.lock().await;
                let applied = tokio::task::spawn_blocking(move || set_monitors(monitors)).await??;
                sink.push(tokio::task::spawn_blocking(Hypr::snapshot).await?);
                Ok(applied)
            }

            "previewMonitors" => {
                let monitors = parse_monitors(&params)?;
                let mut state = self.state.lock().await;
                let started = self.begin_preview(&mut state, monitors, sink).await?;
                drop(state);
                sink.push(tokio::task::spawn_blocking(Hypr::snapshot).await?);
                Ok(started)
            }

            "confirmMonitors" => {
                let token = parse_token(&params)?;
                let mut state = self.state.lock().await;
                let confirmed = self.confirm_preview(&mut state, &token).await?;
                drop(state);
                sink.push(tokio::task::spawn_blocking(Hypr::snapshot).await?);
                Ok(confirmed)
            }

            "revertMonitors" => {
                let token = parse_token(&params)?;
                let mut state = self.state.lock().await;
                let reverted = self.revert_preview(&mut state, &token).await?;
                drop(state);
                sink.push(tokio::task::spawn_blocking(Hypr::snapshot).await?);
                Ok(reverted)
            }

            "reset" => {
                let scope = params
                    .get("scope")
                    .and_then(Value::as_str)
                    .ok_or_else(|| ModuleError::invalid_params("hianyzik a 'scope'"))?
                    .to_string();

                let _state = self.state.lock().await;
                let store = tokio::task::spawn_blocking(move || reset(&scope)).await??;
                sink.push(tokio::task::spawn_blocking(Hypr::snapshot).await?);
                Ok(serde_json::to_value(store)?)
            }

            other => Err(ModuleError::UnknownMethod(other.to_string()).into()),
        }
    }
}

// -- muveletek ---------------------------------------------------------------

fn prepare() -> Result<Value> {
    // A rendereles a kovetkezo Hyprland-indulasra is megorzi a szabalyt, az
    // eval pedig az aktualis sessionben teszi elerhetove meg az ablak mapelese
    // elott. Hyprland nelkul a shell tovabbra is degradaltan indul.
    Store::load().render()?;
    let available = hyprctl(&["eval", SETTINGS_WINDOW_RULE]).is_ok();
    Ok(json!({ "available": available }))
}

fn set_options(values: Map<String, Value>) -> Result<Value> {
    let mut store = Store::load();

    // A tarolt es az elo alak ugyanaz a halmaz, csak mas rendezessel: egyszer
    // vesszuk at, aztan mindketto ebbol dolgozik.
    let live_options: BTreeMap<String, Value> = values.into_iter().collect();
    let live_code = render_options_lua(&live_options);

    // A nativ Lua parser mellett a `hyprctl keyword` 0 statuszt ad, de nem
    // csinal semmit. Az `eval` ugyanazt a publikus API-t futtatja, mint a
    // perzisztalt modul. Az elo allitas elbukhat (nem Hyprland session), de a
    // perzisztalas ilyenkor is helyes: kovetkezo indulaskor ervenyre jut.
    if !live_code.is_empty()
        && let Err(err) = hyprctl(&["eval", &live_code])
    {
        tracing::warn!(%err, "a Hyprland opciok nem allithatoak eloben");
    }

    store.options.extend(live_options);

    store.render()?;
    store.save()?;
    Ok(json!({ "options": store.options }))
}

/// Monitorok allitasa egy lepesben. Elonezet nelkuli ut: a settings app a
/// kockazatos valtoztatasokra a `previewMonitors`-t hasznalja, ez a hivas
/// azoknak marad, akik mar tudjak, mit akarnak.
///
/// Ket dolgot csinal maskepp, mint korabban: ervenyesit, mielott hozzanyulna a
/// kompozitorhoz, es **csak sikeres elo alkalmazas utan ment**. Egy elbukott
/// eval korabban is a lemezre kerult, igy egy hibas beallitas a kovetkezo
/// indulaskor visszajott.
fn set_monitors(monitors: Vec<MonitorSetting>) -> Result<Value> {
    // Hyprland nelkul nincs mit ervenyesiteni es nincs mit eloben allitani, a
    // perzisztalas viszont ilyenkor is helyes: kovetkezo indulaskor ervenyre
    // jut. Ez a shell graceful degradation szerzodese.
    let live = live_monitors().ok();

    if let Some(live) = &live {
        validate_layout(&monitors, live)?;
        let previous = snapshot_settings(live);
        if let Err(err) = apply_live(&monitors) {
            // Egy felig alkalmazott elrendezes rosszabb, mint a regi.
            let _ = apply_live(&previous);
            return Err(err);
        }
    }

    let store = persist_monitors(monitors)?;
    Ok(json!({ "monitors": store.monitors, "live": live.is_some() }))
}

/// A store frissitese es kiirasa. Csak akkor hivjuk, ha az elo alkalmazas mar
/// sikerult (vagy nincs elo session).
fn persist_monitors(monitors: Vec<MonitorSetting>) -> Result<Store> {
    let mut store = Store::load();
    for setting in monitors {
        store.upsert_monitor(setting);
    }
    store.render()?;
    store.save()?;
    Ok(store)
}

/// Egyetlen `hyprctl eval` az egesz elrendezesre. Egy hivas egy chunkban: a
/// kijelzok pozicioja egymashoz kepest ertelmes, ezert nem akarunk kozottuk
/// olyan pillanatot, amikor csak a fele allt at.
fn apply_live(monitors: &[MonitorSetting]) -> Result<()> {
    let mut code = String::new();
    for setting in monitors {
        code.push_str(&render_monitor_lua(setting));
    }
    if code.is_empty() {
        return Ok(());
    }
    hyprctl(&["eval", &code])?;
    Ok(())
}

/// Az elo allapot teljes `MonitorSetting` listakent -- ez a visszaallitas
/// alapja. Minden mezot kiirunk, mert a visszaallitasnak nem szabad a Hyprland
/// alapertelmezesere hagyatkoznia.
fn snapshot_settings(live: &[LiveMonitor]) -> Vec<MonitorSetting> {
    live.iter()
        .map(|monitor| MonitorSetting {
            output: monitor.name.clone(),
            mode: Some(format!(
                "{}x{}@{}",
                monitor.width,
                monitor.height,
                monitor.refresh_rate.round() as i64
            )),
            position: Some(format!("{}x{}", monitor.x, monitor.y)),
            scale: Some(if monitor.scale > 0.0 { monitor.scale } else { 1.0 }),
            transform: Some(monitor.transform),
            vrr: monitor.vrr.map(u32::from),
            disabled: monitor.disabled,
        })
        .collect()
}

fn next_token() -> String {
    static COUNTER: AtomicU64 = AtomicU64::new(1);
    let serial = COUNTER.fetch_add(1, Ordering::Relaxed);
    format!("display-{}-{serial}", std::process::id())
}

fn take_preview(state: &mut HyprState, token: &str) -> Result<Preview> {
    let Some(preview) = state.preview.take_if(|pending| pending.token == token) else {
        return Err(ModuleError::not_found(
            "nincs fuggo kijelzo-elonezet ezzel a tokennel (talan mar lejart)",
        )
        .into());
    };
    preview.guard.abort();
    Ok(preview)
}

fn parse_monitors(params: &Value) -> Result<Vec<MonitorSetting>> {
    let raw = params
        .get("monitors")
        .cloned()
        .ok_or_else(|| ModuleError::invalid_params("hianyzik a 'monitors' tomb"))?;
    let monitors: Vec<MonitorSetting> =
        serde_json::from_value(raw).map_err(|err| ModuleError::invalid_params(err.to_string()))?;
    if monitors.is_empty() {
        return Err(ModuleError::invalid_params("ures 'monitors' tomb").into());
    }
    Ok(monitors)
}

fn parse_token(params: &Value) -> Result<String> {
    params
        .get("token")
        .and_then(Value::as_str)
        .filter(|token| !token.trim().is_empty())
        .map(str::to_string)
        .ok_or_else(|| ModuleError::invalid_params("hianyzik a 'token'").into())
}

fn reset(scope: &str) -> Result<Store> {
    let mut store = Store::load();
    match scope {
        "options" => store.options.clear(),
        "monitors" => store.monitors.clear(),
        "all" => store = Store::default(),
        other => return Err(ModuleError::invalid_params(format!("rossz scope: {other}")).into()),
    }

    store.render()?;
    store.save()?;
    // Az elo felulirasokat csak egy reload tudja visszavonni: az ujra beolvassa
    // a konfigot, amibol mar kikerult a torolt ertek.
    let _ = hyprctl(&["reload"]);
    Ok(store)
}

// -- ervenyesites ------------------------------------------------------------

/// Egy csatlakoztatott kijelzo elo allapota, annyi mezovel, amennyit az
/// ervenyesites hasznal.
#[derive(Debug, Clone, PartialEq)]
struct LiveMonitor {
    name: String,
    width: i64,
    height: i64,
    refresh_rate: f64,
    x: i64,
    y: i64,
    scale: f64,
    transform: u32,
    vrr: Option<u8>,
    disabled: bool,
    available_modes: Vec<String>,
}

impl LiveMonitor {
    fn from_value(value: &Value) -> Option<Self> {
        let object = value.as_object()?;
        Some(Self {
            name: object.get("name")?.as_str()?.to_string(),
            width: object.get("width").and_then(Value::as_i64).unwrap_or(0),
            height: object.get("height").and_then(Value::as_i64).unwrap_or(0),
            refresh_rate: object.get("refreshRate").and_then(Value::as_f64).unwrap_or(0.0),
            x: object.get("x").and_then(Value::as_i64).unwrap_or(0),
            y: object.get("y").and_then(Value::as_i64).unwrap_or(0),
            scale: object.get("scale").and_then(Value::as_f64).unwrap_or(1.0),
            transform: object.get("transform").and_then(Value::as_u64).unwrap_or(0) as u32,
            vrr: object.get("vrr").and_then(Value::as_bool).map(u8::from),
            disabled: object.get("disabled").and_then(Value::as_bool).unwrap_or(false),
            available_modes: object
                .get("availableModes")
                .and_then(Value::as_array)
                .map(|modes| modes.iter().filter_map(Value::as_str).map(str::to_string).collect())
                .unwrap_or_default(),
        })
    }
}

/// Az elo kijelzok, hibaval, ha nincs Hyprland. A `monitors()` szandekosan
/// nyeli a hibat (a snapshot udvarias ures listat ad), itt viszont pont az a
/// kerdes, hogy van-e mihez kepest ervenyesiteni.
fn live_monitors() -> Result<Vec<LiveMonitor>> {
    let text = hyprctl(&["-j", "monitors", "all"])?;
    let list: Vec<Value> =
        serde_json::from_str(&text).context("a hyprctl monitor-listaja ertelmezhetetlen")?;
    Ok(list.iter().filter_map(LiveMonitor::from_value).collect())
}

/// Egy kijelzo helye a kert elrendezes utan, logikai pixelben.
#[derive(Debug, Clone, PartialEq)]
struct ResolvedMonitor {
    name: String,
    x: i64,
    y: i64,
    width: i64,
    height: i64,
    disabled: bool,
}

/// A kert elrendezes ellenorzese az elo kijelzok ismereteben.
///
/// Ez a kapu all a sotet kepernyo elott: ami ezen atmegy, azt mar alkalmazzuk.
/// Az egyes mezoket a Hyprland is ellenorzi, de a *kapcsolatukat* nem: hogy
/// marad-e bekapcsolt kijelzo, es hogy nem fedik-e egymast.
fn validate_layout(requested: &[MonitorSetting], live: &[LiveMonitor]) -> Result<(), ModuleError> {
    let mut seen = BTreeSet::new();

    for setting in requested {
        let output = setting.output.trim();
        if output.is_empty() {
            return Err(ModuleError::invalid_params("ures 'output' a listaban"));
        }
        if !seen.insert(output.to_string()) {
            return Err(ModuleError::invalid_params(format!(
                "a(z) {output} ketszer szerepel a listaban"
            )));
        }
        let Some(monitor) = live.iter().find(|item| item.name == output) else {
            return Err(ModuleError::not_found(format!("nincs ilyen kijelzo: {output}")));
        };

        // Egy kikapcsolt kijelzonek nincs modja, pozicioja vagy skalaja.
        if setting.disabled {
            continue;
        }
        if let Some(mode) = &setting.mode {
            validate_mode(mode, monitor)?;
        }
        if let Some(position) = &setting.position {
            validate_position(position)?;
        }
        if let Some(scale) = setting.scale
            && !(MIN_SCALE..=MAX_SCALE).contains(&scale)
        {
            return Err(ModuleError::invalid_params(format!(
                "a skala {MIN_SCALE} es {MAX_SCALE} kozott lehet, nem {scale}"
            )));
        }
        if let Some(transform) = setting.transform
            && transform > 7
        {
            return Err(ModuleError::invalid_params(format!(
                "a transform 0 es 7 kozott lehet, nem {transform}"
            )));
        }
        if let Some(vrr) = setting.vrr
            && vrr > 2
        {
            return Err(ModuleError::invalid_params(format!("a vrr 0, 1 vagy 2 lehet, nem {vrr}")));
        }
    }

    let layout = resolve_layout(requested, live);
    if !layout.iter().any(|item| !item.disabled) {
        return Err(ModuleError::invalid_params(
            "legalabb egy kijelzonek bekapcsolva kell maradnia",
        ));
    }
    if let Some((first, second)) = first_overlap(&layout) {
        return Err(ModuleError::invalid_params(format!(
            "a(z) {first} es a(z) {second} atfedne egymast; huzd oket szet"
        )));
    }

    Ok(())
}

fn validate_mode(mode: &str, monitor: &LiveMonitor) -> Result<(), ModuleError> {
    let mode = mode.trim();
    if matches!(mode, "preferred" | "highres" | "highrr" | "auto" | "") {
        return Ok(());
    }

    let (size, rate) = match mode.split_once('@') {
        Some((size, rate)) => (size, Some(rate)),
        None => (mode, None),
    };
    let Some((width, height)) = parse_size(size) else {
        return Err(ModuleError::invalid_params(format!("ertelmezhetetlen mod: {mode}")));
    };
    if let Some(rate) = rate {
        let rate = rate.trim().trim_end_matches("Hz").trim();
        match rate.parse::<f64>() {
            Ok(hertz) if hertz > 0.0 => {}
            _ => {
                return Err(ModuleError::invalid_params(format!(
                    "ertelmezhetetlen frissitesi rata: {mode}"
                )));
            }
        }
    }

    // Csak a felbontast vetjuk ossze a panel listajaval. A frissitesi rata
    // kerekitese kliensenkent elter (59.95 vs 60), a nem tamogatott felbontas
    // viszont pont az a hiba, ami sotet kepernyot hagy.
    if !monitor.available_modes.is_empty()
        && !monitor.available_modes.iter().any(|available| {
            available.split('@').next().map(parse_size) == Some(Some((width, height)))
        })
    {
        return Err(ModuleError::invalid_params(format!(
            "a(z) {} nem tamogatja a {width}x{height} felbontast",
            monitor.name
        )));
    }

    Ok(())
}

fn validate_position(position: &str) -> Result<(), ModuleError> {
    let position = position.trim();
    // A Hyprland sajat elhelyezo kulcsszavai (`auto`, `auto-right`, ...).
    if position.is_empty() || position.starts_with("auto") {
        return Ok(());
    }
    match parse_point(position) {
        Some(_) => Ok(()),
        None => Err(ModuleError::invalid_params(format!("ertelmezhetetlen pozicio: {position}"))),
    }
}

fn parse_size(value: &str) -> Option<(i64, i64)> {
    let (width, height) = value.trim().split_once('x')?;
    let width = width.trim().parse::<i64>().ok()?;
    let height = height.trim().parse::<i64>().ok()?;
    (width > 0 && height > 0).then_some((width, height))
}

fn parse_point(value: &str) -> Option<(i64, i64)> {
    let value = value.trim();
    // A negativ x-koordinata miatt nem az elso 'x'-nel vagunk, hanem az elso
    // olyannal, ami nem a szam elojele utan all.
    let split = value.char_indices().skip(1).find(|(_, ch)| *ch == 'x')?.0;
    let x = value[..split].trim().parse::<i64>().ok()?;
    let y = value[split + 1..].trim().parse::<i64>().ok()?;
    Some((x, y))
}

/// A kert modositasokat rateritjuk az elo allapotra, es kiszamoljuk, hova
/// kerulnek a kijelzok logikai pixelben.
fn resolve_layout(requested: &[MonitorSetting], live: &[LiveMonitor]) -> Vec<ResolvedMonitor> {
    live.iter()
        .map(|monitor| {
            let setting = requested.iter().find(|item| item.output.trim() == monitor.name);
            let disabled = setting.map(|item| item.disabled).unwrap_or(monitor.disabled);

            let (width, height) = setting
                .and_then(|item| item.mode.as_deref())
                .and_then(|mode| parse_size(mode.split('@').next().unwrap_or(mode)))
                .unwrap_or((monitor.width, monitor.height));
            let (x, y) = setting
                .and_then(|item| item.position.as_deref())
                .and_then(parse_point)
                .unwrap_or((monitor.x, monitor.y));

            let scale =
                setting.and_then(|item| item.scale).unwrap_or(monitor.scale).max(f64::MIN_POSITIVE);
            let transform = setting.and_then(|item| item.transform).unwrap_or(monitor.transform);

            let mut logical_width = (width as f64 / scale).round() as i64;
            let mut logical_height = (height as f64 / scale).round() as i64;
            // A paratlan transformok (90 es 270 fok) megforditjak az oldalakat.
            if transform % 2 == 1 {
                std::mem::swap(&mut logical_width, &mut logical_height);
            }

            ResolvedMonitor {
                name: monitor.name.clone(),
                x,
                y,
                width: logical_width,
                height: logical_height,
                disabled,
            }
        })
        .collect()
}

/// Az elso atfedo par, ha van. Egy pixelnyi erintkezest nem szamitunk
/// atfedesnek: a kerekites ennyit hozhat.
fn first_overlap(layout: &[ResolvedMonitor]) -> Option<(String, String)> {
    let active: Vec<&ResolvedMonitor> =
        layout.iter().filter(|item| !item.disabled && item.width > 0 && item.height > 0).collect();

    for (index, first) in active.iter().enumerate() {
        for second in active.iter().skip(index + 1) {
            let horizontal =
                (first.x + first.width).min(second.x + second.width) - first.x.max(second.x);
            let vertical =
                (first.y + first.height).min(second.y + second.height) - first.y.max(second.y);
            if horizontal > 1 && vertical > 1 {
                return Some((first.name.clone(), second.name.clone()));
            }
        }
    }
    None
}

// -- olvasas -----------------------------------------------------------------

/// A csatlakoztatott kijelzok, a kikapcsoltakat is beleertve, EDID-azonositoval
/// kiegeszitve. Az EDID azert kell, mert a connector nevek nem stabilak --
/// ugyanaz az indoklas, mint az SDDM greeternel (`crate::edid`).
fn monitors() -> Value {
    let Ok(text) = hyprctl(&["-j", "monitors", "all"]) else {
        return Value::Array(Vec::new());
    };
    let Ok(Value::Array(mut list)) = serde_json::from_str::<Value>(&text) else {
        return Value::Array(Vec::new());
    };

    for monitor in &mut list {
        let Some(object) = monitor.as_object_mut() else {
            continue;
        };
        let Some(name) = object.get("name").and_then(Value::as_str).map(str::to_string) else {
            continue;
        };
        if let Some(identity) = edid::identity_for_connector(&name) {
            object.insert(
                "edid".into(),
                json!({
                    "manufacturer": identity.manufacturer,
                    "model": identity.model,
                    "serial": identity.serial,
                }),
            );
        }
    }

    Value::Array(list)
}

/// Egyetlen `hyprctl --batch` hivas az osszes ismert kulcsra. Kulon
/// folyamatonkent futtatva ez huszonket process lenne minden megnyitaskor.
fn read_options() -> Value {
    let query =
        OPTION_KEYS.iter().map(|key| format!("getoption {key}")).collect::<Vec<_>>().join(" ; ");

    let mut values = Map::new();
    let Ok(text) = hyprctl(&["-j", "--batch", &query]) else {
        return Value::Object(values);
    };

    for line in text.lines() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let Ok(Value::Object(reply)) = serde_json::from_str::<Value>(line) else {
            continue;
        };
        let Some(key) = reply.get("option").and_then(Value::as_str) else {
            continue;
        };
        if let Some(value) = normalize_option(&reply) {
            values.insert(key.to_string(), value);
        }
    }

    Value::Object(values)
}

/// A `getoption` valasza tipusfuggo mezoben hozza az erteket. A `css` forma
/// ("5 5 5 5") egyetlen szamma esik ossze, ha minden oldal egyforma -- a
/// settings app egy csuszkat mutat, nem negyet.
fn normalize_option(reply: &Map<String, Value>) -> Option<Value> {
    if let Some(value) = reply.get("bool") {
        return Some(value.clone());
    }
    if let Some(value) = reply.get("int") {
        return Some(value.clone());
    }
    if let Some(value) = reply.get("float") {
        return Some(value.clone());
    }
    if let Some(value) = reply.get("str").or_else(|| reply.get("custom")) {
        return Some(value.clone());
    }

    let css = reply.get("css")?.as_str()?;
    let parts: Vec<&str> = css.split_whitespace().collect();
    if !parts.is_empty()
        && parts.iter().all(|part| *part == parts[0])
        && let Ok(number) = parts[0].parse::<f64>()
    {
        return Some(json!(number));
    }
    Some(json!(css))
}

// -- hyprctl -----------------------------------------------------------------

fn hyprctl(args: &[&str]) -> Result<String> {
    // Idokorlattal: ez a hivas a modul modositasi zarat tartja, es egy beragadt
    // hyprctl kulonben minden tovabbi kijelzomuveletet befagyasztana.
    let output = crate::proc::run("hyprctl", args, crate::proc::SHORT)?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
        return Err(ModuleError::failed(if stderr.is_empty() {
            "a hyprctl hibaval tert vissza".to_string()
        } else {
            stderr
        })
        .into());
    }

    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

// -- Lua rendereles ----------------------------------------------------------

const HEADER: &str = "-- Generated by vellum_shell. Do not edit: use the Vellum settings app.\n";

fn render_display_lua(monitors: &[MonitorSetting]) -> String {
    let mut out = String::from(HEADER);
    for setting in monitors {
        out.push('\n');
        out.push_str(&render_monitor_lua(setting));
    }

    out
}

/// Egyetlen monitor Lua API-hivasa. Ugyanezt kuldjuk az elo compositornak es
/// tesszuk a generalt modulba, igy a ket utvonal nem tud elterni egymastol.
fn render_monitor_lua(setting: &MonitorSetting) -> String {
    let mut out = String::from("hl.monitor({\n");
    out.push_str(&format!("    output = {},\n", lua_string(&setting.output)));
    if setting.disabled {
        out.push_str("    disabled = true,\n");
    } else {
        if let Some(mode) = &setting.mode {
            out.push_str(&format!("    mode = {},\n", lua_string(mode)));
        }
        if let Some(position) = &setting.position {
            out.push_str(&format!("    position = {},\n", lua_string(position)));
        }
        if let Some(scale) = setting.scale {
            out.push_str(&format!("    scale = {},\n", format_number(scale)));
        }
        if let Some(transform) = setting.transform {
            out.push_str(&format!("    transform = {transform},\n"));
        }
        if let Some(vrr) = setting.vrr {
            out.push_str(&format!("    vrr = {vrr},\n"));
        }
    }
    out.push_str("})\n");
    out
}

/// A lapos `general:gaps_in` kulcsokbol egy beagyazott `hl.config` tabla lesz.
/// A `BTreeMap` rendezettsege teszi a kimenetet determinisztikussa.
fn render_tuning_lua(options: &BTreeMap<String, Value>) -> String {
    let mut out = String::from(HEADER);
    out.push('\n');
    out.push_str(SETTINGS_WINDOW_RULE);
    out.push_str(&render_options_lua(options));
    out
}

/// Egyetlen `hl.config` hivas a megadott opciokbol. Fejlec nelkul az elo
/// `hyprctl eval` hivasnak is kozvetlenul atadhato.
fn render_options_lua(options: &BTreeMap<String, Value>) -> String {
    if options.is_empty() {
        return String::new();
    }

    let mut tree = Node::default();
    for (key, value) in options {
        tree.insert(&key.split(':').collect::<Vec<_>>(), value.clone());
    }

    let mut out = String::from("\nhl.config({\n");
    tree.render(&mut out, 1);
    out.push_str("})\n");
    out
}

/// Egy Lua tabla faja. Egy kulcs vagy levelerteket, vagy egy alfat tart.
#[derive(Default)]
struct Node {
    leaves: BTreeMap<String, Value>,
    children: BTreeMap<String, Node>,
}

impl Node {
    fn insert(&mut self, path: &[&str], value: Value) {
        match path {
            [] => {}
            [last] => {
                self.leaves.insert((*last).to_string(), value);
            }
            [head, rest @ ..] => {
                self.children.entry((*head).to_string()).or_default().insert(rest, value);
            }
        }
    }

    fn render(&self, out: &mut String, depth: usize) {
        let pad = "    ".repeat(depth);
        for (key, value) in &self.leaves {
            out.push_str(&format!("{pad}{} = {},\n", lua_key(key), lua_value(value)));
        }
        for (key, child) in &self.children {
            out.push_str(&format!("{pad}{} = {{\n", lua_key(key)));
            child.render(out, depth + 1);
            out.push_str(&format!("{pad}}},\n"));
        }
    }
}

/// A `tap-to-click`-hez hasonlo kulcsok nem ervenyes Lua azonositok.
fn lua_key(key: &str) -> String {
    let identifier = !key.is_empty()
        && !key.starts_with(|ch: char| ch.is_ascii_digit())
        && key.chars().all(|ch| ch.is_ascii_alphanumeric() || ch == '_');

    if identifier { key.to_string() } else { format!("[{}]", lua_string(key)) }
}

fn lua_value(value: &Value) -> String {
    match value {
        Value::Bool(flag) => flag.to_string(),
        Value::Number(number) => number.to_string(),
        Value::String(text) => lua_string(text),
        other => lua_string(&other.to_string()),
    }
}

fn lua_string(value: &str) -> String {
    let escaped = value.replace('\\', "\\\\").replace('"', "\\\"");
    format!("\"{escaped}\"")
}

/// Egesz ertekeket `1`-kent irunk ki, nem `1.0`-kent: a Hyprland skala mezoje
/// mindkettot elfogadja, de a konfig igy olvashatobb marad.
fn format_number(value: f64) -> String {
    if value.fract() == 0.0 && value.abs() < 1e9 {
        format!("{}", value as i64)
    } else {
        format!("{value}")
    }
}

// -- esemenyfigyeles ---------------------------------------------------------

fn event_socket_path() -> Option<std::path::PathBuf> {
    let runtime = std::env::var_os("XDG_RUNTIME_DIR")?;
    let signature = std::env::var_os("HYPRLAND_INSTANCE_SIGNATURE")?;
    let dir = std::path::PathBuf::from(runtime).join("hypr").join(signature);
    let path = dir.join(".socket2.sock");
    path.exists().then_some(path)
}

/// A monitor- es konfigvaltozasokra uj snapshotot tolunk. Az esemenyek
/// csomagban erkeznek (egy `hyprctl reload` tobb sort is kivalt), ezert a
/// snapshotot rovid csenddel varjuk meg.
async fn watch_events(path: &std::path::Path, sink: &StateSink) -> Result<()> {
    use tokio::io::{AsyncBufReadExt, BufReader};

    let stream = tokio::net::UnixStream::connect(path).await?;
    let mut lines = BufReader::new(stream).lines();

    loop {
        let mut dirty = false;

        loop {
            let next = if dirty {
                match tokio::time::timeout(Duration::from_millis(250), lines.next_line()).await {
                    Ok(result) => result?,
                    Err(_) => break,
                }
            } else {
                lines.next_line().await?
            };

            let Some(line) = next else {
                return Ok(());
            };
            let event = line.split_once(">>").map(|(name, _)| name).unwrap_or(&line);
            if matches!(
                event,
                "monitoradded"
                    | "monitoraddedv2"
                    | "configreloaded"
                    | "monitorremoved"
                    | "monitorremovedv2"
            ) {
                dirty = true;
            }
        }

        sink.push(tokio::task::spawn_blocking(Hypr::snapshot).await?);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn options(pairs: &[(&str, Value)]) -> BTreeMap<String, Value> {
        pairs.iter().map(|(key, value)| ((*key).to_string(), value.clone())).collect()
    }

    #[test]
    fn empty_store_still_renders_a_valid_module() {
        assert_eq!(render_display_lua(&[]), HEADER);
        let tuning = render_tuning_lua(&BTreeMap::new());
        assert!(tuning.starts_with(HEADER));
        assert!(tuning.contains("name = \"vellum-settings\""));
        assert!(tuning.contains("float = true"));
    }

    #[test]
    fn nested_keys_become_nested_tables() {
        let rendered = render_tuning_lua(&options(&[
            ("general:gaps_in", json!(8)),
            ("decoration:blur:enabled", json!(true)),
            ("decoration:rounding", json!(6)),
            ("input:touchpad:tap-to-click", json!(false)),
        ]));

        assert_eq!(
            rendered,
            format!(
                "{HEADER}\n{SETTINGS_WINDOW_RULE}\nhl.config({{\n    \
                 decoration = {{\n        rounding = 6,\n        blur = {{\n            \
                 enabled = true,\n        }},\n    }},\n    \
                 general = {{\n        gaps_in = 8,\n    }},\n    \
                 input = {{\n        touchpad = {{\n            \
                 [\"tap-to-click\"] = false,\n        }},\n    }},\n}})\n"
            )
        );
    }

    #[test]
    fn monitor_module_omits_unset_fields() {
        let rendered = render_display_lua(&[MonitorSetting {
            output: "DP-2".into(),
            mode: Some("1920x1080@60".into()),
            position: Some("0x0".into()),
            scale: Some(1.0),
            ..MonitorSetting::default()
        }]);

        assert_eq!(
            rendered,
            format!(
                "{HEADER}\nhl.monitor({{\n    output = \"DP-2\",\n    \
                 mode = \"1920x1080@60\",\n    position = \"0x0\",\n    scale = 1,\n}})\n"
            )
        );
    }

    #[test]
    fn disabled_monitor_drops_the_mode() {
        let rendered = render_display_lua(&[MonitorSetting {
            output: "HDMI-A-1".into(),
            mode: Some("1920x1080@144".into()),
            disabled: true,
            ..MonitorSetting::default()
        }]);

        assert!(rendered.contains("disabled = true"));
        assert!(!rendered.contains("mode"));
    }

    #[test]
    fn live_monitor_code_uses_the_native_lua_api() {
        let setting = MonitorSetting {
            output: "HDMI-A-1".into(),
            mode: Some("1920x1080@144".into()),
            position: Some("1920x0".into()),
            scale: Some(1.5),
            vrr: Some(1),
            ..MonitorSetting::default()
        };
        assert_eq!(
            render_monitor_lua(&setting),
            "hl.monitor({\n    output = \"HDMI-A-1\",\n    mode = \"1920x1080@144\",\n    position = \"1920x0\",\n    scale = 1.5,\n    vrr = 1,\n})\n"
        );

        let unset = MonitorSetting { output: "DP-1".into(), ..MonitorSetting::default() };
        assert_eq!(render_monitor_lua(&unset), "hl.monitor({\n    output = \"DP-1\",\n})\n");

        let off = MonitorSetting { output: "DP-1".into(), disabled: true, ..Default::default() };
        assert_eq!(
            render_monitor_lua(&off),
            "hl.monitor({\n    output = \"DP-1\",\n    disabled = true,\n})\n"
        );
    }

    #[test]
    fn live_options_code_uses_the_native_lua_api_without_a_file_header() {
        assert_eq!(
            render_options_lua(&options(&[("general:gaps_out", json!(24))])),
            "\nhl.config({\n    general = {\n        gaps_out = 24,\n    },\n})\n"
        );
        assert_eq!(render_options_lua(&BTreeMap::new()), "");
    }

    #[test]
    fn css_gaps_collapse_to_one_number() {
        let four_sided: Map<String, Value> =
            serde_json::from_value(json!({ "css": "5 5 5 5" })).unwrap();
        assert_eq!(normalize_option(&four_sided), Some(json!(5.0)));

        let uneven: Map<String, Value> =
            serde_json::from_value(json!({ "css": "5 10 5 10" })).unwrap();
        assert_eq!(normalize_option(&uneven), Some(json!("5 10 5 10")));

        let integer: Map<String, Value> = serde_json::from_value(json!({ "int": 2 })).unwrap();
        assert_eq!(normalize_option(&integer), Some(json!(2)));

        // A boolok sajat mezoben jonnek, es a Hyprland `int`-et is kuld melle.
        let flag: Map<String, Value> =
            serde_json::from_value(json!({ "bool": true, "int": 1 })).unwrap();
        assert_eq!(normalize_option(&flag), Some(json!(true)));
    }

    #[test]
    fn upsert_replaces_the_same_output() {
        let mut store = Store::default();
        store.upsert_monitor(MonitorSetting { output: "DP-2".into(), ..Default::default() });
        store.upsert_monitor(MonitorSetting {
            output: "DP-2".into(),
            scale: Some(2.0),
            ..Default::default()
        });
        store.upsert_monitor(MonitorSetting { output: "DP-3".into(), ..Default::default() });

        assert_eq!(store.monitors.len(), 2);
        assert_eq!(store.monitors[0].scale, Some(2.0));
    }

    fn live(name: &str, width: i64, height: i64, x: i64, y: i64) -> LiveMonitor {
        LiveMonitor {
            name: name.into(),
            width,
            height,
            refresh_rate: 60.0,
            x,
            y,
            scale: 1.0,
            transform: 0,
            vrr: Some(0),
            disabled: false,
            available_modes: vec![format!("{width}x{height}@60.00Hz"), "1280x720@60.00Hz".into()],
        }
    }

    fn setting(output: &str) -> MonitorSetting {
        MonitorSetting { output: output.into(), ..MonitorSetting::default() }
    }

    #[test]
    fn a_side_by_side_layout_is_accepted() {
        let live = vec![live("DP-1", 1920, 1080, 0, 0), live("HDMI-A-1", 1920, 1080, 1920, 0)];
        let requested = vec![MonitorSetting {
            position: Some("1920x0".into()),
            mode: Some("1920x1080@60".into()),
            ..setting("HDMI-A-1")
        }];
        assert!(validate_layout(&requested, &live).is_ok());
    }

    #[test]
    fn an_unknown_output_is_rejected() {
        let live = vec![live("DP-1", 1920, 1080, 0, 0)];
        let err = validate_layout(&[setting("DP-9")], &live).unwrap_err();
        assert_eq!(err.code(), "not_found");
    }

    #[test]
    fn the_same_output_cannot_appear_twice() {
        let live = vec![live("DP-1", 1920, 1080, 0, 0)];
        let err = validate_layout(&[setting("DP-1"), setting("DP-1")], &live).unwrap_err();
        assert_eq!(err.code(), "invalid_params");
    }

    #[test]
    fn the_last_display_cannot_be_switched_off() {
        let live = vec![live("DP-1", 1920, 1080, 0, 0), live("HDMI-A-1", 1920, 1080, 1920, 0)];

        let one_off = vec![MonitorSetting { disabled: true, ..setting("DP-1") }];
        assert!(validate_layout(&one_off, &live).is_ok());

        let all_off = vec![
            MonitorSetting { disabled: true, ..setting("DP-1") },
            MonitorSetting { disabled: true, ..setting("HDMI-A-1") },
        ];
        let err = validate_layout(&all_off, &live).unwrap_err();
        assert_eq!(err.code(), "invalid_params");
        assert!(err.to_string().contains("bekapcsolva"));
    }

    #[test]
    fn overlapping_displays_are_rejected() {
        let live = vec![live("DP-1", 1920, 1080, 0, 0), live("HDMI-A-1", 1920, 1080, 1920, 0)];
        let requested =
            vec![MonitorSetting { position: Some("960x0".into()), ..setting("HDMI-A-1") }];

        let err = validate_layout(&requested, &live).unwrap_err();
        assert!(err.to_string().contains("atfedne"), "{err}");

        // Egy pixelnyi erintkezes meg nem atfedes: a skalazas kerekitese ennyit hozhat.
        let touching =
            vec![MonitorSetting { position: Some("1919x0".into()), ..setting("HDMI-A-1") }];
        assert!(validate_layout(&touching, &live).is_ok());
    }

    #[test]
    fn a_scaled_display_frees_up_the_space_it_no_longer_uses() {
        // 1920 logikai szelesseg 1.5-os skalan 1280: ami korabban atfedett
        // volna, az igy elfer.
        let live = vec![live("DP-1", 1920, 1080, 0, 0), live("HDMI-A-1", 1920, 1080, 1920, 0)];
        let requested = vec![
            MonitorSetting { scale: Some(1.5), ..setting("DP-1") },
            MonitorSetting { position: Some("1280x0".into()), ..setting("HDMI-A-1") },
        ];
        assert!(validate_layout(&requested, &live).is_ok());
    }

    #[test]
    fn a_rotated_display_is_measured_on_its_side() {
        let live = vec![live("DP-1", 1920, 1080, 0, 0)];
        let layout =
            resolve_layout(&[MonitorSetting { transform: Some(1), ..setting("DP-1") }], &live);
        assert_eq!(layout[0].width, 1080);
        assert_eq!(layout[0].height, 1920);
    }

    #[test]
    fn an_unsupported_resolution_is_rejected() {
        let live = vec![live("DP-1", 1920, 1080, 0, 0)];

        let bad = vec![MonitorSetting { mode: Some("3840x2160@60".into()), ..setting("DP-1") }];
        let err = validate_layout(&bad, &live).unwrap_err();
        assert!(err.to_string().contains("felbontast"), "{err}");

        // A rata kerekitese nem szamit, a felbontas igen.
        let good = vec![MonitorSetting { mode: Some("1280x720@59".into()), ..setting("DP-1") }];
        assert!(validate_layout(&good, &live).is_ok());

        let garbage = vec![MonitorSetting { mode: Some("nonsense".into()), ..setting("DP-1") }];
        assert!(validate_layout(&garbage, &live).is_err());
    }

    #[test]
    fn out_of_range_values_are_rejected() {
        let live = vec![live("DP-1", 1920, 1080, 0, 0)];
        for bad in [
            MonitorSetting { scale: Some(0.01), ..setting("DP-1") },
            MonitorSetting { scale: Some(12.0), ..setting("DP-1") },
            MonitorSetting { transform: Some(9), ..setting("DP-1") },
            MonitorSetting { vrr: Some(5), ..setting("DP-1") },
            MonitorSetting { position: Some("kozepre".into()), ..setting("DP-1") },
        ] {
            let err = validate_layout(std::slice::from_ref(&bad), &live).unwrap_err();
            assert_eq!(err.code(), "invalid_params", "{bad:?}");
        }
    }

    #[test]
    fn a_disabled_display_skips_the_field_checks() {
        // Kikapcsolva a mod es a pozicio nem szamit -- azokat ugysem irjuk ki.
        let live = vec![live("DP-1", 1920, 1080, 0, 0), live("HDMI-A-1", 1920, 1080, 1920, 0)];
        let requested = vec![MonitorSetting {
            mode: Some("9999x9999@60".into()),
            disabled: true,
            ..setting("DP-1")
        }];
        assert!(validate_layout(&requested, &live).is_ok());
    }

    #[test]
    fn negative_positions_parse() {
        assert_eq!(parse_point("-1920x0"), Some((-1920, 0)));
        assert_eq!(parse_point("1920x-1080"), Some((1920, -1080)));
        assert_eq!(parse_point("0x0"), Some((0, 0)));
        assert_eq!(parse_point("x0"), None);
        assert_eq!(parse_point("auto"), None);
    }

    #[test]
    fn the_live_snapshot_is_fully_specified() {
        // A visszaallitasnak nem szabad a Hyprland alapertelmezesere biznia
        // magat: minden mezot kiirunk.
        let restored = snapshot_settings(&[live("DP-1", 1920, 1080, 0, 0)]);
        assert_eq!(restored[0].mode.as_deref(), Some("1920x1080@60"));
        assert_eq!(restored[0].position.as_deref(), Some("0x0"));
        assert_eq!(restored[0].scale, Some(1.0));
        assert_eq!(restored[0].transform, Some(0));
        assert_eq!(restored[0].vrr, Some(0));
        assert!(!restored[0].disabled);
    }

    #[test]
    fn a_live_monitor_survives_a_sparse_hyprctl_reply() {
        let parsed = LiveMonitor::from_value(&json!({ "name": "DP-1" })).unwrap();
        assert_eq!(parsed.name, "DP-1");
        assert_eq!(parsed.scale, 1.0);
        assert!(parsed.available_modes.is_empty());
        assert!(LiveMonitor::from_value(&json!({ "width": 1920 })).is_none());
    }

    #[test]
    fn quoted_values_survive_a_round_trip() {
        assert_eq!(lua_string("a\"b\\c"), "\"a\\\"b\\\\c\"");
        assert_eq!(lua_key("gaps_in"), "gaps_in");
        assert_eq!(lua_key("tap-to-click"), "[\"tap-to-click\"]");
    }
}

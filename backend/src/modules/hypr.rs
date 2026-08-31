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
use std::collections::BTreeMap;
use std::sync::Arc;
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

pub struct Hypr;

impl Hypr {
    pub fn new() -> Self {
        Self
    }

    fn snapshot() -> Value {
        json!({
            "available": hyprctl(&["version"]).is_ok(),
            "monitors": monitors(),
            "options": read_options(),
        })
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

                let applied = tokio::task::spawn_blocking(move || set_options(values)).await??;
                sink.push(tokio::task::spawn_blocking(Hypr::snapshot).await?);
                Ok(applied)
            }

            "setMonitors" => {
                let raw = params
                    .get("monitors")
                    .cloned()
                    .ok_or_else(|| ModuleError::invalid_params("hianyzik a 'monitors' tomb"))?;
                let monitors: Vec<MonitorSetting> = serde_json::from_value(raw)
                    .map_err(|err| ModuleError::invalid_params(err.to_string()))?;

                if monitors.iter().any(|item| item.output.trim().is_empty()) {
                    return Err(ModuleError::invalid_params("ures 'output' a listaban").into());
                }

                let applied = tokio::task::spawn_blocking(move || set_monitors(monitors)).await??;
                sink.push(tokio::task::spawn_blocking(Hypr::snapshot).await?);
                Ok(applied)
            }

            "reset" => {
                let scope = params
                    .get("scope")
                    .and_then(Value::as_str)
                    .ok_or_else(|| ModuleError::invalid_params("hianyzik a 'scope'"))?
                    .to_string();

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

fn set_monitors(monitors: Vec<MonitorSetting>) -> Result<Value> {
    let mut store = Store::load();

    for setting in monitors {
        let live_code = render_monitor_lua(&setting);
        if let Err(err) = hyprctl(&["eval", &live_code]) {
            tracing::warn!(%err, output = setting.output, "a monitor nem allithato eloben");
        }
        store.upsert_monitor(setting);
    }

    store.render()?;
    store.save()?;
    Ok(json!({ "monitors": store.monitors }))
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
    let output = std::process::Command::new("hyprctl")
        .args(args)
        .output()
        .context("a hyprctl nem futtathato")?;

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

    #[test]
    fn quoted_values_survive_a_round_trip() {
        assert_eq!(lua_string("a\"b\\c"), "\"a\\\"b\\\\c\"");
        assert_eq!(lua_key("gaps_in"), "gaps_in");
        assert_eq!(lua_key("tap-to-click"), "[\"tap-to-click\"]");
    }
}

//! NetworkManager titokkero (secret agent).
//!
//! A NetworkManager nem kerdez jelszot magatol: egy regisztralt "secret
//! agent"-et hiv meg, amikor egy kapcsolathoz titok kell (uj vagy elutasitott
//! Wi-Fi jelszo, 802.1X, PPPoE). Eddig ezt az `nm-applet` vegezte, a sajat
//! GTK ablakaival es egy masodik halozati ikonnal a trayben. Ez a modul
//! ugyanazt a D-Bus feluletet adja, a kerdest pedig a `netsecrets` topicon
//! a shellnek tovabbitja, ami sajat dialogusban kerdez.
//!
//! Eletciklus: a topic lazy, igy az agent csak addig van regisztralva, amig a
//! shell feliratkozik. Ha a shell nem fut (vagy osszeomlik), a sajat
//! rendszerbusz-kapcsolatunk bezarul, a NetworkManager elfelejti az agentet, es
//! egy masik agent (nm-applet, `nmcli --ask`) veheti at a kerdest. A
//! NetworkManager ujraindulasat a `NameOwnerChanged` jelbol vesszuk eszre, es
//! ujra regisztralunk.
//!
//! Biztonsag: a `GetSecrets` titkot ad ki (a kulcstarbol) es jelszoablakot
//! nyit, ezert csak a NetworkManager aktualis busz-nevetol fogadjuk el. Egy
//! masik folyamat nem kerheti el a mentett jelszavakat es nem nyithat hamis
//! jelszokerest.
//!
//! A kulcstar-attributumok (`connection-uuid`, `setting-name`, `setting-key`)
//! megegyeznek az nm-applet es a libnm attributumaival, igy a korabban ott
//! mentett "csak ehhez a felhasznalohoz" jelszavak is megmaradnak.
//!
//! VPN-plugin titkokat (OpenVPN, stb.) nem kezelunk: azokhoz a plugin sajat
//! auth-dialogja kell. Ilyenkor `NoSecrets`-szel valaszolunk, hogy a
//! NetworkManager a kovetkezo agenthez forduljon.

use crate::module::{MethodDescription, Module, ModuleDescription, ModuleError, StateSink};
use crate::nm;
use crate::secret;
use anyhow::{Result, anyhow};
use async_trait::async_trait;
use futures_util::StreamExt;
use serde::Serialize;
use serde_json::{Value, json};
use std::collections::HashMap;
use std::sync::{Arc, Mutex, MutexGuard};
use std::time::Duration;
use tokio::sync::oneshot;
use zbus::message::Header;
use zbus::zvariant::{OwnedObjectPath, OwnedValue};

/// `a{sa{sv}}`: beallitas neve -> kulcs -> ertek.
type Settings = HashMap<String, HashMap<String, OwnedValue>>;

const NM_SERVICE: &str = "org.freedesktop.NetworkManager";
const AGENT_PATH: &str = "/org/freedesktop/NetworkManager/SecretAgent";
/// Felhasznalonkent egy agent hasznalhatja ugyanazt az azonositot.
const AGENT_ID: &str = "org.vellumshell.SecretAgent";
const KEYRING_SCHEMA: &str = "org.freedesktop.NetworkManager.Connection";

/// Ennyit varunk a felhasznalora. A NetworkManager sajat idokorlatja (120 s)
/// alatt maradunk, hogy a valaszunk meg erjen valamit.
const PROMPT_TIMEOUT: Duration = Duration::from_secs(110);

/// `GetSecrets` jelzok.
const ALLOW_INTERACTION: u32 = 0x1;
const REQUEST_NEW: u32 = 0x2;

/// Titok-jelzok (`<kulcs>-flags`).
const AGENT_OWNED: u32 = 0x1;
const NOT_SAVED: u32 = 0x2;
const NOT_REQUIRED: u32 = 0x4;

#[derive(Debug, zbus::DBusError)]
#[zbus(prefix = "org.freedesktop.NetworkManager.SecretAgent")]
enum AgentError {
    #[zbus(error)]
    ZBus(zbus::Error),
    PermissionDenied(String),
    UserCanceled(String),
    AgentCanceled(String),
    NoSecrets(String),
}

/// Egy bekerendo titok.
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
struct Field {
    key: String,
    label: String,
    #[serde(skip)]
    flags: u32,
}

/// Mit kell bekerni egy `GetSecrets` keresre. D-Bus nelkuli, tesztelheto.
#[derive(Debug, Clone, PartialEq)]
struct Plan {
    /// "wifi" | "wep" | "leap" | "8021x" | "8021x-tls" | "pppoe"
    kind: &'static str,
    fields: Vec<Field>,
}

/// Ami a dialogusba kerul. Titkot sosem tartalmaz.
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
struct Prompt {
    id: u64,
    kind: &'static str,
    /// A kapcsolat neve a NetworkManagerben.
    connection: String,
    /// Vezetek nelkuli halozatnal az SSID, egyebkent ures.
    ssid: String,
    /// 802.1X felhasznalonev, ha a profil tartalmaz ilyet.
    identity: String,
    /// A NetworkManager uj titkot ker: az elozot elutasitotta a halozat.
    retry: bool,
    fields: Vec<Field>,
}

enum Answer {
    Secrets(HashMap<String, String>),
    UserCanceled,
    AgentCanceled,
}

struct Pending {
    prompt: Prompt,
    connection_path: String,
    setting_name: String,
    reply: oneshot::Sender<Answer>,
}

#[derive(Default)]
struct Queue {
    next_id: u64,
    pending: Vec<Pending>,
    registered: bool,
}

pub struct NetSecrets {
    queue: Mutex<Queue>,
}

impl Default for NetSecrets {
    fn default() -> Self {
        Self::new()
    }
}

impl NetSecrets {
    pub fn new() -> Self {
        Self { queue: Mutex::new(Queue::default()) }
    }

    fn queue(&self) -> MutexGuard<'_, Queue> {
        self.queue.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
    }

    fn publish(&self, sink: &StateSink) {
        let (registered, request, queued) = {
            let queue = self.queue();
            (
                queue.registered,
                queue.pending.first().map(|pending| pending.prompt.clone()),
                queue.pending.len(),
            )
        };
        sink.push(json!({
            "available": true,
            "registered": registered,
            "request": request,
            "queued": queued,
        }));
    }

    fn set_registered(&self, registered: bool, sink: &StateSink) {
        self.queue().registered = registered;
        self.publish(sink);
    }

    /// Kiveszi a kerest a sorbol; `None`, ha mar nincs benne.
    fn take(&self, id: u64) -> Option<Pending> {
        let mut queue = self.queue();
        let index = queue.pending.iter().position(|pending| pending.prompt.id == id)?;
        Some(queue.pending.remove(index))
    }

    /// Feltesszi a kerdest a shellnek, es megvarja a valaszt.
    async fn ask(
        self: &Arc<Self>,
        sink: &StateSink,
        mut prompt: Prompt,
        connection_path: String,
        setting_name: String,
    ) -> Answer {
        let (reply, answer) = oneshot::channel();
        let id = {
            let mut queue = self.queue();
            queue.next_id += 1;
            prompt.id = queue.next_id;
            let id = prompt.id;
            queue.pending.push(Pending { prompt, connection_path, setting_name, reply });
            id
        };
        // A D-Bus hivas megszakadhat (a NetworkManager bontja, a kapcsolat
        // bezarul): a kerdes akkor se ragadjon a dialogusban.
        let _guard = PendingGuard { owner: Arc::clone(self), sink: sink.clone(), id };
        self.publish(sink);

        match tokio::time::timeout(PROMPT_TIMEOUT, answer).await {
            Ok(Ok(answer)) => answer,
            // A kuldo eldobva: a modul leall, a shell elment.
            Ok(Err(_)) => Answer::AgentCanceled,
            Err(_) => Answer::UserCanceled,
        }
    }
}

struct PendingGuard {
    owner: Arc<NetSecrets>,
    sink: StateSink,
    id: u64,
}

impl Drop for PendingGuard {
    fn drop(&mut self) {
        if self.owner.take(self.id).is_some() {
            self.owner.publish(&self.sink);
        }
    }
}

/// A hurok leallasakor minden fuggo kerdes elmarad: a kuldok eldobasa
/// `AgentCanceled`-et ad a NetworkManagernek.
struct ClearOnDrop(Arc<NetSecrets>);

impl Drop for ClearOnDrop {
    fn drop(&mut self) {
        let mut queue = self.0.queue();
        queue.pending.clear();
        queue.registered = false;
    }
}

/// A leallo hurok utan kijelentkezik, es bezarja a sajat buszkapcsolatot. Ha
/// a kijelentkezes elmaradna, a kapcsolat bezarasa akkor is torli az agentet.
struct Registration(zbus::Connection);

impl Drop for Registration {
    fn drop(&mut self) {
        let connection = self.0.clone();
        let Ok(runtime) = tokio::runtime::Handle::try_current() else { return };
        runtime.spawn(async move {
            if let Ok(manager) = nm::AgentManagerProxy::new(&connection).await {
                let _ = tokio::time::timeout(Duration::from_secs(2), manager.unregister()).await;
            }
            let _ = connection.close().await;
        });
    }
}

/// A D-Bus objektum, amit a NetworkManager hiv.
struct Agent {
    owner: Arc<NetSecrets>,
    sink: StateSink,
}

impl Agent {
    /// Csak a NetworkManager aktualis peldanya hivhat minket.
    async fn authorize(
        &self,
        connection: &zbus::Connection,
        header: &Header<'_>,
    ) -> Result<(), AgentError> {
        let denied =
            || AgentError::PermissionDenied("only NetworkManager may call this agent".into());
        let sender = header.sender().ok_or_else(denied)?;
        let dbus = zbus::fdo::DBusProxy::new(connection).await?;
        let service = zbus::names::BusName::try_from(NM_SERVICE).map_err(zbus::Error::from)?;
        let owner = dbus.get_name_owner(service).await.map_err(|_| denied())?;
        if owner.as_str() != sender.as_str() {
            tracing::warn!(%sender, "idegen folyamat hivta a titokkerot");
            return Err(denied());
        }
        Ok(())
    }
}

#[zbus::interface(name = "org.freedesktop.NetworkManager.SecretAgent")]
impl Agent {
    // A D-Bus alairas kotott: a NetworkManager ot argumentumot kuld.
    #[allow(clippy::too_many_arguments)]
    async fn get_secrets(
        &self,
        #[zbus(connection)] bus: &zbus::Connection,
        #[zbus(header)] header: Header<'_>,
        connection: Settings,
        connection_path: OwnedObjectPath,
        setting_name: String,
        hints: Vec<String>,
        flags: u32,
    ) -> Result<Settings, AgentError> {
        self.authorize(bus, &header).await?;

        let Some(plan) = plan(&setting_name, &connection, &hints) else {
            return Err(AgentError::NoSecrets(format!("{setting_name} is not handled here")));
        };
        let uuid = string(&connection, "connection", "uuid").unwrap_or_default();
        let interactive = flags & ALLOW_INTERACTION != 0;
        let request_new = flags & REQUEST_NEW != 0;

        // A "csak ehhez a felhasznalohoz" mentett titkok a kulcstarban vannak:
        // ezeket a NetworkManager nem tarolja, minden csatlakozaskor tolunk keri.
        let mut stored = HashMap::new();
        if !request_new && !uuid.is_empty() {
            for field in plan.fields.iter().filter(|field| field.flags & AGENT_OWNED != 0) {
                let attributes = [
                    ("connection-uuid", uuid.as_str()),
                    ("setting-name", setting_name.as_str()),
                    ("setting-key", field.key.as_str()),
                ];
                match secret::lookup(&attributes, interactive).await {
                    Ok(Some(bytes)) => {
                        if let Ok(value) = String::from_utf8(bytes) {
                            stored.insert(field.key.clone(), value);
                        }
                    }
                    Ok(None) => {}
                    Err(err) => tracing::debug!(%err, "a kulcstar nem adott titkot"),
                }
            }
            if plan.fields.iter().all(|field| stored.contains_key(&field.key)) {
                return Ok(reply(&setting_name, stored));
            }
        }

        if !interactive {
            if stored.is_empty() {
                return Err(AgentError::NoSecrets("no stored secrets".into()));
            }
            return Ok(reply(&setting_name, stored));
        }

        let prompt = Prompt {
            id: 0,
            kind: plan.kind,
            connection: string(&connection, "connection", "id").unwrap_or_default(),
            ssid: ssid(&connection),
            identity: string(&connection, "802-1x", "identity").unwrap_or_default(),
            retry: request_new,
            fields: plan.fields.clone(),
        };
        let path = connection_path.as_str().to_string();
        match self.owner.ask(&self.sink, prompt, path, setting_name.clone()).await {
            Answer::Secrets(mut values) => {
                values.retain(|key, _| plan.fields.iter().any(|field| &field.key == key));
                Ok(reply(&setting_name, values))
            }
            Answer::UserCanceled => Err(AgentError::UserCanceled("cancelled".into())),
            Answer::AgentCanceled => Err(AgentError::AgentCanceled("the shell went away".into())),
        }
    }

    async fn cancel_get_secrets(
        &self,
        #[zbus(connection)] bus: &zbus::Connection,
        #[zbus(header)] header: Header<'_>,
        connection_path: OwnedObjectPath,
        setting_name: String,
    ) -> Result<(), AgentError> {
        self.authorize(bus, &header).await?;
        let cancelled: Vec<Pending> = {
            let mut queue = self.owner.queue();
            let (matching, rest) =
                std::mem::take(&mut queue.pending).into_iter().partition(|pending: &Pending| {
                    pending.connection_path == connection_path.as_str()
                        && pending.setting_name == setting_name
                });
            queue.pending = rest;
            matching
        };
        if !cancelled.is_empty() {
            for pending in cancelled {
                let _ = pending.reply.send(Answer::AgentCanceled);
            }
            self.owner.publish(&self.sink);
        }
        Ok(())
    }

    async fn save_secrets(
        &self,
        #[zbus(connection)] bus: &zbus::Connection,
        #[zbus(header)] header: Header<'_>,
        connection: Settings,
        _connection_path: OwnedObjectPath,
    ) -> Result<(), AgentError> {
        self.authorize(bus, &header).await?;
        let uuid = string(&connection, "connection", "uuid").unwrap_or_default();
        let id = string(&connection, "connection", "id").unwrap_or_default();
        if uuid.is_empty() {
            return Ok(());
        }
        for (setting_name, key, value) in agent_owned_secrets(&connection) {
            let label = format!("Network secret for {id}/{setting_name}/{key}");
            let attributes = [
                ("xdg:schema", KEYRING_SCHEMA),
                ("connection-uuid", uuid.as_str()),
                ("setting-name", setting_name.as_str()),
                ("setting-key", key.as_str()),
            ];
            if let Err(err) = secret::store(&label, &attributes, value.as_bytes(), true).await {
                tracing::warn!(%err, setting = %setting_name, %key, "a titok nem mentheto a kulcstarba");
            }
        }
        Ok(())
    }

    async fn delete_secrets(
        &self,
        #[zbus(connection)] bus: &zbus::Connection,
        #[zbus(header)] header: Header<'_>,
        connection: Settings,
        _connection_path: OwnedObjectPath,
    ) -> Result<(), AgentError> {
        self.authorize(bus, &header).await?;
        let uuid = string(&connection, "connection", "uuid").unwrap_or_default();
        if uuid.is_empty() {
            return Ok(());
        }
        if let Err(err) = secret::delete(&[("connection-uuid", uuid.as_str())], false).await {
            tracing::debug!(%err, "a kulcstarbol nem torolheto a kapcsolat titka");
        }
        Ok(())
    }
}

#[async_trait]
impl Module for NetSecrets {
    fn name(&self) -> &'static str {
        "netsecrets"
    }

    fn describe(&self) -> ModuleDescription {
        ModuleDescription {
            topic: "netsecrets",
            summary: "NetworkManager titokkero: a halozati jelszokereseket a shell kerdezi meg.",
            streams: true,
            methods: vec![
                MethodDescription::new("reply", "Valasz egy fuggo jelszokeresre.")
                    .param("id", "number", true, "A keres azonositoja a topicbol.")
                    .param("secrets", "object", true, "Mezonev -> beirt ertek."),
                MethodDescription::new("cancel", "Egy fuggo jelszokeres elutasitasa.").param(
                    "id",
                    "number",
                    true,
                    "A keres azonositoja a topicbol.",
                ),
            ],
        }
    }

    async fn run(self: Arc<Self>, sink: StateSink) -> Result<()> {
        let _clear = ClearOnDrop(Arc::clone(&self));
        let agent = Agent { owner: Arc::clone(&self), sink: sink.clone() };
        // Sajat kapcsolat, nem a megosztott: a bezarasa egyben a kijelentkezes.
        let connection =
            zbus::connection::Builder::system()?.serve_at(AGENT_PATH, agent)?.build().await?;
        let _registration = Registration(connection.clone());

        let dbus = zbus::fdo::DBusProxy::new(&connection).await?;
        let mut owners = dbus.receive_name_owner_changed_with_args(&[(0, NM_SERVICE)]).await?;
        let manager = nm::AgentManagerProxy::new(&connection).await?;

        self.set_registered(register(&manager).await, &sink);

        while let Some(signal) = owners.next().await {
            let args = signal.args()?;
            if args.new_owner().is_some() {
                // Az uj peldany meg az AgentManagert allitja fel.
                tokio::time::sleep(Duration::from_millis(500)).await;
                self.set_registered(register(&manager).await, &sink);
            } else {
                self.set_registered(false, &sink);
            }
        }
        Err(anyhow!("a NameOwnerChanged jelfolyam lezarult"))
    }

    async fn call(self: Arc<Self>, method: &str, params: Value, sink: &StateSink) -> Result<Value> {
        match method {
            "reply" => {
                let id = request_id(&params)?;
                let values = secret_values(&params)?;
                let pending = self
                    .take_valid(id, &values)
                    // A `failed` uzenete elotag nelkul jut el a dialogusig.
                    .map_err(|message| anyhow::Error::from(ModuleError::failed(message)))?
                    .ok_or_else(|| ModuleError::not_found("this request is no longer pending"))?;
                let _ = pending.reply.send(Answer::Secrets(values));
                self.publish(sink);
                Ok(json!({ "accepted": true }))
            }
            "cancel" => {
                let id = request_id(&params)?;
                if let Some(pending) = self.take(id) {
                    let _ = pending.reply.send(Answer::UserCanceled);
                    self.publish(sink);
                }
                Ok(Value::Null)
            }
            other => Err(ModuleError::UnknownMethod(other.to_string()).into()),
        }
    }
}

impl NetSecrets {
    /// Ellenorzi a valaszt, mielott a kerest lezarna. Egy hibas ertek (pl.
    /// tul rovid WPA jelszo) nem zarja le: a dialogus nyitva marad.
    fn take_valid(
        &self,
        id: u64,
        values: &HashMap<String, String>,
    ) -> Result<Option<Pending>, String> {
        {
            let queue = self.queue();
            let Some(pending) = queue.pending.iter().find(|pending| pending.prompt.id == id) else {
                return Ok(None);
            };
            validate(&pending.prompt, values)?;
        }
        Ok(self.take(id))
    }
}

async fn register(manager: &nm::AgentManagerProxy<'_>) -> bool {
    match manager.register_with_capabilities(AGENT_ID, 0).await {
        Ok(()) => {
            tracing::info!("a NetworkManager titokkero regisztralva");
            true
        }
        Err(err) => {
            tracing::warn!(%err, "a NetworkManager titokkero nem regisztralhato");
            false
        }
    }
}

fn request_id(params: &Value) -> Result<u64> {
    params
        .get("id")
        .and_then(Value::as_u64)
        .ok_or_else(|| ModuleError::invalid_params("az `id` kotelezo szam").into())
}

fn secret_values(params: &Value) -> Result<HashMap<String, String>> {
    let object = params
        .get("secrets")
        .and_then(Value::as_object)
        .ok_or_else(|| ModuleError::invalid_params("a `secrets` kotelezo objektum"))?;
    Ok(object
        .iter()
        .filter_map(|(key, value)| Some((key.clone(), value.as_str()?.to_string())))
        .collect())
}

fn validate(prompt: &Prompt, values: &HashMap<String, String>) -> Result<(), String> {
    for field in &prompt.fields {
        let value = values.get(&field.key).map(String::as_str).unwrap_or("");
        if value.is_empty() {
            return Err(format!("{} is required", field.label));
        }
        if field.key == "psk" && !valid_psk(value) {
            return Err("A Wi-Fi password is 8 to 63 characters long".into());
        }
    }
    Ok(())
}

/// WPA-PSK: 8-63 nyomtathato ASCII karakter, vagy 64 hexa szamjegy.
fn valid_psk(value: &str) -> bool {
    let length = value.len();
    if length == 64 {
        return value.chars().all(|c| c.is_ascii_hexdigit());
    }
    (8..=63).contains(&length) && value.chars().all(|c| (' '..='~').contains(&c))
}

fn reply(setting_name: &str, values: HashMap<String, String>) -> Settings {
    let setting =
        values.into_iter().filter_map(|(key, value)| Some((key, owned(value)?))).collect();
    HashMap::from([(setting_name.to_string(), setting)])
}

fn owned(value: String) -> Option<OwnedValue> {
    OwnedValue::try_from(zbus::zvariant::Value::from(value)).ok()
}

fn value<'a>(settings: &'a Settings, setting: &str, key: &str) -> Option<&'a OwnedValue> {
    settings.get(setting)?.get(key)
}

fn string(settings: &Settings, setting: &str, key: &str) -> Option<String> {
    String::try_from(value(settings, setting, key)?.try_clone().ok()?).ok()
}

fn number(settings: &Settings, setting: &str, key: &str) -> Option<u32> {
    u32::try_from(value(settings, setting, key)?.try_clone().ok()?).ok()
}

fn strings(settings: &Settings, setting: &str, key: &str) -> Vec<String> {
    value(settings, setting, key)
        .and_then(|value| value.try_clone().ok())
        .and_then(|value| Vec::<String>::try_from(value).ok())
        .unwrap_or_default()
}

fn ssid(settings: &Settings) -> String {
    value(settings, "802-11-wireless", "ssid")
        .and_then(|value| value.try_clone().ok())
        .and_then(|value| Vec::<u8>::try_from(value).ok())
        .map(|bytes| String::from_utf8_lossy(&bytes).into_owned())
        .unwrap_or_default()
}

/// Mely titkokat kell bekerni. `None`: ezt a beallitast nem mi kezeljuk.
fn plan(setting_name: &str, settings: &Settings, hints: &[String]) -> Option<Plan> {
    let wanted: (&'static str, Vec<(String, &str)>) = match setting_name {
        "802-11-wireless-security" => match string(settings, setting_name, "key-mgmt").as_deref() {
            Some("wpa-psk" | "sae") => ("wifi", vec![("psk".into(), "Password")]),
            Some("none") => {
                let index = number(settings, setting_name, "wep-tx-keyidx").unwrap_or(0).min(3);
                ("wep", vec![(format!("wep-key{index}"), "WEP key")])
            }
            Some("ieee8021x")
                if string(settings, setting_name, "auth-alg").as_deref() == Some("leap") =>
            {
                ("leap", vec![("leap-password".into(), "Password")])
            }
            _ => return None,
        },
        "802-1x" => {
            if strings(settings, setting_name, "eap").iter().any(|method| method == "tls") {
                ("8021x-tls", vec![("private-key-password".into(), "Private key password")])
            } else {
                ("8021x", vec![("password".into(), "Password")])
            }
        }
        "pppoe" => ("pppoe", vec![("password".into(), "Password")]),
        _ => return None,
    };

    let (kind, keys) = wanted;
    let mut fields: Vec<Field> = keys
        .into_iter()
        .map(|(key, label)| Field {
            flags: number(settings, setting_name, &format!("{key}-flags")).unwrap_or(0),
            key,
            label: label.to_string(),
        })
        .filter(|field| field.flags & NOT_REQUIRED == 0)
        .collect();

    // A NetworkManager megnevezheti a hianyzo kulcsot; ha a nevek kozul
    // egyet sem ismerunk, a teljes keszletet kerdezzuk.
    let hinted: Vec<Field> = fields
        .iter()
        .filter(|field| hints.iter().any(|hint| hint == &field.key))
        .cloned()
        .collect();
    if !hinted.is_empty() {
        fields = hinted;
    }

    (!fields.is_empty()).then_some(Plan { kind, fields })
}

/// A `SaveSecrets`-ben kapott, nekunk tarolando (agent-owned) szoveges titkok.
fn agent_owned_secrets(settings: &Settings) -> Vec<(String, String, String)> {
    let mut out = Vec::new();
    for (setting_name, values) in settings {
        for key in values.keys() {
            let Some(flags) = number(settings, setting_name, &format!("{key}-flags")) else {
                continue;
            };
            if flags & AGENT_OWNED == 0 || flags & NOT_SAVED != 0 {
                continue;
            }
            if let Some(secret) = string(settings, setting_name, key).filter(|s| !s.is_empty()) {
                out.push((setting_name.clone(), key.clone(), secret));
            }
        }
    }
    out.sort();
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use zbus::zvariant::Value as Variant;

    fn settings(entries: &[(&str, &str, Variant<'static>)]) -> Settings {
        let mut out: Settings = HashMap::new();
        for (setting, key, value) in entries {
            out.entry(setting.to_string())
                .or_default()
                .insert(key.to_string(), OwnedValue::try_from(value.clone()).unwrap());
        }
        out
    }

    const SECURITY: &str = "802-11-wireless-security";

    #[test]
    fn wpa_networks_ask_for_the_psk() {
        let connection = settings(&[(SECURITY, "key-mgmt", Variant::from("wpa-psk"))]);
        let plan = plan(SECURITY, &connection, &[]).unwrap();
        assert_eq!(plan.kind, "wifi");
        assert_eq!(plan.fields.len(), 1);
        assert_eq!(plan.fields[0].key, "psk");
        assert_eq!(plan.fields[0].flags, 0);
    }

    #[test]
    fn wep_uses_the_transmit_key_index_and_reads_agent_ownership() {
        let connection = settings(&[
            (SECURITY, "key-mgmt", Variant::from("none")),
            (SECURITY, "wep-tx-keyidx", Variant::from(2u32)),
            (SECURITY, "wep-key2-flags", Variant::from(AGENT_OWNED)),
        ]);
        let plan = plan(SECURITY, &connection, &[]).unwrap();
        assert_eq!(plan.kind, "wep");
        assert_eq!(plan.fields[0].key, "wep-key2");
        assert_eq!(plan.fields[0].flags, AGENT_OWNED);
    }

    #[test]
    fn enterprise_wifi_is_left_to_the_802_1x_setting() {
        let connection = settings(&[(SECURITY, "key-mgmt", Variant::from("wpa-eap"))]);
        assert!(plan(SECURITY, &connection, &[]).is_none());
    }

    #[test]
    fn eap_tls_asks_for_the_private_key_password_unless_it_is_not_required() {
        let tls = settings(&[("802-1x", "eap", Variant::from(vec!["tls"]))]);
        assert_eq!(plan("802-1x", &tls, &[]).unwrap().kind, "8021x-tls");

        let unencrypted = settings(&[
            ("802-1x", "eap", Variant::from(vec!["tls"])),
            ("802-1x", "private-key-password-flags", Variant::from(NOT_REQUIRED)),
        ]);
        assert!(plan("802-1x", &unencrypted, &[]).is_none());

        let peap = settings(&[("802-1x", "eap", Variant::from(vec!["peap"]))]);
        assert_eq!(plan("802-1x", &peap, &[]).unwrap().fields[0].key, "password");
    }

    #[test]
    fn vpn_secrets_are_left_to_other_agents() {
        let connection = settings(&[("vpn", "service-type", Variant::from("openvpn"))]);
        assert!(plan("vpn", &connection, &[]).is_none());
    }

    #[test]
    fn unknown_hints_do_not_hide_every_field() {
        let connection = settings(&[(SECURITY, "key-mgmt", Variant::from("sae"))]);
        let plan = plan(SECURITY, &connection, &["something-else".into()]).unwrap();
        assert_eq!(plan.fields[0].key, "psk");
    }

    #[test]
    fn ssid_is_decoded_from_bytes() {
        let connection =
            settings(&[("802-11-wireless", "ssid", Variant::from(b"Cafe guest".to_vec()))]);
        assert_eq!(ssid(&connection), "Cafe guest");
    }

    #[test]
    fn only_agent_owned_saved_secrets_go_to_the_keyring() {
        let connection = settings(&[
            (SECURITY, "psk", Variant::from("hunter22")),
            (SECURITY, "psk-flags", Variant::from(AGENT_OWNED)),
            (SECURITY, "leap-password", Variant::from("system")),
            (SECURITY, "leap-password-flags", Variant::from(0u32)),
            ("802-1x", "password", Variant::from("ask-every-time")),
            ("802-1x", "password-flags", Variant::from(AGENT_OWNED | NOT_SAVED)),
        ]);
        assert_eq!(
            agent_owned_secrets(&connection),
            vec![(SECURITY.to_string(), "psk".to_string(), "hunter22".to_string())]
        );
    }

    #[test]
    fn psk_validation_follows_the_wpa_rules() {
        assert!(valid_psk("12345678"));
        assert!(!valid_psk("1234567"));
        assert!(valid_psk(&"a".repeat(63)));
        assert!(!valid_psk(&"a".repeat(65)));
        assert!(valid_psk(&"0f".repeat(32)));
        assert!(!valid_psk(&"zz".repeat(32)));
        assert!(!valid_psk("jelszó123"));
    }

    #[test]
    fn a_too_short_answer_keeps_the_request_open() {
        let module = NetSecrets::new();
        let (reply, _answer) = oneshot::channel();
        module.queue().pending.push(Pending {
            prompt: Prompt {
                id: 7,
                kind: "wifi",
                connection: "Home".into(),
                ssid: "Home".into(),
                identity: String::new(),
                retry: false,
                fields: vec![Field { key: "psk".into(), label: "Password".into(), flags: 0 }],
            },
            connection_path: "/org/freedesktop/NetworkManager/Settings/1".into(),
            setting_name: SECURITY.into(),
            reply,
        });

        let short = HashMap::from([("psk".to_string(), "short".to_string())]);
        assert!(module.take_valid(7, &short).is_err());
        assert_eq!(module.queue().pending.len(), 1);

        let good = HashMap::from([("psk".to_string(), "long enough".to_string())]);
        assert!(module.take_valid(7, &good).unwrap().is_some());
        assert!(module.queue().pending.is_empty());
        assert!(module.take_valid(7, &good).unwrap().is_none());
    }
}

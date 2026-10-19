//! Google Naptar: bejelentkezes es esemenyek a Google Calendar API-bol.
//!
//! A bejelentkezes a Google asztali alkalmazasoknak szant folyamata: loopback
//! atiranyitas (`http://127.0.0.1:<port>`) PKCE-vel. A daemon egy egyszeri
//! helyi portot nyit, a bongeszo oda kuldi vissza a kodot, a daemon pedig
//! refresh tokenre valtja. Csak olvasasi jogot kerunk (`calendar.readonly`).
//!
//! A Google minden asztali alkalmazastol OAuth klienst ker (client id +
//! secret). Ezt a felhasznalo egyszer adja meg a Settingsben (vagy build
//! idoben `VELLUM_GOOGLE_CLIENT_ID` / `VELLUM_GOOGLE_CLIENT_SECRET`); az
//! asztali kliens "titka" a Google szerint sem titok, csak azonosito.
//!
//! A refresh token a rendszer kulcstaraban (Secret Service: GNOME Keyring,
//! KWallet) el, titkositva. A fajlba (0600, allapotmappa) csak a nem titkos
//! resz kerul: az email es a naptarak lathatosaga. A korabbi, fajlban tarolt
//! token az elso hasznalatkor atkoltozik a kulcstarba. Az access token es az
//! esemenyek memoriaban elnek. Az ismetlodo esemenyeket a Google bontja ki (`singleEvents`), igy
//! itt nincs RRULE-ertelmezes.

use crate::module::{MethodDescription, Module, ModuleDescription, ModuleError, StateSink};
use crate::secret::{self, SecretError};
use crate::theme::paths;
use anyhow::{Context, Result, bail};
use async_trait::async_trait;
use base64::Engine;
use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use futures_util::future::join_all;
use reqwest::Url;
use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::collections::HashMap;
use std::io::Write;
use std::os::unix::fs::{DirBuilderExt, OpenOptionsExt};
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::Mutex;
use tokio::task::JoinHandle;

const AUTH_ENDPOINT: &str = "https://accounts.google.com/o/oauth2/v2/auth";
const TOKEN_ENDPOINT: &str = "https://oauth2.googleapis.com/token";
const REVOKE_ENDPOINT: &str = "https://oauth2.googleapis.com/revoke";
const API_ROOT: &str = "https://www.googleapis.com/calendar/v3";
const SCOPE: &str = "https://www.googleapis.com/auth/calendar.readonly";

/// Ennyi idonkent kerdezzuk ujra a naptarat, amig valaki nezi.
const REFRESH_EVERY: Duration = Duration::from_secs(10 * 60);
/// Ennyit varunk a bongeszoben torteno jovahagyasra.
const LOGIN_TIMEOUT: Duration = Duration::from_secs(5 * 60);
const REQUEST_TIMEOUT: Duration = Duration::from_secs(10);
/// A lekert idoablak a mai naphoz kepest: a havi nezet visszafele es elore is
/// lapozhato.
const WINDOW_PAST_DAYS: i64 = 62;
const WINDOW_FUTURE_DAYS: i64 = 366;
/// Felso korlat, hogy egy nagyon zsufolt naptar se fujja fel a topicot.
const MAX_EVENTS: usize = 5000;
const MAX_PAGES: usize = 4;

const DAY_MS: i64 = 86_400_000;

/// A refresh token kulcstar-eleme. A `replace` ezek alapjan irja felul.
const SECRET_LABEL: &str = "Vellum Shell: Google Calendar";
const SECRET_ATTRIBUTES: &[(&str, &str)] =
    &[("application", "vellum-shell"), ("service", "google-calendar")];

/// A refresh token mar nem ervenyes: a felhasznalo visszavonta, vagy lejart.
#[derive(Debug, thiserror::Error)]
#[error("Google access expired or was revoked. Sign in again.")]
struct AuthExpired;

#[derive(Debug, Clone, PartialEq)]
struct OAuthClient {
    client_id: String,
    client_secret: String,
}

/// A tarolt fiok nem titkos resze. A refresh token a kulcstarban van.
#[derive(Debug, Clone, Default, PartialEq, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct Account {
    /// Csak a korabbi, fajlos tarolasbol valo atallashoz olvassuk; az
    /// atkoltoztetes utan ures, es ures erteket nem irunk ki.
    #[serde(default, skip_serializing_if = "String::is_empty")]
    refresh_token: String,
    #[serde(default)]
    email: String,
    /// Naptar id -> lathato-e. Ami nincs benne, annal a Google sajat
    /// `selected` jelzoje dont (az, ami a Google feluleten is latszik).
    #[serde(default)]
    calendars: HashMap<String, bool>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CalendarInfo {
    pub id: String,
    pub name: String,
    pub color: String,
    pub enabled: bool,
    pub primary: bool,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Event {
    pub id: String,
    pub calendar: String,
    pub title: String,
    pub location: String,
    pub color: String,
    pub link: String,
    pub all_day: bool,
    /// Idoponthoz kotott esemenynel epoch ms; egesz naposnal 0.
    pub start: i64,
    pub end: i64,
    /// Egesz napos esemenynel "YYYY-MM-DD"; a vege kizarolagos, ahogy a
    /// Google adja. A QML helyi datumkent ertelmezi.
    pub start_date: String,
    pub end_date: String,
}

#[derive(Debug, Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CalendarState {
    /// Van-e OAuth kliens (enelkul nem lehet bejelentkezni).
    pub configured: bool,
    pub connected: bool,
    /// "idle" | "authorizing" | "syncing"
    pub status: &'static str,
    /// A kulcstar zarolt, ezert a token nem olvashato. A "Sync now" feloldja.
    pub locked: bool,
    pub account: String,
    pub error: String,
    /// A folyamatban levo bejelentkezes URL-je, hogy ujra megnyithato legyen.
    pub auth_url: String,
    /// Az utolso sikeres szinkron, epoch ms; 0 = meg nem volt.
    pub updated_at: i64,
    pub calendars: Vec<CalendarInfo>,
    pub events: Vec<Event>,
}

#[derive(Default)]
struct Inner {
    state: CalendarState,
    access: Option<(String, Instant)>,
    /// A kulcstarbol egyszer kiolvasott refresh token, hogy ne kelljen minden
    /// orankenti tokenfrissiteshez a kulcstarhoz fordulni.
    refresh: Option<String>,
    synced: Option<Instant>,
}

pub struct Calendar {
    client: reqwest::Client,
    inner: Mutex<Inner>,
    /// Egyszerre egy szinkron fut; a tobbi megvarja es a friss eredmenyt latja.
    sync_lock: Mutex<()>,
    login: Mutex<Option<JoinHandle<()>>>,
}

impl Default for Calendar {
    fn default() -> Self {
        Self::new()
    }
}

impl Calendar {
    pub fn new() -> Self {
        Self {
            client: reqwest::Client::builder()
                .timeout(REQUEST_TIMEOUT)
                .user_agent("vellum-shell")
                .build()
                .unwrap_or_default(),
            inner: Mutex::new(Inner {
                state: CalendarState { status: "idle", ..CalendarState::default() },
                ..Inner::default()
            }),
            sync_lock: Mutex::new(()),
            login: Mutex::new(None),
        }
    }
}

#[async_trait]
impl Module for Calendar {
    fn name(&self) -> &'static str {
        "calendar"
    }

    fn describe(&self) -> ModuleDescription {
        ModuleDescription {
            topic: "calendar",
            summary: "Google Naptar esemenyek (csak olvasas), OAuth bejelentkezessel.",
            streams: true,
            methods: vec![
                MethodDescription::new(
                    "login",
                    "Elinditja a Google bejelentkezest; a valasz `url` mezoje a bongeszoben megnyitando cim.",
                ),
                MethodDescription::new("cancelLogin", "Megszakitja a folyamatban levo bejelentkezest."),
                MethodDescription::new(
                    "logout",
                    "Kijelentkezik: visszavonja es torli a tarolt tokent.",
                ),
                MethodDescription::new("refresh", "Azonnali szinkron a Google-lel."),
                MethodDescription::new("setCalendar", "Egy naptar megjelenitese vagy elrejtese.")
                    .param("id", "string", true, "A naptar Google azonositoja.")
                    .param("enabled", "bool", true, "Latszodjanak-e az esemenyei."),
                MethodDescription::new(
                    "setClient",
                    "Elmenti a Google Cloud Console-ban letrehozott asztali OAuth klienst.",
                )
                .param("clientId", "string", true, "Az OAuth kliens azonositoja.")
                .param("clientSecret", "string", true, "Az OAuth kliens titka."),
            ],
        }
    }

    async fn run(self: Arc<Self>, sink: StateSink) -> Result<()> {
        self.publish(&sink).await;
        loop {
            let synced = self.inner.lock().await.synced;
            let wait = match synced {
                Some(at) if at.elapsed() < REFRESH_EVERY => REFRESH_EVERY - at.elapsed(),
                _ => {
                    // A hatterben futo szinkron sosem nyit jelszoablakot: a
                    // panel overlay alatt az nem is latszana.
                    self.sync(&sink, false).await;
                    REFRESH_EVERY
                }
            };
            tokio::time::sleep(wait).await;
        }
    }

    async fn call(self: Arc<Self>, method: &str, params: Value, sink: &StateSink) -> Result<Value> {
        match method {
            "login" => self.begin_login(sink).await,
            "cancelLogin" => {
                self.cancel_login().await;
                self.publish(sink).await;
                Ok(Value::Null)
            }
            "logout" => {
                self.logout().await;
                self.publish(sink).await;
                Ok(Value::Null)
            }
            "refresh" => {
                self.sync(sink, true).await;
                Ok(Value::Null)
            }
            "setCalendar" => {
                let id = string_param(&params, "id")?;
                let enabled = params
                    .get("enabled")
                    .and_then(Value::as_bool)
                    .ok_or_else(|| ModuleError::invalid_params("'enabled' must be a bool"))?;
                self.set_calendar(&id, enabled).await?;
                self.publish(sink).await;
                // Az esemenyeket a hatterben toltjuk ujra: a kapcsolo azonnal
                // valtson, ne a halozatra varjon.
                let module = Arc::clone(&self);
                let sink = sink.clone();
                tokio::spawn(async move { module.sync(&sink, false).await });
                Ok(Value::Null)
            }
            "setClient" => {
                let client = OAuthClient {
                    client_id: string_param(&params, "clientId")?,
                    client_secret: string_param(&params, "clientSecret")?,
                };
                if !client.client_id.ends_with(".apps.googleusercontent.com") {
                    return Err(ModuleError::invalid_params(
                        "the client ID should end with .apps.googleusercontent.com",
                    )
                    .into());
                }
                save_client(&client)?;
                self.inner.lock().await.state.error.clear();
                self.publish(sink).await;
                Ok(Value::Null)
            }
            other => Err(ModuleError::UnknownMethod(other.to_string()).into()),
        }
    }
}

impl Calendar {
    async fn publish(&self, sink: &StateSink) {
        let mut state = self.inner.lock().await.state.clone();
        state.configured = oauth_client().is_some();
        state.connected = account_path().exists();
        sink.push(json!(state));
    }

    // -- bejelentkezes -------------------------------------------------------

    async fn begin_login(self: &Arc<Self>, sink: &StateSink) -> Result<Value> {
        let client = oauth_client().ok_or_else(|| {
            ModuleError::failed("no Google OAuth client is configured; add one in Settings first")
        })?;
        self.cancel_login().await;

        let listener = TcpListener::bind(("127.0.0.1", 0))
            .await
            .context("a helyi visszahivo port nem nyithato meg")?;
        let redirect = format!("http://127.0.0.1:{}", listener.local_addr()?.port());
        let verifier = random_token(32)?;
        let state_token = random_token(16)?;
        let url = auth_url(&client.client_id, &redirect, &pkce_challenge(&verifier), &state_token)?;

        {
            let mut inner = self.inner.lock().await;
            inner.state.status = "authorizing";
            inner.state.error.clear();
            inner.state.auth_url = url.clone();
        }
        self.publish(sink).await;

        let module = Arc::clone(self);
        let sink = sink.clone();
        let task = tokio::spawn(async move {
            let outcome = tokio::time::timeout(
                LOGIN_TIMEOUT,
                module.finish_login(listener, &client, &redirect, &verifier, &state_token),
            )
            .await;
            let error = match outcome {
                Ok(Ok(())) => None,
                Ok(Err(err)) => Some(format!("{err:#}")),
                Err(_) => Some("Sign-in timed out. Try again.".to_string()),
            };

            {
                let mut inner = module.inner.lock().await;
                inner.state.status = "idle";
                inner.state.auth_url.clear();
                if let Some(error) = &error {
                    tracing::warn!(error = %error, "a Google bejelentkezes nem sikerult");
                    inner.state.error = error.clone();
                }
            }
            if error.is_none() {
                module.sync(&sink, true).await;
            } else {
                module.publish(&sink).await;
            }
        });
        *self.login.lock().await = Some(task);

        Ok(json!({ "url": url }))
    }

    async fn finish_login(
        &self,
        listener: TcpListener,
        client: &OAuthClient,
        redirect: &str,
        verifier: &str,
        expected_state: &str,
    ) -> Result<()> {
        let (code, mut stream) = wait_for_code(&listener, expected_state).await?;
        drop(listener);

        // A bongeszo fule csak a tokencsere utan kap valaszt: igy azt mutatja,
        // ami tenyleg tortent, nem egy idoelotti "kesz"-t.
        let exchanged = self
            .token_request(&[
                ("grant_type", "authorization_code"),
                ("code", &code),
                ("client_id", &client.client_id),
                ("client_secret", &client.client_secret),
                ("redirect_uri", redirect),
                ("code_verifier", verifier),
            ])
            .await
            .and_then(|tokens| {
                let refresh_token = tokens
                    .refresh_token
                    .clone()
                    .filter(|token| !token.is_empty())
                    .context("Google did not return a refresh token")?;
                Ok((tokens, refresh_token))
            });
        let (tokens, refresh_token) = match exchanged {
            Ok(result) => result,
            Err(err) => {
                respond(
                    &mut stream,
                    "200 OK",
                    "Sign-in failed. Check the Calendar page in Vellum Settings.",
                )
                .await;
                return Err(err);
            }
        };

        // A token a kulcstarba kerul. Ha a kulcstar zarolt, itt kerul elo a
        // jelszoablak; ha nem sikerul, a tokent visszavonjuk, nem hagyjuk
        // gazdatlanul ervenyben.
        let stored =
            secret::store(SECRET_LABEL, SECRET_ATTRIBUTES, refresh_token.as_bytes(), true).await;
        if let Err(err) = stored {
            respond(
                &mut stream,
                "200 OK",
                "Google approved the sign-in, but the keyring could not store it. \
                 Check the Calendar page in Vellum Settings.",
            )
            .await;
            self.revoke(&refresh_token).await;
            return Err(err.context("the sign-in could not be saved to the keyring"));
        }
        respond(
            &mut stream,
            "200 OK",
            "Vellum Shell is now connected to Google Calendar. You can close this tab.",
        )
        .await;

        // Ugyanannak a fioknak az ujracsatlakozasa megtartja a naptarvalasztast;
        // az email a szinkronnal frissul. Egy esetleges regi, fajlban tarolt
        // token itt vegleg kikerul a fajlbol.
        let previous = load_account().unwrap_or_default();
        save_account(&Account { refresh_token: String::new(), ..previous })?;

        let mut inner = self.inner.lock().await;
        inner.access = Some((tokens.access_token, expiry(tokens.expires_in)));
        inner.refresh = Some(refresh_token);
        inner.synced = None;
        Ok(())
    }

    async fn cancel_login(&self) {
        if let Some(task) = self.login.lock().await.take() {
            task.abort();
        }
        let mut inner = self.inner.lock().await;
        if inner.state.status == "authorizing" {
            inner.state.status = "idle";
        }
        inner.state.auth_url.clear();
    }

    async fn logout(&self) {
        self.cancel_login().await;
        let _guard = self.sync_lock.lock().await;

        // A visszavonas udvariassag: ha nem sikerul (nincs halozat, a kulcstar
        // zarolt marad), a token akkor is torlodik innen, a Google fiokban
        // pedig kezzel visszavonhato.
        if let Some(account) = load_account() {
            match self.refresh_token(&account, true).await {
                Ok(token) => self.revoke(&token).await,
                Err(err) => tracing::warn!(
                    error = format!("{err:#}"),
                    "a token nem olvashato, nem vonhato vissza"
                ),
            }
        }
        if let Err(err) = secret::delete(SECRET_ATTRIBUTES, true).await {
            tracing::warn!(error = format!("{err:#}"), "a kulcstar elem nem torolheto");
        }
        if let Err(err) = std::fs::remove_file(account_path())
            && err.kind() != std::io::ErrorKind::NotFound
        {
            tracing::warn!(error = %err, "a naptar fiokfajl nem torolheto");
        }

        let mut inner = self.inner.lock().await;
        inner.access = None;
        inner.refresh = None;
        inner.synced = None;
        inner.state = CalendarState { status: "idle", ..CalendarState::default() };
    }

    async fn revoke(&self, token: &str) {
        let revoked = self.client.post(REVOKE_ENDPOINT).form(&[("token", token)]).send().await;
        if let Err(err) = revoked {
            tracing::warn!(error = %err, "a Google token nem vonhato vissza");
        }
    }

    async fn set_calendar(&self, id: &str, enabled: bool) -> Result<()> {
        let mut account =
            load_account().ok_or_else(|| ModuleError::failed("not signed in to Google"))?;
        account.calendars.insert(id.to_string(), enabled);
        save_account(&account)?;

        let mut inner = self.inner.lock().await;
        for calendar in &mut inner.state.calendars {
            if calendar.id == id {
                calendar.enabled = enabled;
            }
        }
        if !enabled {
            inner.state.events.retain(|event| event.calendar != id);
        }
        inner.synced = None;
        Ok(())
    }

    // -- szinkron ------------------------------------------------------------

    /// `interactive`: feloldhatja-e a zarolt kulcstarat jelszoablakkal. Csak a
    /// felhasznalo sajat muveletei (bejelentkezes, "Sync now") kapjak meg.
    async fn sync(&self, sink: &StateSink, interactive: bool) {
        let _guard = self.sync_lock.lock().await;

        let account = load_account();
        let client = oauth_client();
        let (Some(account), Some(client)) = (account, client) else {
            let mut inner = self.inner.lock().await;
            inner.state.calendars.clear();
            inner.state.events.clear();
            inner.state.account.clear();
            inner.synced = Some(Instant::now());
            drop(inner);
            self.publish(sink).await;
            return;
        };

        {
            let mut inner = self.inner.lock().await;
            if inner.state.status != "authorizing" {
                inner.state.status = "syncing";
            }
            if inner.state.account.is_empty() {
                inner.state.account = account.email.clone();
            }
        }
        self.publish(sink).await;

        let result = self.fetch(&client, &account, interactive).await;

        let mut inner = self.inner.lock().await;
        // Hiba eseten is szamit "szinkronnak": a kovetkezo probalkozas a
        // szokasos idokozzel jon, nem porog a hurok egy halozat nelkuli gepen.
        inner.synced = Some(Instant::now());
        if inner.state.status == "syncing" {
            inner.state.status = "idle";
        }
        match result {
            Ok((calendars, events)) => {
                let email = calendars
                    .iter()
                    .find(|calendar| calendar.primary)
                    .map(|calendar| calendar.id.clone())
                    .unwrap_or_default();
                // Frissen olvassuk vissza: a szinkron kozben a token
                // atkoltozhetett a kulcstarba, a regi peldany meg tartalmazza.
                if !email.is_empty()
                    && email != account.email
                    && let Some(stored) = load_account()
                {
                    let updated = Account { email: email.clone(), ..stored };
                    if let Err(err) = save_account(&updated) {
                        tracing::warn!(error = format!("{err:#}"), "a fiokfajl nem irhato");
                    }
                }
                if !email.is_empty() {
                    inner.state.account = email;
                }
                inner.state.calendars = calendars;
                inner.state.events = events;
                inner.state.error.clear();
                inner.state.locked = false;
                inner.state.updated_at = now_ms();
            }
            Err(err) if err.downcast_ref::<AuthExpired>().is_some() => {
                tracing::warn!("a Google refresh token ervenytelen, a fiok torlodik");
                let _ = std::fs::remove_file(account_path());
                if let Err(err) = secret::delete(SECRET_ATTRIBUTES, false).await {
                    tracing::debug!(error = format!("{err:#}"), "a kulcstar elem nem torolheto");
                }
                inner.access = None;
                inner.refresh = None;
                inner.state = CalendarState {
                    status: inner.state.status,
                    error: AuthExpired.to_string(),
                    ..CalendarState::default()
                };
            }
            Err(err) if err.downcast_ref::<SecretError>().is_some() => {
                // A kulcstar zarolt vagy nem elerheto: a fiok ervenyes marad,
                // a korabbi esemenyek is.
                inner.state.locked = matches!(
                    err.downcast_ref::<SecretError>(),
                    Some(SecretError::Locked | SecretError::Dismissed)
                );
                inner.state.error = match err.downcast_ref::<SecretError>() {
                    Some(SecretError::Locked) => {
                        "The keyring is locked. Press Unlock to open it.".to_string()
                    }
                    Some(SecretError::Dismissed) => {
                        "Unlocking the keyring was cancelled.".to_string()
                    }
                    _ => format!("{err:#}"),
                };
            }
            Err(err) => {
                tracing::warn!(error = format!("{err:#}"), "a Google naptar nem frissitheto");
                // A korabbi esemenyek maradnak: jobb egy kicsit regi naptar,
                // mint egy ures.
                inner.state.error = format!("{err:#}");
            }
        }
        drop(inner);
        self.publish(sink).await;
    }

    async fn fetch(
        &self,
        client: &OAuthClient,
        account: &Account,
        interactive: bool,
    ) -> Result<(Vec<CalendarInfo>, Vec<Event>)> {
        let token = self.access_token(client, account, interactive).await?;

        let mut url = Url::parse(&format!("{API_ROOT}/users/me/calendarList"))?;
        url.query_pairs_mut().extend_pairs([
            ("maxResults", "250"),
            ("fields", "items(id,summary,summaryOverride,backgroundColor,primary,selected)"),
        ]);
        let list: ApiCalendarList = self.get_json(&token, url).await?;
        let calendars: Vec<CalendarInfo> =
            list.items.into_iter().map(|item| item.into_info(&account.calendars)).collect();

        let now = now_ms();
        let time_min = format_rfc3339_utc((now - WINDOW_PAST_DAYS * DAY_MS) / 1000);
        let time_max = format_rfc3339_utc((now + WINDOW_FUTURE_DAYS * DAY_MS) / 1000);

        let enabled: Vec<&CalendarInfo> =
            calendars.iter().filter(|calendar| calendar.enabled).collect();
        let results = join_all(
            enabled
                .iter()
                .map(|calendar| self.fetch_events(&token, calendar, &time_min, &time_max)),
        )
        .await;

        let mut events = Vec::new();
        let mut first_error = None;
        let mut any_ok = enabled.is_empty();
        for (calendar, result) in enabled.iter().zip(results) {
            match result {
                Ok(mut found) => {
                    any_ok = true;
                    events.append(&mut found);
                }
                Err(err) => {
                    tracing::warn!(
                        calendar = %calendar.name,
                        error = format!("{err:#}"),
                        "a naptar esemenyei nem kerhetok le"
                    );
                    first_error.get_or_insert(err);
                }
            }
        }
        // Egy hibas naptar nem viheti el a tobbit; ha viszont mind elbukott,
        // az mar kapcsolati hiba, amit jelezni kell.
        if !any_ok && let Some(err) = first_error {
            return Err(err);
        }

        events.sort_by(|a, b| sort_key(a).cmp(&sort_key(b)).then_with(|| a.title.cmp(&b.title)));
        events.truncate(MAX_EVENTS);
        Ok((calendars, events))
    }

    async fn fetch_events(
        &self,
        token: &str,
        calendar: &CalendarInfo,
        time_min: &str,
        time_max: &str,
    ) -> Result<Vec<Event>> {
        let mut base = Url::parse(API_ROOT)?;
        base.path_segments_mut()
            .map_err(|_| anyhow::anyhow!("ervenytelen API cim"))?
            .extend(["calendars", calendar.id.as_str(), "events"]);

        let mut events = Vec::new();
        let mut page_token: Option<String> = None;
        for _ in 0..MAX_PAGES {
            let mut url = base.clone();
            {
                let mut query = url.query_pairs_mut();
                query.extend_pairs([
                    ("timeMin", time_min),
                    ("timeMax", time_max),
                    ("singleEvents", "true"),
                    ("orderBy", "startTime"),
                    ("maxResults", "2500"),
                    (
                        "fields",
                        "nextPageToken,items(id,status,summary,location,htmlLink,eventType,start,end)",
                    ),
                ]);
                if let Some(page) = &page_token {
                    query.append_pair("pageToken", page);
                }
            }
            let page: ApiEventList = self.get_json(token, url).await?;
            events.extend(page.items.into_iter().filter_map(|item| convert_event(item, calendar)));
            page_token = page.next_page_token;
            if page_token.is_none() || events.len() >= MAX_EVENTS {
                break;
            }
        }
        Ok(events)
    }

    async fn access_token(
        &self,
        client: &OAuthClient,
        account: &Account,
        interactive: bool,
    ) -> Result<String> {
        {
            let inner = self.inner.lock().await;
            if let Some((token, until)) = &inner.access
                && *until > Instant::now() + Duration::from_secs(60)
            {
                return Ok(token.clone());
            }
        }

        let refresh_token = self.refresh_token(account, interactive).await?;
        let tokens = self
            .token_request(&[
                ("grant_type", "refresh_token"),
                ("refresh_token", &refresh_token),
                ("client_id", &client.client_id),
                ("client_secret", &client.client_secret),
            ])
            .await?;
        self.inner.lock().await.access =
            Some((tokens.access_token.clone(), expiry(tokens.expires_in)));
        Ok(tokens.access_token)
    }

    /// A refresh token: memoriabol, kulonben a kulcstarbol. Egy korabbi,
    /// fajlban tarolt tokent itt koltoztetunk at a kulcstarba.
    async fn refresh_token(&self, account: &Account, interactive: bool) -> Result<String> {
        if let Some(token) = self.inner.lock().await.refresh.clone() {
            return Ok(token);
        }

        let token = match secret::lookup(SECRET_ATTRIBUTES, interactive).await? {
            Some(bytes) => String::from_utf8(bytes).context("a kulcstarban levo token serult")?,
            None if !account.refresh_token.is_empty() => {
                secret::store(
                    SECRET_LABEL,
                    SECRET_ATTRIBUTES,
                    account.refresh_token.as_bytes(),
                    interactive,
                )
                .await?;
                if let Some(stored) = load_account() {
                    save_account(&Account { refresh_token: String::new(), ..stored })?;
                }
                tracing::info!("a Google refresh token atkerult a fajlbol a kulcstarba");
                account.refresh_token.clone()
            }
            // A fiokfajl megvan, de a token eltunt (pl. a kulcstarat toroltek):
            // ujra be kell jelentkezni.
            None => return Err(AuthExpired.into()),
        };
        if token.is_empty() {
            return Err(AuthExpired.into());
        }

        self.inner.lock().await.refresh = Some(token.clone());
        Ok(token)
    }

    async fn token_request(&self, form: &[(&str, &str)]) -> Result<TokenResponse> {
        let response = self
            .client
            .post(TOKEN_ENDPOINT)
            .form(form)
            .send()
            .await
            .context("Google sign-in is not reachable")?;
        if response.status().is_success() {
            return response.json().await.context("unexpected token response from Google");
        }

        let error: TokenError = response.json().await.unwrap_or_default();
        if error.error == "invalid_grant" {
            return Err(AuthExpired.into());
        }
        if error.error == "invalid_client" {
            bail!("Google rejected the OAuth client. Check the client ID and secret.");
        }
        bail!("Google refused the token request: {} {}", error.error, error.error_description)
    }

    async fn get_json<T: DeserializeOwned>(&self, token: &str, url: Url) -> Result<T> {
        let response = self
            .client
            .get(url)
            .bearer_auth(token)
            .send()
            .await
            .context("Google Calendar is not reachable")?;
        let status = response.status();
        if status.is_success() {
            return response.json().await.context("unexpected response from Google Calendar");
        }
        if status == reqwest::StatusCode::UNAUTHORIZED {
            // A kovetkezo szinkron uj access tokent ker.
            self.inner.lock().await.access = None;
        }
        // A Google hibauzenete hasznos (pl. "Google Calendar API has not been
        // used in project ... or it is disabled"), ezert tovabbadjuk.
        let body: ApiError = response.json().await.unwrap_or_default();
        let message = body.error.message.trim().to_string();
        if message.is_empty() {
            bail!("Google Calendar answered {status}");
        }
        bail!("{message}")
    }
}

// -- loopback visszahivas -----------------------------------------------------

#[derive(Debug, PartialEq)]
enum Callback {
    Code { code: String, state: String },
    Denied(String),
}

/// A visszakapott kod es a bongeszo kapcsolata, amelyre meg valaszolni kell.
async fn wait_for_code(
    listener: &TcpListener,
    expected_state: &str,
) -> Result<(String, TcpStream)> {
    loop {
        let (mut stream, _) = listener.accept().await.context("a visszahivas nem fogadhato")?;
        let Some(target) = read_request_target(&mut stream).await else {
            continue;
        };
        match parse_callback(&target) {
            // Pl. /favicon.ico: nem a mi valaszunk, varunk tovabb.
            None => respond(&mut stream, "404 Not Found", "Not found.").await,
            Some(Callback::Denied(reason)) => {
                respond(&mut stream, "200 OK", "Sign-in was cancelled. You can close this tab.")
                    .await;
                bail!("Google sign-in was cancelled ({reason})");
            }
            Some(Callback::Code { code, state }) => {
                if state != expected_state {
                    respond(&mut stream, "400 Bad Request", "This sign-in link has expired.").await;
                    bail!("the sign-in response did not match this request");
                }
                return Ok((code, stream));
            }
        }
    }
}

/// Az elso HTTP sor celja ("GET /?code=... HTTP/1.1" -> "/?code=...").
async fn read_request_target(stream: &mut TcpStream) -> Option<String> {
    let mut buffer = Vec::with_capacity(2048);
    let mut chunk = [0u8; 2048];
    while !buffer.windows(2).any(|pair| pair == b"\r\n") && buffer.len() < 16 * 1024 {
        let read = tokio::time::timeout(Duration::from_secs(5), stream.read(&mut chunk))
            .await
            .ok()?
            .ok()?;
        if read == 0 {
            break;
        }
        buffer.extend_from_slice(&chunk[..read]);
    }
    let text = String::from_utf8_lossy(&buffer);
    let line = text.lines().next()?;
    let mut parts = line.split_whitespace();
    if parts.next()? != "GET" {
        return None;
    }
    parts.next().map(str::to_string)
}

fn parse_callback(target: &str) -> Option<Callback> {
    let url = Url::parse(&format!("http://127.0.0.1{target}")).ok()?;
    if url.path() != "/" {
        return None;
    }
    let pairs: HashMap<String, String> = url.query_pairs().into_owned().collect();
    if let Some(error) = pairs.get("error") {
        return Some(Callback::Denied(error.clone()));
    }
    Some(Callback::Code { code: pairs.get("code")?.clone(), state: pairs.get("state")?.clone() })
}

async fn respond(stream: &mut TcpStream, status: &str, message: &str) {
    let body = format!(
        "<!doctype html><html><head><meta charset=\"utf-8\"><title>Vellum Shell</title></head>\
         <body style=\"font-family:sans-serif;background:#11130f;color:#e8ddc7;display:grid;\
         place-items:center;height:100vh;margin:0\"><p>{message}</p></body></html>"
    );
    let response = format!(
        "HTTP/1.1 {status}\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\n\
         Connection: close\r\n\r\n{body}",
        body.len()
    );
    let _ = stream.write_all(response.as_bytes()).await;
    let _ = stream.shutdown().await;
}

// -- OAuth segedek ------------------------------------------------------------

fn auth_url(client_id: &str, redirect: &str, challenge: &str, state: &str) -> Result<String> {
    let url = Url::parse_with_params(
        AUTH_ENDPOINT,
        [
            ("client_id", client_id),
            ("redirect_uri", redirect),
            ("response_type", "code"),
            ("scope", SCOPE),
            ("code_challenge", challenge),
            ("code_challenge_method", "S256"),
            ("state", state),
            // Refresh token csak `offline` hozzaferessel jar, es csak akkor, ha
            // a jovahagyo kepernyo tenyleg megjelenik.
            ("access_type", "offline"),
            ("prompt", "consent"),
        ],
    )?;
    Ok(url.into())
}

fn random_token(bytes: usize) -> Result<String> {
    use ring::rand::{SecureRandom, SystemRandom};
    let mut buffer = vec![0u8; bytes];
    SystemRandom::new()
        .fill(&mut buffer)
        .map_err(|_| anyhow::anyhow!("nincs elerheto veletlenszam-forras"))?;
    Ok(URL_SAFE_NO_PAD.encode(buffer))
}

/// RFC 7636 S256: base64url(sha256(verifier)).
fn pkce_challenge(verifier: &str) -> String {
    let digest = ring::digest::digest(&ring::digest::SHA256, verifier.as_bytes());
    URL_SAFE_NO_PAD.encode(digest.as_ref())
}

fn expiry(expires_in: u64) -> Instant {
    Instant::now() + Duration::from_secs(if expires_in == 0 { 3600 } else { expires_in })
}

#[derive(Debug, Deserialize)]
struct TokenResponse {
    access_token: String,
    #[serde(default)]
    expires_in: u64,
    #[serde(default)]
    refresh_token: Option<String>,
}

#[derive(Debug, Default, Deserialize)]
struct TokenError {
    #[serde(default)]
    error: String,
    #[serde(default)]
    error_description: String,
}

#[derive(Debug, Default, Deserialize)]
struct ApiError {
    #[serde(default)]
    error: ApiErrorBody,
}

#[derive(Debug, Default, Deserialize)]
struct ApiErrorBody {
    #[serde(default)]
    message: String,
}

// -- Calendar API valaszok ------------------------------------------------------

#[derive(Debug, Default, Deserialize)]
struct ApiCalendarList {
    #[serde(default)]
    items: Vec<ApiCalendar>,
}

#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ApiCalendar {
    id: String,
    #[serde(default)]
    summary: String,
    #[serde(default)]
    summary_override: Option<String>,
    #[serde(default)]
    background_color: String,
    #[serde(default)]
    primary: bool,
    #[serde(default)]
    selected: bool,
}

impl ApiCalendar {
    fn into_info(self, overrides: &HashMap<String, bool>) -> CalendarInfo {
        let name = self
            .summary_override
            .filter(|name| !name.is_empty())
            .unwrap_or(if self.summary.is_empty() { self.id.clone() } else { self.summary });
        CalendarInfo {
            enabled: overrides.get(&self.id).copied().unwrap_or(self.selected || self.primary),
            color: self.background_color,
            primary: self.primary,
            name,
            id: self.id,
        }
    }
}

#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ApiEventList {
    #[serde(default)]
    items: Vec<ApiEvent>,
    #[serde(default)]
    next_page_token: Option<String>,
}

#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ApiEvent {
    #[serde(default)]
    id: String,
    #[serde(default)]
    status: String,
    #[serde(default)]
    summary: String,
    #[serde(default)]
    location: String,
    #[serde(default)]
    html_link: String,
    #[serde(default)]
    event_type: String,
    #[serde(default)]
    start: ApiTime,
    #[serde(default)]
    end: ApiTime,
}

#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ApiTime {
    #[serde(default)]
    date: Option<String>,
    #[serde(default)]
    date_time: Option<String>,
}

fn convert_event(item: ApiEvent, calendar: &CalendarInfo) -> Option<Event> {
    // A lemondott peldanyok es a "honnan dolgozom" bejegyzesek nem esemenyek.
    if item.status == "cancelled" || item.event_type == "workingLocation" {
        return None;
    }
    let mut event = Event {
        id: item.id,
        calendar: calendar.id.clone(),
        title: if item.summary.trim().is_empty() {
            "(No title)".to_string()
        } else {
            item.summary
        },
        location: item.location,
        color: calendar.color.clone(),
        link: item.html_link,
        ..Event::default()
    };

    if let Some(start_date) = item.start.date {
        let start_days = parse_date(&start_date)?;
        let end_days = item
            .end
            .date
            .as_deref()
            .and_then(parse_date)
            .filter(|end| *end > start_days)
            .unwrap_or(start_days + 1);
        event.all_day = true;
        event.start_date = format_date(start_days);
        event.end_date = format_date(end_days);
    } else {
        let start = parse_rfc3339_ms(item.start.date_time.as_deref()?)?;
        let end = item
            .end
            .date_time
            .as_deref()
            .and_then(parse_rfc3339_ms)
            .filter(|end| *end >= start)
            .unwrap_or(start);
        event.start = start;
        event.end = end;
    }
    Some(event)
}

/// Rendezesi kulcs: az egesz napos esemenyek a napjuk elejere kerulnek.
fn sort_key(event: &Event) -> i64 {
    if event.all_day {
        parse_date(&event.start_date).map_or(0, |days| days * DAY_MS)
    } else {
        event.start
    }
}

// -- datumok --------------------------------------------------------------------

/// Napok szama 1970-01-01 ota (Howard Hinnant `days_from_civil`).
fn days_from_civil(year: i64, month: i64, day: i64) -> i64 {
    let year = if month <= 2 { year - 1 } else { year };
    let era = year.div_euclid(400);
    let yoe = year - era * 400;
    let mp = (month + 9) % 12;
    let doy = (153 * mp + 2) / 5 + day - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146_097 + doe - 719_468
}

fn civil_from_days(days: i64) -> (i64, i64, i64) {
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let day = doy - (153 * mp + 2) / 5 + 1;
    let month = if mp < 10 { mp + 3 } else { mp - 9 };
    (if month <= 2 { yoe + era * 400 + 1 } else { yoe + era * 400 }, month, day)
}

fn number(text: &str) -> Option<i64> {
    if text.is_empty() || !text.bytes().all(|byte| byte.is_ascii_digit()) {
        return None;
    }
    text.parse().ok()
}

/// "YYYY-MM-DD" -> napok 1970 ota.
fn parse_date(text: &str) -> Option<i64> {
    let mut parts = text.splitn(3, '-');
    let year = number(parts.next()?)?;
    let month = number(parts.next()?)?;
    let day = number(parts.next()?)?;
    if !(1..=12).contains(&month) || !(1..=31).contains(&day) {
        return None;
    }
    Some(days_from_civil(year, month, day))
}

fn format_date(days: i64) -> String {
    let (year, month, day) = civil_from_days(days);
    format!("{year:04}-{month:02}-{day:02}")
}

fn format_rfc3339_utc(epoch_seconds: i64) -> String {
    let days = epoch_seconds.div_euclid(86_400);
    let seconds = epoch_seconds.rem_euclid(86_400);
    format!(
        "{}T{:02}:{:02}:{:02}Z",
        format_date(days),
        seconds / 3600,
        seconds % 3600 / 60,
        seconds % 60
    )
}

/// "2026-10-15T09:30:00+02:00" / "...Z" / tortmasodperccel -> epoch ms.
fn parse_rfc3339_ms(text: &str) -> Option<i64> {
    let (date, rest) = text.split_once(['T', 't'])?;
    let days = parse_date(date)?;

    let zone_at = rest.find(['Z', 'z', '+', '-'])?;
    let (clock, zone) = rest.split_at(zone_at);
    let (clock, fraction) = match clock.split_once('.') {
        Some((clock, fraction)) => (clock, fraction),
        None => (clock, ""),
    };
    let mut fields = clock.splitn(3, ':');
    let hour = number(fields.next()?)?;
    let minute = number(fields.next()?)?;
    let second = number(fields.next()?)?;
    let millis = if fraction.is_empty() {
        0
    } else {
        let digits: String = fraction.chars().chain("000".chars()).take(3).collect();
        number(&digits)?
    };

    let offset_minutes = if zone.eq_ignore_ascii_case("z") {
        0
    } else {
        let sign = if zone.starts_with('-') { -1 } else { 1 };
        let (hours, minutes) = zone[1..].split_once(':')?;
        sign * (number(hours)? * 60 + number(minutes)?)
    };

    let seconds = days * 86_400 + hour * 3600 + minute * 60 + second - offset_minutes * 60;
    Some(seconds * 1000 + millis)
}

fn now_ms() -> i64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map_or(0, |elapsed| elapsed.as_millis() as i64)
}

// -- tarolas --------------------------------------------------------------------

fn string_param(params: &Value, name: &str) -> Result<String> {
    let value = params.get(name).and_then(Value::as_str).map(str::trim).unwrap_or_default();
    if value.is_empty() {
        return Err(ModuleError::invalid_params(format!("'{name}' is required")).into());
    }
    Ok(value.to_string())
}

fn account_path() -> PathBuf {
    paths::state_dir().join("vellum-shell/calendar/google.json")
}

fn client_path() -> PathBuf {
    paths::config_dir().join("vellum-shell/google-oauth.json")
}

fn load_account() -> Option<Account> {
    let text = std::fs::read_to_string(account_path()).ok()?;
    // A fiokfajl leted jelenti a bejelentkezest; maga a token a kulcstarban
    // van (vagy egy regi fajlnal meg itt, atkoltoztetesre varva).
    serde_json::from_str(&text).ok()
}

/// Ures `refresh_token` mellett a token nem kerul a fajlba (lasd `Account`).
fn save_account(account: &Account) -> Result<()> {
    write_private(&account_path(), &serde_json::to_vec_pretty(account)?)
}

/// Az OAuth kliens forrasa, erosorrendben: kornyezeti valtozok, a Settingsben
/// mentett fajl, vegul a build idoben beegetett ertek.
fn oauth_client() -> Option<OAuthClient> {
    let env = |name| std::env::var(name).ok().filter(|value: &String| !value.trim().is_empty());
    if let (Some(client_id), Some(client_secret)) =
        (env("VELLUM_GOOGLE_CLIENT_ID"), env("VELLUM_GOOGLE_CLIENT_SECRET"))
    {
        return Some(OAuthClient { client_id, client_secret });
    }
    if let Some(client) =
        std::fs::read_to_string(client_path()).ok().and_then(|text| parse_client(&text))
    {
        return Some(client);
    }
    match (option_env!("VELLUM_GOOGLE_CLIENT_ID"), option_env!("VELLUM_GOOGLE_CLIENT_SECRET")) {
        (Some(client_id), Some(client_secret))
            if !client_id.is_empty() && !client_secret.is_empty() =>
        {
            Some(OAuthClient {
                client_id: client_id.to_string(),
                client_secret: client_secret.to_string(),
            })
        }
        _ => None,
    }
}

/// A sajat formatum (`clientId`/`clientSecret`) mellett a Google Cloud
/// Console-bol letoltott `client_secret_*.json` is elfogadott, igy az a fajl
/// egyszeruen a helyere masolhato.
fn parse_client(text: &str) -> Option<OAuthClient> {
    let value: Value = serde_json::from_str(text).ok()?;
    let field = |object: &Value, names: [&str; 2]| {
        names
            .iter()
            .find_map(|name| object.get(name).and_then(Value::as_str))
            .map(|value| value.trim().to_string())
            .filter(|value| !value.is_empty())
    };
    let object = value.get("installed").unwrap_or(&value);
    Some(OAuthClient {
        client_id: field(object, ["clientId", "client_id"])?,
        client_secret: field(object, ["clientSecret", "client_secret"])?,
    })
}

fn save_client(client: &OAuthClient) -> Result<()> {
    let data = json!({ "clientId": client.client_id, "clientSecret": client.client_secret });
    write_private(&client_path(), &serde_json::to_vec_pretty(&data)?)
}

/// Atomikus iras csak a tulajdonos szamara olvashato fajlba (0600, mappa 0700).
fn write_private(path: &Path, data: &[u8]) -> Result<()> {
    let parent = path.parent().context("ervenytelen fajlutvonal")?;
    std::fs::DirBuilder::new()
        .recursive(true)
        .mode(0o700)
        .create(parent)
        .with_context(|| format!("{} nem hozhato letre", parent.display()))?;

    let temp = path.with_extension(format!("tmp-{}", std::process::id()));
    let result = (|| -> Result<()> {
        let mut file = std::fs::OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(true)
            .mode(0o600)
            .open(&temp)?;
        file.write_all(data)?;
        file.sync_all()?;
        std::fs::rename(&temp, path)?;
        Ok(())
    })();
    if result.is_err() {
        let _ = std::fs::remove_file(&temp);
    }
    result.with_context(|| format!("{} nem irhato", path.display()))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn calendar() -> CalendarInfo {
        CalendarInfo {
            id: "me@example.com".into(),
            name: "Me".into(),
            color: "#9fe1e7".into(),
            enabled: true,
            primary: true,
        }
    }

    #[test]
    fn civil_dates_round_trip() {
        assert_eq!(days_from_civil(1970, 1, 1), 0);
        assert_eq!(days_from_civil(2000, 3, 1), 11_017);
        for days in [-800_000, -1, 0, 59, 11_016, 20_741, 2_932_896] {
            let (year, month, day) = civil_from_days(days);
            assert_eq!(days_from_civil(year, month, day), days);
        }
        assert_eq!(format_date(days_from_civil(2024, 2, 29) + 1), "2024-03-01");
    }

    #[test]
    fn rfc3339_is_parsed_with_offsets_and_fractions() {
        assert_eq!(parse_rfc3339_ms("1970-01-01T00:00:00Z"), Some(0));
        assert_eq!(parse_rfc3339_ms("1970-01-01T01:00:00+01:00"), Some(0));
        assert_eq!(parse_rfc3339_ms("1969-12-31T19:00:00-05:00"), Some(0));
        assert_eq!(parse_rfc3339_ms("1970-01-01T00:00:01.5Z"), Some(1500));
        assert_eq!(parse_rfc3339_ms("2026-10-15T09:30:00+02:00"), Some(1_792_049_400_000));
        assert_eq!(parse_rfc3339_ms("2026-10-15"), None);
        assert_eq!(parse_rfc3339_ms("szemet"), None);
    }

    #[test]
    fn rfc3339_formatting_is_utc() {
        assert_eq!(format_rfc3339_utc(0), "1970-01-01T00:00:00Z");
        assert_eq!(format_rfc3339_utc(1_792_049_400), "2026-10-15T07:30:00Z");
        assert_eq!(format_rfc3339_utc(-1), "1969-12-31T23:59:59Z");
    }

    #[test]
    fn timed_events_become_epoch_milliseconds() {
        let item: ApiEvent = serde_json::from_value(json!({
            "id": "a1",
            "summary": "Standup",
            "location": "Room 2",
            "htmlLink": "https://www.google.com/calendar/event?eid=a1",
            "start": { "dateTime": "2026-10-15T09:30:00+02:00" },
            "end": { "dateTime": "2026-10-15T09:45:00+02:00" }
        }))
        .unwrap();
        let event = convert_event(item, &calendar()).unwrap();
        assert!(!event.all_day);
        assert_eq!(event.start, 1_792_049_400_000);
        assert_eq!(event.end - event.start, 15 * 60 * 1000);
        assert_eq!(event.title, "Standup");
        assert_eq!(event.color, "#9fe1e7");
        assert_eq!(event.calendar, "me@example.com");
    }

    #[test]
    fn all_day_events_keep_their_local_dates() {
        let item: ApiEvent = serde_json::from_value(json!({
            "id": "h1",
            "start": { "date": "2026-12-24" },
            "end": { "date": "2026-12-27" }
        }))
        .unwrap();
        let event = convert_event(item, &calendar()).unwrap();
        assert!(event.all_day);
        assert_eq!(event.start_date, "2026-12-24");
        assert_eq!(event.end_date, "2026-12-27");
        assert_eq!(event.title, "(No title)");

        // Hianyzo vagy hibas veg: egy napos esemeny.
        let item: ApiEvent =
            serde_json::from_value(json!({ "id": "h2", "start": { "date": "2026-12-31" } }))
                .unwrap();
        assert_eq!(convert_event(item, &calendar()).unwrap().end_date, "2027-01-01");
    }

    #[test]
    fn cancelled_and_working_location_entries_are_skipped() {
        let cancelled: ApiEvent = serde_json::from_value(json!({
            "id": "c", "status": "cancelled", "start": { "date": "2026-01-01" }
        }))
        .unwrap();
        assert!(convert_event(cancelled, &calendar()).is_none());

        let office: ApiEvent = serde_json::from_value(json!({
            "id": "w", "eventType": "workingLocation", "start": { "date": "2026-01-01" }
        }))
        .unwrap();
        assert!(convert_event(office, &calendar()).is_none());
    }

    #[test]
    fn calendar_visibility_prefers_the_local_choice() {
        let api: ApiCalendar = serde_json::from_value(json!({
            "id": "team@group.calendar.google.com",
            "summary": "Team",
            "summaryOverride": "Work",
            "backgroundColor": "#123456",
            "selected": true
        }))
        .unwrap();
        let mut overrides = HashMap::new();
        let info = api.into_info(&overrides);
        assert_eq!(info.name, "Work");
        assert!(info.enabled);

        overrides.insert("holidays".to_string(), true);
        let hidden: ApiCalendar =
            serde_json::from_value(json!({ "id": "holidays", "summary": "Holidays" })).unwrap();
        assert!(hidden.into_info(&overrides).enabled);
    }

    #[test]
    fn callback_query_is_parsed() {
        assert_eq!(
            parse_callback("/?state=abc&code=4%2F0Ab&scope=x"),
            Some(Callback::Code { code: "4/0Ab".into(), state: "abc".into() })
        );
        assert_eq!(
            parse_callback("/?error=access_denied&state=abc"),
            Some(Callback::Denied("access_denied".into()))
        );
        assert_eq!(parse_callback("/favicon.ico"), None);
        assert_eq!(parse_callback("/"), None);
    }

    #[test]
    fn auth_url_carries_pkce_and_offline_access() {
        let url = auth_url("id.apps.googleusercontent.com", "http://127.0.0.1:4242", "ch", "st")
            .unwrap();
        let parsed = Url::parse(&url).unwrap();
        let pairs: HashMap<String, String> = parsed.query_pairs().into_owned().collect();
        assert_eq!(pairs["redirect_uri"], "http://127.0.0.1:4242");
        assert_eq!(pairs["code_challenge_method"], "S256");
        assert_eq!(pairs["access_type"], "offline");
        assert_eq!(pairs["scope"], SCOPE);
    }

    /// RFC 7636 B fuggelek peldaja.
    #[test]
    fn pkce_challenge_matches_the_rfc_example() {
        assert_eq!(
            pkce_challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"),
            "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        );
        assert_eq!(random_token(32).unwrap().len(), 43);
    }

    #[test]
    fn the_account_file_never_carries_an_empty_token() {
        let account = Account { email: "me@example.com".into(), ..Account::default() };
        let text = serde_json::to_string(&account).unwrap();
        assert!(!text.contains("refreshToken"), "{text}");

        // A regi formatum meg olvashato, hogy atkoltoztetheto legyen.
        let legacy: Account =
            serde_json::from_str(r#"{"refreshToken":"1//old","email":"me@example.com"}"#)
                .unwrap();
        assert_eq!(legacy.refresh_token, "1//old");
    }

    #[test]
    fn both_client_file_formats_are_accepted() {
        let own = parse_client(r#"{"clientId":"a.apps.googleusercontent.com","clientSecret":"s"}"#);
        assert_eq!(
            own,
            Some(OAuthClient {
                client_id: "a.apps.googleusercontent.com".into(),
                client_secret: "s".into()
            })
        );
        let downloaded = parse_client(
            r#"{"installed":{"client_id":"b.apps.googleusercontent.com","client_secret":"t"}}"#,
        );
        assert_eq!(downloaded.unwrap().client_id, "b.apps.googleusercontent.com");
        assert_eq!(parse_client(r#"{"clientId":"only-id"}"#), None);
    }
}

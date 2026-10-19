//! Minimalis Secret Service kliens (`org.freedesktop.secrets`).
//!
//! A GNOME Keyring es a KWallet is ezt a D-Bus feluletet adja. Csak annyit
//! tud, amennyi egy token tarolasahoz kell: menteni, megkeresni es torolni egy
//! elemet attributumok alapjan.
//!
//! A titok a "plain" munkamenettel utazik. Ez a munkamenet-buszon megy, amit
//! csak a felhasznalo sajat folyamatai ernek el; a kulcstar maga titkositva
//! tarolja a lemezen.
//!
//! A zarolt kulcstar feloldasa jelszokerest nyit (pl. gcr-prompter). Ezt csak
//! akkor engedjuk, ha a hivo `interactive` -- a hatterben futo szinkron ne
//! dobjon fel varatlanul ablakot.

use crate::dbus;
use anyhow::{Context, Result, anyhow};
use futures_util::StreamExt;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::time::Duration;
use zbus::Connection;
use zbus::zvariant::{ObjectPath, OwnedObjectPath, OwnedValue, Type, Value};

/// Ennyit varunk, hogy a felhasznalo beirja a kulcstar jelszavat.
const PROMPT_TIMEOUT: Duration = Duration::from_secs(120);

#[derive(Debug, thiserror::Error)]
pub enum SecretError {
    #[error("no keyring is available (install and start gnome-keyring or KWallet)")]
    Unavailable,
    #[error("the keyring is locked")]
    Locked,
    #[error("unlocking the keyring was cancelled")]
    Dismissed,
}

#[derive(Debug, Serialize, Deserialize, Type)]
struct Secret {
    session: OwnedObjectPath,
    parameters: Vec<u8>,
    value: Vec<u8>,
    content_type: String,
}

#[zbus::proxy(
    interface = "org.freedesktop.Secret.Service",
    default_service = "org.freedesktop.secrets",
    default_path = "/org/freedesktop/secrets"
)]
trait Service {
    fn open_session(
        &self,
        algorithm: &str,
        input: &Value<'_>,
    ) -> zbus::Result<(OwnedValue, OwnedObjectPath)>;

    fn search_items(
        &self,
        attributes: HashMap<&str, &str>,
    ) -> zbus::Result<(Vec<OwnedObjectPath>, Vec<OwnedObjectPath>)>;

    fn unlock(
        &self,
        objects: &[ObjectPath<'_>],
    ) -> zbus::Result<(Vec<OwnedObjectPath>, OwnedObjectPath)>;

    fn get_secrets(
        &self,
        items: &[ObjectPath<'_>],
        session: &ObjectPath<'_>,
    ) -> zbus::Result<HashMap<OwnedObjectPath, Secret>>;

    fn read_alias(&self, name: &str) -> zbus::Result<OwnedObjectPath>;
}

#[zbus::proxy(interface = "org.freedesktop.Secret.Collection", default_service = "org.freedesktop.secrets")]
trait Collection {
    fn create_item(
        &self,
        properties: HashMap<&str, Value<'_>>,
        secret: &Secret,
        replace: bool,
    ) -> zbus::Result<(OwnedObjectPath, OwnedObjectPath)>;

    #[zbus(property)]
    fn locked(&self) -> zbus::Result<bool>;
}

#[zbus::proxy(interface = "org.freedesktop.Secret.Item", default_service = "org.freedesktop.secrets")]
trait Item {
    fn delete(&self) -> zbus::Result<OwnedObjectPath>;
}

#[zbus::proxy(interface = "org.freedesktop.Secret.Session", default_service = "org.freedesktop.secrets")]
trait Session {
    fn close(&self) -> zbus::Result<()>;
}

#[zbus::proxy(interface = "org.freedesktop.Secret.Prompt", default_service = "org.freedesktop.secrets")]
trait Prompt {
    fn prompt(&self, window_id: &str) -> zbus::Result<()>;

    #[zbus(signal)]
    fn completed(&self, dismissed: bool, result: OwnedValue) -> zbus::Result<()>;
}

/// Kapcsolat es szolgaltatas. Ha nincs kulcstar, ez `Unavailable`.
async fn service() -> Result<(Connection, ServiceProxy<'static>)> {
    let connection = dbus::session().await.map_err(|_| SecretError::Unavailable)?;
    let service = ServiceProxy::new(&connection).await.map_err(|_| SecretError::Unavailable)?;
    Ok((connection, service))
}

/// Elmenti (vagy azonos attributumokkal felulirja) a titkot az alapertelmezett
/// kulcstarban.
pub async fn store(
    label: &str,
    attributes: &[(&str, &str)],
    secret: &[u8],
    interactive: bool,
) -> Result<()> {
    let (connection, service) = service().await?;
    let collection_path = service
        .read_alias("default")
        .await
        .map_err(|_| SecretError::Unavailable)?;
    if collection_path.as_str() == "/" {
        return Err(SecretError::Unavailable.into());
    }

    let collection = CollectionProxy::builder(&connection)
        .path(collection_path.clone())?
        .build()
        .await?;
    if collection.locked().await.unwrap_or(true) {
        unlock(&connection, &service, &[collection_path.as_ref()], interactive).await?;
    }

    let session = open_session(&service).await?;
    let attributes: HashMap<&str, &str> = attributes.iter().copied().collect();
    let properties = HashMap::from([
        ("org.freedesktop.Secret.Item.Label", Value::from(label)),
        ("org.freedesktop.Secret.Item.Attributes", Value::from(attributes)),
    ]);
    let secret = Secret {
        session: session.clone(),
        parameters: Vec::new(),
        value: secret.to_vec(),
        content_type: "text/plain".to_string(),
    };
    let created = collection.create_item(properties, &secret, true).await;
    close_session(&connection, session).await;

    let (_, prompt) = created.context("a titok nem mentheto a kulcstarba")?;
    run_prompt(&connection, prompt, interactive).await
}

/// Az elso illeszkedo elem titka; `None`, ha nincs ilyen elem.
pub async fn lookup(attributes: &[(&str, &str)], interactive: bool) -> Result<Option<Vec<u8>>> {
    let (connection, service) = service().await?;
    let search: HashMap<&str, &str> = attributes.iter().copied().collect();
    let (unlocked, locked) =
        service.search_items(search).await.map_err(|_| SecretError::Unavailable)?;

    let item = match (unlocked.into_iter().next(), locked.into_iter().next()) {
        (Some(item), _) => item,
        (None, Some(item)) => {
            unlock(&connection, &service, &[item.as_ref()], interactive).await?;
            item
        }
        (None, None) => return Ok(None),
    };

    let session = open_session(&service).await?;
    let secrets = service.get_secrets(&[item.as_ref()], &session.as_ref()).await;
    close_session(&connection, session).await;

    let secrets = secrets.context("a titok nem olvashato a kulcstarbol")?;
    Ok(secrets.into_values().next().map(|secret| secret.value))
}

/// Minden illeszkedo elem torlese. A zarolt elemekhez feloldas kell.
pub async fn delete(attributes: &[(&str, &str)], interactive: bool) -> Result<()> {
    let (connection, service) = service().await?;
    let search: HashMap<&str, &str> = attributes.iter().copied().collect();
    let (unlocked, locked) =
        service.search_items(search).await.map_err(|_| SecretError::Unavailable)?;

    if !locked.is_empty() {
        let paths: Vec<ObjectPath<'_>> = locked.iter().map(|path| path.as_ref()).collect();
        unlock(&connection, &service, &paths, interactive).await?;
    }
    for path in unlocked.iter().chain(locked.iter()) {
        let item = ItemProxy::builder(&connection).path(path.clone())?.build().await?;
        let prompt = item.delete().await.context("a kulcstar elem nem torolheto")?;
        run_prompt(&connection, prompt, interactive).await?;
    }
    Ok(())
}

async fn open_session(service: &ServiceProxy<'_>) -> Result<OwnedObjectPath> {
    let (_, session) = service
        .open_session("plain", &Value::from(""))
        .await
        .context("nem nyithato munkamenet a kulcstarral")?;
    Ok(session)
}

/// A munkamenet a kapcsolat bontasakor amugy is bezarul, de a kozos
/// kapcsolat a daemon teljes eletideje alatt el.
async fn close_session(connection: &Connection, session: OwnedObjectPath) {
    if let Ok(builder) = SessionProxy::builder(connection).path(session)
        && let Ok(proxy) = builder.build().await
    {
        let _ = proxy.close().await;
    }
}

async fn unlock(
    connection: &Connection,
    service: &ServiceProxy<'_>,
    objects: &[ObjectPath<'_>],
    interactive: bool,
) -> Result<()> {
    if !interactive {
        return Err(SecretError::Locked.into());
    }
    let (_, prompt) = service.unlock(objects).await.context("a kulcstar nem oldhato fel")?;
    run_prompt(connection, prompt, interactive).await
}

/// Lefuttat egy kulcstar-kerest (pl. jelszoablak), ha a szolgaltatas kert
/// ilyet. A "/" utvonal azt jelenti, hogy nincs szukseg kerdesre.
async fn run_prompt(connection: &Connection, path: OwnedObjectPath, interactive: bool) -> Result<()> {
    if path.as_str() == "/" {
        return Ok(());
    }
    if !interactive {
        return Err(SecretError::Locked.into());
    }

    let prompt = PromptProxy::builder(connection).path(path)?.build().await?;
    // Elobb iratkozunk fel, aztan inditjuk: igy a gyors valasz sem veszhet el.
    let mut completed = prompt.receive_completed().await?;
    prompt.prompt("").await.context("a kulcstar jelszokerese nem indithato")?;

    let signal = tokio::time::timeout(PROMPT_TIMEOUT, completed.next())
        .await
        .map_err(|_| SecretError::Dismissed)?
        .ok_or_else(|| anyhow!("a kulcstar kerese megszakadt"))?;
    if *signal.args()?.dismissed() {
        return Err(SecretError::Dismissed.into());
    }
    Ok(())
}

//! Kozos logind (org.freedesktop.login1) proxyk.
//!
//! A `session` modul az alvast es a zarolasi kereseket figyeli, a `brightness`
//! modul a munkamenet `SetBrightness` metodusaval allit fenyerot -- mindketto
//! a felhasznalo grafikus munkamenetet hasznalja.

use anyhow::{Result, anyhow};
use zbus::zvariant::OwnedObjectPath;

#[zbus::proxy(
    interface = "org.freedesktop.login1.Manager",
    default_service = "org.freedesktop.login1",
    default_path = "/org/freedesktop/login1"
)]
pub trait LoginManager {
    fn inhibit(
        &self,
        what: &str,
        who: &str,
        why: &str,
        mode: &str,
    ) -> zbus::Result<zbus::zvariant::OwnedFd>;

    fn get_user(&self, uid: u32) -> zbus::Result<OwnedObjectPath>;

    #[zbus(signal)]
    fn prepare_for_sleep(&self, start: bool) -> zbus::Result<()>;
}

#[zbus::proxy(
    interface = "org.freedesktop.login1.User",
    default_service = "org.freedesktop.login1"
)]
pub trait LoginUser {
    /// A felhasznalo grafikus munkamenete: (azonosito, objektumutvonal).
    #[zbus(property)]
    fn display(&self) -> zbus::Result<(String, OwnedObjectPath)>;
}

#[zbus::proxy(
    interface = "org.freedesktop.login1.Session",
    default_service = "org.freedesktop.login1"
)]
pub trait LoginSession {
    fn set_locked_hint(&self, locked: bool) -> zbus::Result<()>;

    fn set_brightness(&self, subsystem: &str, name: &str, brightness: u32) -> zbus::Result<()>;

    #[zbus(signal)]
    fn lock(&self) -> zbus::Result<()>;
}

/// A felhasznalo grafikus munkamenete.
///
/// A daemon user service-kent fut, nem a munkamenet scope-jaban, ezert a
/// `session/auto` utvonal nem mukodne: a munkamenetet a logind `User.Display`
/// adja meg.
pub async fn graphical_session(
    connection: &zbus::Connection,
    manager: &LoginManagerProxy<'_>,
) -> Result<LoginSessionProxy<'static>> {
    // SAFETY: a getuid() mindig sikeres es nincs mellekhatasa.
    let uid = unsafe { libc::getuid() };
    let user_path = manager.get_user(uid).await?;
    let user = LoginUserProxy::builder(connection).path(user_path)?.build().await?;
    let (_, session_path) = user.display().await?;
    if session_path.as_str() == "/" {
        return Err(anyhow!("nincs grafikus munkamenet"));
    }
    Ok(LoginSessionProxy::builder(connection).path(session_path)?.build().await?)
}

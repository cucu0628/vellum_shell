//! Tema modul: a paletta mint topic, plusz a temavaltas mint parancs.
//!
//! Ez valtja ki az `AppearanceController.applyScene()` ~9 bash scriptes lancat
//! es a `ThemeStore` kezi szovegparse-olasat.

use crate::module::{MethodDescription, Module, ModuleDescription, ModuleError, StateSink};
use crate::theme;
use anyhow::Result;
use async_trait::async_trait;
use serde_json::{Value, json};
use std::sync::Arc;

pub struct Theme {
    /// A temat modosito muveletek sorbaallitasa.
    ///
    /// Az `apply` es a `setWallpaper` ugyanazokat az allapotfajlokat es
    /// generalt kimeneteket irja. Parhuzamosan futva ket temavaltas
    /// osszekeveredhet: az egyik palettajaval generalt fajlok mellett a masik
    /// slugja maradna bejegyezve.
    mutation: tokio::sync::Mutex<()>,
}

impl Default for Theme {
    fn default() -> Self {
        Self::new()
    }
}

impl Theme {
    pub fn new() -> Self {
        Self { mutation: tokio::sync::Mutex::new(()) }
    }

    /// A topic tartalma: az aktiv paletta minden kulcsa, plusz a slug es a
    /// hatterkep. A QML igy nem 6 szinre van korlatozva, mint korabban.
    fn snapshot() -> Value {
        let slug = theme::current_slug();
        let palette = match slug.as_deref() {
            Some(slug) => theme::load(slug).ok(),
            None => None,
        };

        json!({
            "slug": slug,
            "wallpaper": theme::paths::read_line_file(&theme::paths::current_wallpaper_file()),
            "colors": palette.map(|palette| palette.to_json()).unwrap_or_default(),
        })
    }
}

#[async_trait]
impl Module for Theme {
    fn name(&self) -> &'static str {
        "theme"
    }

    fn describe(&self) -> ModuleDescription {
        ModuleDescription {
            topic: "theme",
            summary: "Az aktiv paletta, a tema slugja es a hatterkep.",
            streams: true,
            methods: vec![
                MethodDescription::new("list", "Az osszes valaszthato tema osszefoglaloja."),
                MethodDescription::new("read", "Az aktiv paletta osszes kulcsa."),
                MethodDescription::new("apply", "Tema (es opcionalisan hatterkep) alkalmazasa.")
                    .param("slug", "string", true, "A tema mappajanak neve.")
                    .param("wallpaper", "string", false, "A hatterkep teljes utvonala.")
                    .param("zen", "bool", false, "Patchelje-e a Zen Browser profilt is."),
                MethodDescription::new("setWallpaper", "Csak a hatterkep valtoztatasa.").param(
                    "path",
                    "string",
                    true,
                    "A hatterkep teljes utvonala.",
                ),
                MethodDescription::new("wallpapers", "A valaszthato hatterkepek listaja."),
                MethodDescription::new(
                    "preview",
                    "A hatterkepbol szarmaztatott paletta, alkalmazas nelkul.",
                )
                .param("wallpaper", "string", true, "A hatterkep teljes utvonala."),
            ],
        }
    }

    async fn run(self: Arc<Self>, sink: StateSink) -> Result<()> {
        sink.push(Self::snapshot());
        // Nincs mit pollozni: a valtozast mindig a sajat `apply` parancsunk
        // valtja ki, es az maga tolja ki az uj allapotot.
        std::future::pending::<()>().await;
        Ok(())
    }

    async fn call(self: Arc<Self>, method: &str, params: Value, sink: &StateSink) -> Result<Value> {
        match method {
            "list" => Ok(json!(theme::list())),

            "read" => Ok(Self::snapshot()),

            "apply" => {
                let slug = params
                    .get("slug")
                    .and_then(Value::as_str)
                    .ok_or_else(|| ModuleError::invalid_params("hianyzik a 'slug'"))?;
                let wallpaper = params.get("wallpaper").and_then(Value::as_str);
                let zen = params.get("zen").and_then(Value::as_bool).unwrap_or(true);

                // A generatorok fajlrendszert es kulso parancsokat hasznalnak,
                // ezert blokkolo szalra tesszuk -- kulonben megallitanak a
                // daemon egyszalu futtatojat.
                let slug = slug.to_string();
                let wallpaper = wallpaper.map(str::to_string);
                let _mutation = self.mutation.lock().await;
                let report = tokio::task::spawn_blocking(move || {
                    theme::apply(&slug, wallpaper.as_deref(), zen)
                })
                .await??;

                sink.push(Self::snapshot());
                Ok(json!(report))
            }

            "setWallpaper" => {
                let path = params
                    .get("path")
                    .and_then(Value::as_str)
                    .ok_or_else(|| ModuleError::invalid_params("hianyzik a 'path'"))?;
                let _mutation = self.mutation.lock().await;
                theme::set_wallpaper(path)?;
                sink.push(Self::snapshot());
                Ok(json!({ "wallpaper": path }))
            }

            "wallpapers" => Ok(json!(theme::wallpapers())),

            // Csak olvas: a valaszto ezzel mutatja meg a dinamikus palettat,
            // mielott barmit is kiirnank a lemezre.
            "preview" => {
                let wallpaper = params
                    .get("wallpaper")
                    .and_then(Value::as_str)
                    .ok_or_else(|| ModuleError::invalid_params("hianyzik a 'wallpaper'"))?
                    .to_string();

                // A kvantalas nagy kepeknel szazezer pixelt olvas: blokkolo szal.
                let palette =
                    tokio::task::spawn_blocking(move || theme::preview_dynamic(&wallpaper))
                        .await??;

                Ok(json!({ "colors": palette.to_json() }))
            }

            other => Err(ModuleError::UnknownMethod(other.to_string()).into()),
        }
    }
}

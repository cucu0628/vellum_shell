//! Vellum Shell backend.
//!
//! Egy binaris, ket szerepben:
//!   * `vellum daemon` -- rezidens szolgaltatas Unix socketen;
//!   * `vellum describe|call|watch|ping` -- CLI kliens, ami ugyanahhoz a
//!     sockethez beszel. Igy a Hyprland bindings es a setup.sh scriptelheto
//!     marad, es egy jovobeli settings app is ugyanezt a feluletet hasznalja.

use anyhow::Result;
use clap::{Parser, Subcommand};
use serde_json::{Value, json};
use std::path::PathBuf;
use vellum_shell_backend::ipc;
use vellum_shell_backend::ipc::client::Client;
use vellum_shell_backend::ipc::hub::Hub;
use vellum_shell_backend::modules;
use vellum_shell_backend::theme;

#[derive(Parser)]
#[command(name = "vellum", version, about = "Vellum Shell backend")]
struct Cli {
    /// A socket utvonala (alapertelmezes: $XDG_RUNTIME_DIR/vellum-shell.sock).
    #[arg(long, global = true)]
    socket: Option<PathBuf>,

    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// A rezidens daemon inditasa.
    Daemon,
    /// Kiirja az elerheto topicokat es metodusokat (a kliensek szerzodese).
    Describe,
    /// Meghiv egy metodust, pl. `vellum call theme apply '{"slug":"rose-pine"}'`.
    Call {
        domain: String,
        method: String,
        /// JSON objektum parameterekkel.
        #[arg(default_value = "{}")]
        params: String,
    },
    /// Feliratkozik topicokra es a stdoutra irja az erkezo eventeket.
    Watch {
        #[arg(required = true)]
        topics: Vec<String>,
    },
    /// Gyors ellenorzes, hogy fut-e a daemon.
    Ping,
    /// Tema-muveletek. Daemon nelkul is mukodnek (a setup bootstrapjahoz), de
    /// ha fut a daemon, rajta keresztul mennek -- kulonben a shell nem ertesulne
    /// a valtozasrol es elavult szineket mutatna.
    #[command(subcommand)]
    Theme(ThemeCommand),
}

#[derive(Subcommand)]
enum ThemeCommand {
    /// Az elerheto temak listaja.
    List,
    /// Az aktiv paletta.
    Read,
    /// Tema alkalmazasa, az osszes generator lefuttatasaval.
    Apply {
        slug: String,
        /// A hatterkep teljes utvonala.
        #[arg(long)]
        wallpaper: Option<String>,
        /// Ne patchelje a Zen Browser profiljat.
        #[arg(long)]
        no_zen: bool,
    },
}

fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_env("VELLUM_LOG")
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info")),
        )
        .with_writer(std::io::stderr)
        .init();

    let cli = Cli::parse();
    let socket = cli.socket.unwrap_or_else(ipc::socket_path);

    keep_large_buffers_off_the_heap();

    // Egyszalu futtato: a munka I/O-kotott, nincs szukseg tobb szalra. Ez tartja
    // alacsonyan a memoria- es CPU-lenyomatot.
    let runtime = tokio::runtime::Builder::new_current_thread().enable_all().build()?;

    runtime.block_on(async move {
        match cli.command {
            Command::Daemon => run_daemon(&socket).await,
            Command::Describe => {
                let data = Client::connect(&socket).await?.describe().await?;
                println!("{}", serde_json::to_string_pretty(&data)?);
                Ok(())
            }
            Command::Call { domain, method, params } => {
                let params: Value = serde_json::from_str(&params)
                    .map_err(|err| anyhow::anyhow!("a params nem ervenyes JSON: {err}"))?;
                let data = Client::connect(&socket).await?.call(&domain, &method, params).await?;
                println!("{}", serde_json::to_string_pretty(&data)?);
                Ok(())
            }
            Command::Watch { topics } => Client::connect(&socket).await?.watch(&topics).await,
            Command::Ping => {
                let data =
                    Client::connect(&socket).await?.call("health", "ping", Value::Null).await?;
                println!("{}", serde_json::to_string_pretty(&data)?);
                Ok(())
            }
            Command::Theme(command) => run_theme(&socket, command).await,
        }
    })
}

/// A hatterkep-kvantalas egy-egy keptol fuggoen tobb tiz MB-ot foglal, majd
/// azonnal el is engedi. A glibc viszont menet kozben megemeli az `mmap`
/// kuszobot, ezert ezek a nagy blokkok a heapen kotnek ki, es a felszabaditas
/// utan sem kerulnek vissza az OS-hez: a daemon RSS-e beragad a csucsertekre
/// (merve: 19 MB -> 78 MB harom elonezet utan).
///
/// A kuszob rogzitesevel a nagy foglalasok vegig `mmap`-pal mennek, es
/// `free`-kor tenylegesen visszakerulnek. A daemon tobbi foglalasa jóval a
/// kuszob alatt van, azokat ez nem erinti.
fn keep_large_buffers_off_the_heap() {
    // SAFETY: `mallopt` a folyamat allokatorat allitja; a hivas szalbiztos, es
    // itt meg egyetlen munkaszal sem indult el.
    unsafe {
        libc::mallopt(libc::M_MMAP_THRESHOLD, 1024 * 1024);
    }
}

/// Eloszor a daemont probaljuk: ha fut, o vegzi el a munkat es azonnal ki is
/// tolja az uj allapotot a shellnek. Ha nem fut (pl. a setup elso futasakor),
/// helyben futtatjuk ugyanazt a kodot.
async fn run_theme(socket: &std::path::Path, command: ThemeCommand) -> Result<()> {
    type Local = Box<dyn FnOnce() -> Result<Value>>;

    let (method, params, local): (&str, Value, Local) = match command {
        ThemeCommand::List => ("list", Value::Null, Box::new(|| Ok(json!(theme::list())))),

        ThemeCommand::Read => (
            "read",
            Value::Null,
            Box::new(|| {
                Ok(json!({
                    "slug": theme::current_slug(),
                    "colors": theme::load_current()?.to_json(),
                }))
            }),
        ),

        ThemeCommand::Apply { slug, wallpaper, no_zen } => {
            let params = json!({ "slug": slug, "wallpaper": wallpaper, "zen": !no_zen });
            (
                "apply",
                params,
                Box::new(move || Ok(json!(theme::apply(&slug, wallpaper.as_deref(), !no_zen)?))),
            )
        }
    };

    let data = match Client::connect(socket).await {
        Ok(mut client) => client.call("theme", method, params).await?,
        Err(_) => {
            tracing::debug!("nem fut daemon, helyben futtatjuk");
            local()?
        }
    };

    println!("{}", serde_json::to_string_pretty(&data)?);
    Ok(())
}

async fn run_daemon(socket: &std::path::Path) -> Result<()> {
    let hub = Hub::new(modules::registry());
    let socket = socket.to_path_buf();

    let server = {
        let hub = std::sync::Arc::clone(&hub);
        let socket = socket.clone();
        tokio::spawn(async move { ipc::server::listen(hub, &socket).await })
    };

    // Rendezett leallas, hogy ne maradjon arva socket-fajl.
    tokio::select! {
        result = server => {
            result??;
        }
        _ = shutdown_signal() => {
            tracing::info!("leallitasi jelzes, kilepes");
        }
    }

    let _ = std::fs::remove_file(&socket);
    Ok(())
}

async fn shutdown_signal() {
    use tokio::signal::unix::{SignalKind, signal};
    let mut term = match signal(SignalKind::terminate()) {
        Ok(signal) => signal,
        Err(_) => return std::future::pending().await,
    };
    tokio::select! {
        _ = tokio::signal::ctrl_c() => {}
        _ = term.recv() => {}
    }
}

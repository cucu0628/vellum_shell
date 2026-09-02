//! A forditasba beleegeti a git reviziot, hogy futas kozben ellenorizheto
//! legyen, a telepitett binaris melyik allapotbol keszult.
//!
//! Ha nincs git (pl. forrasarchivumbol epitve), a revizio "unknown" -- ez nem
//! hiba, csak annyit jelent, hogy nem tudjuk megmondani.

use std::process::Command;

fn main() {
    // Ujraforditas, ha a HEAD vagy az index valtozik. E nelkul egy commit utan
    // a beegetett revizio csendben elavulna.
    for path in ["../.git/HEAD", "../.git/index"] {
        if std::path::Path::new(path).exists() {
            println!("cargo:rerun-if-changed={path}");
        }
    }

    let revision = Command::new("git")
        .args(["rev-parse", "--short", "HEAD"])
        .output()
        .ok()
        .filter(|output| output.status.success())
        .and_then(|output| String::from_utf8(output.stdout).ok())
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| "unknown".to_string());

    // A "-dirty" jelzi, ha a binaris nem egy tiszta commitbol keszult.
    let dirty = Command::new("git")
        .args(["status", "--porcelain", "--untracked-files=no"])
        .output()
        .ok()
        .filter(|output| output.status.success())
        .is_some_and(|output| !output.stdout.is_empty());

    let revision = if dirty { format!("{revision}-dirty") } else { revision };
    println!("cargo:rustc-env=VELLUM_REVISION={revision}");
}

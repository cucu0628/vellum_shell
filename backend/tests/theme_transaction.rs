//! A temaalkalmazas tranzakcios viselkedese.
//!
//! Egyetlen tesztfuggveny, mint a `golden.rs`-ben: a HOME es a
//! VELLUM_SHELL_DIR processz-szintu, ezert parhuzamos tesztek egymas alol
//! huznak ki oket. Kulon integracios fajl viszont kulon processz, tehat a
//! golden teszttel nem utkozik.

use std::path::{Path, PathBuf};
use vellum_shell_backend::theme;

fn repo_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).parent().unwrap().to_path_buf()
}

struct Sandbox {
    root: PathBuf,
    shell_dir: PathBuf,
}

impl Sandbox {
    fn new() -> Self {
        let root = std::env::temp_dir().join(format!("vellum-theme-tx-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        let shell_dir = root.join(".config/quickshell/vellum_shell");
        std::fs::create_dir_all(&shell_dir).unwrap();

        let repo = repo_root();
        copy_dir(&repo.join("themes"), &shell_dir.join("themes"));
        copy_dir(&repo.join("assets"), &shell_dir.join("assets"));
        copy_dir(&repo.join("backend/templates"), &shell_dir.join("backend/templates"));

        // SAFETY: egyetlen teszt fut ebben a processzben, nincs parhuzamos
        // szal, ami kozben olvasna a kornyezetet.
        unsafe {
            std::env::set_var("HOME", &root);
            std::env::set_var("XDG_CONFIG_HOME", root.join(".config"));
            std::env::set_var("VELLUM_SHELL_DIR", &shell_dir);
            std::env::set_var("VELLUM_NO_SIDE_EFFECTS", "1");
        }

        Self { root, shell_dir }
    }

    fn current_theme(&self) -> Option<String> {
        std::fs::read_to_string(self.shell_dir.join("current-theme"))
            .ok()
            .map(|text| text.trim().to_string())
    }

    fn current_wallpaper(&self) -> Option<String> {
        std::fs::read_to_string(self.shell_dir.join("current-wallpaper"))
            .ok()
            .map(|text| text.trim().to_string())
    }

    /// Egy letezo kepfajl, amit hatterkepnek adhatunk at.
    fn wallpaper(&self) -> PathBuf {
        let path = self.root.join("wallpaper.png");
        // 1x1 PNG: a statikus temahoz nem kell dekodolni, csak leteznie kell.
        std::fs::write(&path, PNG_1X1).unwrap();
        path
    }
}

impl Drop for Sandbox {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.root);
    }
}

const PNG_1X1: &[u8] = &[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
];

fn copy_dir(from: &Path, to: &Path) {
    std::fs::create_dir_all(to).unwrap();
    let Ok(entries) = std::fs::read_dir(from) else {
        return;
    };
    for entry in entries.flatten() {
        let target = to.join(entry.file_name());
        if entry.path().is_dir() {
            copy_dir(&entry.path(), &target);
        } else {
            std::fs::copy(entry.path(), target).unwrap();
        }
    }
}

#[test]
fn apply_commits_state_only_after_the_theme_really_landed() {
    let sandbox = Sandbox::new();
    let wallpaper = sandbox.wallpaper();
    let wallpaper = wallpaper.to_str().unwrap();

    // -- 1. A sikeres alkalmazas rogziti az allapotot -------------------------
    let report = theme::apply("rose-pine", Some(wallpaper), false).expect("az alkalmazas bukott");
    assert_eq!(report.slug, "rose-pine");
    assert_eq!(sandbox.current_theme().as_deref(), Some("rose-pine"));
    assert_eq!(sandbox.current_wallpaper().as_deref(), Some(wallpaper));

    // A kotelezo generatorok mind lefutottak.
    assert!(
        report
            .generators
            .iter()
            .any(|outcome| outcome.generator == "kitty" && !outcome.is_failure()),
        "{:?}",
        report.generators
    );

    // -- 2. Ismeretlen tema: nem irunk allapotot ------------------------------
    let err = theme::apply("nincs-ilyen-tema", None, false).unwrap_err();
    assert!(err.to_string().contains("ismeretlen tema"), "{err}");
    assert_eq!(
        sandbox.current_theme().as_deref(),
        Some("rose-pine"),
        "az elutasitott temavaltas atirta az allapotot"
    );

    // -- 3. Nem letezo hatterkep: mar az ervenyesitesnel elbukik --------------
    let err = theme::apply("tokyo-night", Some("/nincs/ilyen/kep.png"), false).unwrap_err();
    assert!(err.to_string().contains("nem letezik"), "{err}");
    assert_eq!(
        sandbox.current_theme().as_deref(),
        Some("rose-pine"),
        "a hibas hatterkep utan is atirodott a tema"
    );
    assert_eq!(sandbox.current_wallpaper().as_deref(), Some(wallpaper));

    // -- 4. Kotelezo generator hibaja megallitja a commitot -------------------
    // A hyprland generator a ~/.config/hypr ala ir. Ha ott egy fajl all a mappa
    // helyen, a kiiras elbukik -- ez a "sajat fajlunkat nem tudtuk kiirni" eset.
    let hypr_dir = sandbox.root.join(".config/hypr");
    let _ = std::fs::remove_dir_all(&hypr_dir);
    std::fs::write(&hypr_dir, "nem mappa").unwrap();

    let err = theme::apply("kanagawa-wave", None, false).unwrap_err();
    assert!(err.to_string().contains("nem alkalmazhato"), "{err}");
    assert_eq!(
        sandbox.current_theme().as_deref(),
        Some("rose-pine"),
        "kotelezo generatorhiba utan is bejegyzodott az uj tema"
    );

    // -- 5. A gat feloldasa utan ugyanaz a valtas mar atmegy ------------------
    std::fs::remove_file(&hypr_dir).unwrap();
    theme::apply("kanagawa-wave", None, false).expect("a javitas utan is bukott");
    assert_eq!(sandbox.current_theme().as_deref(), Some("kanagawa-wave"));
    // Hatterkep nelkuli valtas nem nyul a hatterkephez.
    assert_eq!(sandbox.current_wallpaper().as_deref(), Some(wallpaper));
}

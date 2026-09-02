//! Golden teszt: a Rust generatorok kimenetenek byte-ra egyeznie kell a
//! korabbi bash scriptekevel.
//!
//! A baseline-t a `backend/tests/capture-golden.sh` rogzitette meg a migracio
//! elott, egy homokozo HOME-ban. Ez a teszt ugyanolyan homokozoban futtatja a
//! Rust valtozatot, es osszeveti a ket kimenetet.
//!
//! Egyetlen teszfuggveny, mert a HOME/VELLUM_SHELL_DIR kornyezeti valtozok
//! processz-szintuek -- parhuzamos tesztek egymas alol huznak ki oket.

use std::path::{Path, PathBuf};
use vellum_shell_backend::theme::generators;
use vellum_shell_backend::theme::palette::Palette;

fn repo_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).parent().unwrap().to_path_buf()
}

fn golden_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/golden")
}

/// Homokozo HOME, amiben a generatorok futhatnak anelkul, hogy az eles
/// konfiguraciohoz nyulnanak.
struct Sandbox {
    root: PathBuf,
    shell_dir: PathBuf,
}

impl Sandbox {
    fn new() -> Self {
        let root = std::env::temp_dir().join(format!("vellum-golden-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        let shell_dir = root.join(".config/quickshell/vellum_shell");
        std::fs::create_dir_all(shell_dir.join("sddm/vellum-ink")).unwrap();

        let repo = repo_root();
        copy_dir(&repo.join("themes"), &shell_dir.join("themes"));
        copy_dir(&repo.join("assets"), &shell_dir.join("assets"));
        copy_dir(&repo.join("backend/templates"), &shell_dir.join("backend/templates"));
        if let Ok(monitor) = std::fs::read_to_string(repo.join("lockscreen-monitor")) {
            std::fs::write(shell_dir.join("lockscreen-monitor"), monitor).unwrap();
        }

        // SAFETY: egyetlen teszt fut, nincs parhuzamos szal, ami olvasna oket.
        unsafe {
            std::env::set_var("HOME", &root);
            std::env::set_var("XDG_CONFIG_HOME", root.join(".config"));
            std::env::set_var("VELLUM_SHELL_DIR", &shell_dir);
            std::env::set_var("VELLUM_NO_SIDE_EFFECTS", "1");
        }

        Self { root, shell_dir }
    }

    /// Torli az elozo futas kimeneteit, hogy a "nem irt semmit" eset is latszodjon.
    fn reset_outputs(&self) {
        for path in [
            self.shell_dir.join("kitty-theme.conf"),
            self.shell_dir.join("gtk-theme.css"),
            self.shell_dir.join("zen-theme.css"),
            self.shell_dir.join("zen-content-theme.css"),
            self.shell_dir.join("sddm/vellum-ink/theme.conf"),
        ] {
            let _ = std::fs::remove_file(path);
        }
        for dir in ["hypr", "btop", "fastfetch"] {
            let _ = std::fs::remove_dir_all(self.root.join(".config").join(dir));
        }
    }
}

impl Drop for Sandbox {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.root);
    }
}

fn copy_dir(from: &Path, to: &Path) {
    std::fs::create_dir_all(to).unwrap();
    for entry in std::fs::read_dir(from).unwrap().flatten() {
        let target = to.join(entry.file_name());
        if entry.path().is_dir() {
            copy_dir(&entry.path(), &target);
        } else {
            std::fs::copy(entry.path(), target).unwrap();
        }
    }
}

/// A golden `.calls` fajlbol kiolvassa, melyik ikontemat allitotta be a bash.
fn expected_icon_theme(golden: &Path) -> Option<String> {
    let calls = std::fs::read_to_string(golden.join("icon-theme.calls")).ok()?;
    calls
        .lines()
        .find(|line| line.starts_with("gsettings set org.gnome.desktop.interface icon-theme "))
        .and_then(|line| line.rsplit(' ').next())
        .map(str::to_string)
}

#[test]
fn generators_match_bash_baseline() {
    let sandbox = Sandbox::new();
    let repo = repo_root();
    let golden_root = golden_dir();

    assert!(
        golden_root.is_dir(),
        "hianyzik a golden baseline; futtasd: backend/tests/capture-golden.sh"
    );

    let mut slugs: Vec<String> = std::fs::read_dir(repo.join("themes"))
        .unwrap()
        .flatten()
        .map(|entry| entry.file_name().to_string_lossy().to_string())
        .collect();
    slugs.sort();
    assert!(!slugs.is_empty(), "nincs egyetlen tema sem");

    // Az egyes generatorok kimenete, a golden fajl nevehez rendelve.
    //
    // Az sddm SZANDEKOSAN hianyzik: a kimenete azota bovult az EDID alapu
    // monitor-azonositassal, mert a greeter X szervere mas connector-neveket
    // hasznal, mint a Wayland munkamenet. A formatumat a sddm.rs egysegtesztje
    // rogziti; a szinek lekepezese valtozatlan.
    //
    // A fastfetch is hianyzik: a logo forrasa idokozben ujratervezodott, igy a
    // rogzitett SVG baseline mar nem a jelenlegi forrasrol szol. A marker- es
    // config-transzformaciot a fastfetch.rs egysegtesztje fedi.
    let outputs: &[(&str, &str)] = &[
        ("kitty-theme", "kitty-theme.conf"),
        ("gtk-theme", "gtk-theme.css"),
        ("zen-theme", "zen-theme.css"),
        ("zen-content-theme", "zen-content-theme.css"),
        ("hyprland-theme", "@CONFIG@/hypr/colors.lua"),
        ("btop-theme", "@CONFIG@/btop/themes/vellum.theme"),
    ];

    let mut mismatches = Vec::new();
    let mut compared = 0;

    let mut checked_slugs = 0;

    for slug in &slugs {
        // A dinamikus tema conf-ja maga is generalt: ujragenerálodik minden
        // hatterkep-valtaskor, ezert alkalmatlan rogzitett baseline-nak. A
        // generatorok logikajat a nyolc kezzel irt tema amugy is lefedi.
        if slug == vellum_shell_backend::theme::DYNAMIC_SLUG {
            continue;
        }

        let golden = golden_root.join(slug);
        if !golden.is_dir() {
            continue;
        }
        checked_slugs += 1;

        sandbox.reset_outputs();
        std::fs::write(sandbox.shell_dir.join("current-theme"), format!("{slug}\n")).unwrap();

        let palette =
            Palette::load(&sandbox.shell_dir.join("themes").join(slug).join("theme.conf"))
                .unwrap_or_else(|err| panic!("{slug}: a paletta nem olvashato: {err:#}"));

        generators::run_all(&palette, true);

        for (golden_name, relative) in outputs {
            let expected_path = golden.join(golden_name);
            if !expected_path.is_file() {
                continue;
            }
            let actual_path = if let Some(rest) = relative.strip_prefix("@CONFIG@/") {
                sandbox.root.join(".config").join(rest)
            } else {
                sandbox.shell_dir.join(relative)
            };

            let expected = std::fs::read_to_string(&expected_path).unwrap();
            let Ok(actual) = std::fs::read_to_string(&actual_path) else {
                mismatches.push(format!("{slug}/{golden_name}: a Rust nem irt kimenetet"));
                continue;
            };

            compared += 1;
            if expected != actual {
                mismatches.push(format!(
                    "{slug}/{golden_name}: elteres\n{}",
                    first_difference(&expected, &actual)
                ));
            }
        }

        // Az icon-theme nem fajlt ir; a golden a gsettings hivast rogzitette.
        if let Some(expected) = expected_icon_theme(&golden) {
            compared += 1;
            let actual = generators::icon::resolve(&palette);
            if expected != actual {
                mismatches.push(format!("{slug}/icon-theme: vart {expected}, kapott {actual}"));
            }
        }
    }

    assert!(compared > 0, "egyetlen golden fajl sem lett osszehasonlitva");
    assert!(
        mismatches.is_empty(),
        "{} elteres {} osszehasonlitasbol:\n\n{}",
        mismatches.len(),
        compared,
        mismatches.join("\n\n")
    );

    eprintln!("{compared} golden fajl egyezik, {checked_slugs} tema");
}

/// Az elso eltero sor, hogy a hibauzenet hasznalhato legyen.
fn first_difference(expected: &str, actual: &str) -> String {
    for (index, (want, got)) in expected.lines().zip(actual.lines()).enumerate() {
        if want != got {
            return format!("  {}. sor:\n    vart:   {want}\n    kapott: {got}", index + 1);
        }
    }
    format!("  sorok szama: vart {}, kapott {}", expected.lines().count(), actual.lines().count())
}

//! A greeter hatterkep-masolata az EPPEN alkalmazott kepbol keszul.
//!
//! Regresszio: a `theme::apply` a `current-wallpaper`-t szandekosan csak a
//! generatorok UTAN commitolja, hogy egy elbukott generalas ne hagyjon hazug
//! allapotot. Amig a greeter-generator maga olvasta ki azt a fajlt, a
//! bejelentkezo kepernyo mindig egy hatterkep-valtassal lemaradt.
//!
//! Sajat teszt-binaris, mert a homokozo processz-szintu kornyezeti valtozokat
//! allit -- ugyanezert egyetlen teszfuggveny.

use std::path::{Path, PathBuf};
use vellum_shell_backend::theme;

fn repo_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).parent().unwrap().to_path_buf()
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

#[test]
fn the_greeter_background_follows_the_wallpaper_being_applied() {
    let root = std::env::temp_dir().join(format!("vellum-sddm-apply-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&root);
    let shell_dir = root.join(".config/quickshell/vellum_shell");
    std::fs::create_dir_all(shell_dir.join("sddm/vellum-ink")).unwrap();

    let repo = repo_root();
    copy_dir(&repo.join("themes"), &shell_dir.join("themes"));
    copy_dir(&repo.join("backend/templates"), &shell_dir.join("backend/templates"));

    // SAFETY: egyetlen teszt fut ebben a binarisban, nincs parhuzamos szal.
    unsafe {
        std::env::set_var("HOME", &root);
        std::env::set_var("XDG_CONFIG_HOME", root.join(".config"));
        std::env::set_var("XDG_DATA_HOME", root.join(".local/share"));
        std::env::set_var("VELLUM_SHELL_DIR", &shell_dir);
        // A rendszerkonyvtarban ulo greeter temahoz nem nyulunk.
        std::env::set_var("VELLUM_NO_SIDE_EFFECTS", "1");
    }

    // Ket eltero aranyu kep: a masolatrol igy egyertelmuen megmondhato,
    // melyikbol keszult. Mindketto 1280 px alatt van, tehat nincs kicsinyites.
    let previous = shell_dir.join("previous.png");
    let chosen = shell_dir.join("chosen.png");
    image::RgbImage::from_pixel(400, 400, image::Rgb([20, 20, 20])).save(&previous).unwrap();
    image::RgbImage::from_pixel(800, 200, image::Rgb([200, 40, 90])).save(&chosen).unwrap();

    // A rogzitett allapot meg a REGI kep -- pont ez a csapda.
    std::fs::write(shell_dir.join("current-wallpaper"), format!("{}\n", previous.display()))
        .unwrap();

    // Statikus tema, hogy a paletta ne a kepbol szulessen: itt csak a greeter
    // masolatanak forrasa a kerdes.
    theme::apply("japanese-ink", Some(chosen.to_str().unwrap()), false)
        .expect("a temanak alkalmazhatonak kell lennie");

    let copy = image::open(shell_dir.join("sddm/vellum-ink/background.jpg"))
        .expect("a greeter hatterkep-masolatanak el kell keszulnie");
    assert_eq!(
        (copy.width(), copy.height()),
        (800, 200),
        "a masolat a most alkalmazott kepbol keszuljon, ne a current-wallpaper-bol"
    );

    // A theme.conf relativ nevre hivatkozzon, kulonben a greeter nem talalja.
    let conf = std::fs::read_to_string(shell_dir.join("sddm/vellum-ink/theme.conf")).unwrap();
    assert!(conf.contains("\nbackground=background.jpg\n"), "{conf}");

    let _ = std::fs::remove_dir_all(&root);
}

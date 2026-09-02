//! Az IPC szerzodes pillanatkepe.
//!
//! A `vellum describe` kimenete kompatibilitasi szerzodes a QML kliens es a
//! CLI fele (lasd AGENTS.md). Ez a teszt rogziti, mi van benne: egy metodus
//! atnevezese vagy egy kotelezo parameter megvaltozasa igy nem csuszhat at
//! eszrevetlenul -- a hiba a szerzodes frissitesere emlekeztet, nem tilt.

use std::collections::BTreeMap;
use vellum_shell_backend::modules;

/// topic -> metodusnev(kotelezo parameterek).
///
/// Ha ez a lista valtozik, a QML oldalt (`core/Backend.qml` hivoi) es a README
/// IPC szakaszat is at kell nezni, majd ezt a listat frissiteni.
const CONTRACT: &[(&str, &[&str])] = &[
    ("health", &["ping()"]),
    (
        "hypr",
        &[
            "confirmMonitors(token)",
            "monitors()",
            "prepare()",
            "previewMonitors(monitors)",
            "read()",
            "reset(scope)",
            "revertMonitors(token)",
            "setMonitors(monitors)",
            "setOptions(values)",
            "stored()",
        ],
    ),
    ("network", &[]),
    ("privacy", &[]),
    ("removable", &["mount(path)", "powerOff(path)", "unmount(path)"]),
    ("sysstats", &[]),
    (
        "theme",
        &[
            "apply(slug)",
            "list()",
            "preview(wallpaper)",
            "read()",
            "setWallpaper(path)",
            "wallpapers()",
        ],
    ),
    ("vpn", &["config()", "connect()", "countries()", "details()", "disconnect()", "openApp()"]),
    ("weather", &[]),
];

fn actual() -> BTreeMap<String, Vec<String>> {
    modules::registry()
        .iter()
        .map(|module| {
            let description = module.describe();
            let mut methods: Vec<String> = description
                .methods
                .iter()
                .map(|method| {
                    let required: Vec<&str> = method
                        .params
                        .iter()
                        .filter(|param| param.required)
                        .map(|param| param.name)
                        .collect();
                    format!("{}({})", method.name, required.join(","))
                })
                .collect();
            methods.sort();
            (description.topic.to_string(), methods)
        })
        .collect()
}

#[test]
fn the_ipc_surface_matches_the_recorded_contract() {
    let actual = actual();
    let expected: BTreeMap<String, Vec<String>> = CONTRACT
        .iter()
        .map(|(topic, methods)| {
            ((*topic).to_string(), methods.iter().map(|m| (*m).to_string()).collect())
        })
        .collect();

    let actual_topics: Vec<&String> = actual.keys().collect();
    let expected_topics: Vec<&String> = expected.keys().collect();
    assert_eq!(
        actual_topics, expected_topics,
        "a topicok listaja megvaltozott -- frissitsd a CONTRACT-ot es a README-t"
    );

    for (topic, methods) in &expected {
        assert_eq!(
            actual.get(topic),
            Some(methods),
            "a(z) '{topic}' metodusai megvaltoztak -- frissitsd a CONTRACT-ot, \
             a QML hivokat es a README IPC szakaszat"
        );
    }
}

/// A leiras minden metodushoz mondjon valamit: ebbol tudja meg egy kliens (es
/// a `vellum describe` olvasoja), mire valo.
#[test]
fn every_method_is_documented() {
    for module in modules::registry() {
        let description = module.describe();
        assert!(!description.summary.is_empty(), "{} osszefoglalo nelkul", description.topic);
        for method in &description.methods {
            assert!(
                !method.summary.is_empty(),
                "{}.{} leiras nelkul",
                description.topic,
                method.name
            );
            for param in &method.params {
                assert!(
                    !param.summary.is_empty(),
                    "{}.{}({}) leiras nelkul",
                    description.topic,
                    method.name,
                    param.name
                );
            }
        }
    }
}

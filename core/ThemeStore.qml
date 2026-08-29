import QtQuick

// Az aktiv paletta. Az ertekek a Rust backend `theme` topicjabol jonnek; a
// korabbi Process + kezi szovegparse eltunt.
//
// A hat kozzetett property neve valtozatlan: 42 QML fajl epul rajuk.
Item {
    id: store

    required property var backend

    // A teljes paletta, mind a ~29 kulccsal. Korabban a ThemeStore csak hatot
    // ismert fel -- ami ezen kivul esett, elveszett.
    readonly property var colors: backend && backend.topics.theme && backend.topics.theme.colors
        ? backend.topics.theme.colors
        : ({})

    readonly property string slug: backend && backend.topics.theme && backend.topics.theme.slug
        ? backend.topics.theme.slug
        : ""

    // Azonnali elonezet temavaltaskor: a backend valaszara nem varunk, hogy a
    // felulet ne villanjon. A backend valasza felulirja.
    property var preview: ({})

    // FIGYELEM: a lekepezes szandekosan "kereszt". A MUTED kulcs az `outline`
    // propertybe megy, a LIGHT_FOREGROUND pedig a `muted`-be -- pontosan igy
    // tette a korabbi parse is, es a felulet erre epul.
    // Egyetlen osszevont terkep, amire a szinek epulnek. Fuggveny-hivas helyett
    // azert property, mert a fuggvenybol a QML nem latja a fuggosegeket, es a
    // preview torlese binding-hurkot okozott.
    readonly property var effective: {
        var merged = {}
        for (var key in colors) merged[key] = colors[key]
        for (var override in preview) merged[override] = preview[override]
        return merged
    }

    readonly property string background: effective.BACKGROUND || "#1e1e2e"
    readonly property string foreground: effective.FOREGROUND || "#cdd6f4"
    readonly property string accent: effective.ACCENT || "#89b4fa"
    readonly property string surface: effective.SURFACE || "#181825"
    readonly property string muted: effective.LIGHT_FOREGROUND || "#bac2de"
    readonly property string outline: effective.MUTED || "#9399b2"

    width: 0
    height: 0
    visible: false

    // A valaszto hivja, amig a backend dolgozik. A kulcsok a theme.conf
    // kulcsai, nem a property nevek.
    function setPreview(values) {
        preview = values || ({})
    }

    function load() {
        if (!backend) return
        backend.call("theme", "read", {}, (result, error) => {
            if (error) console.warn("ThemeStore: a paletta nem olvashato:", error.message)
        })
    }

    Component.onCompleted: if (backend) backend.subscribe("theme")

    // Amint a backend kikuldi az uj palettat, az elonezet feleslegesse valik.
    // A felteteles ertekadas fontos: felteteles nelkul minden szinvaltozas uj
    // objektumot rendelne a preview-hoz, ami ujra kivaltana az ertekelest.
    onColorsChanged: if (Object.keys(preview).length > 0) preview = ({})
}

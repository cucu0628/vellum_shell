import QtQuick
import Quickshell.Io

// Az aktiv paletta. Az ertekek a Rust backend `theme` topicjabol jonnek; a
// korabbi Process + kezi szovegparse eltunt.
//
// A hat kozzetett property neve valtozatlan: 42 QML fajl epul rajuk.
Item {
    id: store

    required property var backend
    // A daemon nelkuli tartalekhoz: innen olvassuk a `current-theme`-et es a
    // `themes/<slug>/theme.conf`-ot. Ures ertekkel nincs tartalek.
    property string shellDir: ""

    readonly property var backendColors: backend && backend.topics.theme && backend.topics.theme.colors
        ? backend.topics.theme.colors
        : null

    // A teljes paletta, mind a ~29 kulccsal. Korabban a ThemeStore csak hatot
    // ismert fel -- ami ezen kivul esett, elveszett.
    //
    // Ha a daemon nem fut (vagy meg nem kuldott snapshotot), a beallitott tema
    // fajljabol olvasunk, kulonben a shell a beepitett alapszinekkel indulna,
    // nem a felhasznalo temajaval.
    readonly property var colors: backendColors && Object.keys(backendColors).length > 0
        ? backendColors
        : fileColors

    readonly property string slug: backend && backend.topics.theme && backend.topics.theme.slug
        ? backend.topics.theme.slug
        : fileSlug

    property var fileColors: ({})
    property string fileSlug: ""

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

    // Az alapertekek a Japanese Ink paletta (themes/japanese-ink): a feature-ok
    // sajat tartalek szinei is ebbol jonnek, igy egy hianyzo kulcs nem kever
    // ket kulonbozo palettat.
    readonly property string background: effective.BACKGROUND || "#11130f"
    readonly property string foreground: effective.FOREGROUND || "#e8ddc7"
    readonly property string accent: effective.ACCENT || "#b7372f"
    readonly property string surface: effective.SURFACE || "#191b16"
    readonly property string muted: effective.LIGHT_FOREGROUND || "#cfc3ad"
    readonly property string outline: effective.MUTED || "#958b7a"
    // Figyelmeztetes (pl. majdnem tele lemez). Szemantikus szin, nem akcentus;
    // minden tema megadja az ORANGE kulcsot.
    readonly property string warning: effective.ORANGE || "#c9693f"

    width: 0
    height: 0
    visible: false

    // A valaszto hivja, amig a backend dolgozik. A kulcsok a theme.conf
    // kulcsai, nem a property nevek.
    function setPreview(values) {
        preview = values || ({})
    }

    // Nincs kulon `theme/read` hivas: a feliratkozas maga kikuldi a snapshotot
    // (vagy a modul `run`-ja tolja ki azonnal), tehat az mindig megerkezik.
    Component.onCompleted: if (backend) backend.subscribe("theme")

    // Amint a backend kikuldi az uj palettat, az elonezet feleslegesse valik.
    // A felteteles ertekadas fontos: felteteles nelkul minden szinvaltozas uj
    // objektumot rendelne a preview-hoz, ami ujra kivaltana az ertekelest.
    onColorsChanged: if (Object.keys(preview).length > 0) preview = ({})

    // A backend `Palette::parse` + `color::is_valid` szabalyai: a kulcsbol
    // minden whitespace kiesik, az ertekbol a whitespace es az idezojel is,
    // a kesobbi sor nyer, es csak `#rrggbb` ertek marad meg.
    function parsePalette(text) {
        var parsed = {}
        var lines = (text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line === "" || line.charAt(0) === "#") continue
            var separator = line.indexOf("=")
            if (separator < 0) continue
            var key = line.slice(0, separator).replace(/\s/g, "")
            var value = line.slice(separator + 1).replace(/[\s"]/g, "")
            if (/^#[0-9a-fA-F]{6}$/.test(value)) parsed[key] = value
            else delete parsed[key]
        }
        return parsed
    }

    FileView {
        id: currentThemeFile

        path: store.shellDir !== "" ? store.shellDir + "/current-theme" : ""
        watchChanges: true
        printErrors: false
        onLoaded: {
            var slug = currentThemeFile.text().trim()
            // Csak egyszeru slug: a fajl tartalmabol utvonal lesz.
            store.fileSlug = /^[A-Za-z0-9][A-Za-z0-9_-]*$/.test(slug) ? slug : ""
        }
        onFileChanged: currentThemeFile.reload()
        onLoadFailed: store.fileSlug = ""
    }

    FileView {
        id: themeConfFile

        path: store.shellDir !== "" && store.fileSlug !== ""
            ? store.shellDir + "/themes/" + store.fileSlug + "/theme.conf"
            : ""
        watchChanges: true
        printErrors: false
        onLoaded: store.fileColors = store.parsePalette(themeConfFile.text())
        onFileChanged: themeConfFile.reload()
        onLoadFailed: store.fileColors = ({})
    }
}

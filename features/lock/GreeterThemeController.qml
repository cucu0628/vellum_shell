import QtQuick
import Quickshell
import Quickshell.Io

// A greeter palettaja, hatterkepe es beviteli kijelzoje.
//
// A greeter greetd alatt, sajat rendszerfelhasznalokent fut: sem a backendet,
// sem a /home-ot nem eri el. A temamotor ezert a greeter allapotmappajaba irja
// ki, amire szukseg van (backend/src/greeter.rs). Ha a mappa ures, a lenti
// alapertekek maradnak -- a greeter ilyenkor is mukodik, csak semleges
// szinekkel es hatterkep nelkul.
QtObject {
    id: root

    readonly property string stateDir: Quickshell.env("VELLUM_GREETER_DIR") || "/var/lib/vellum-greeter"

    property var data: ({})
    readonly property var colors: data && data.colors ? data.colors : ({})
    readonly property string themeName: data && data.name ? data.name : ""

    // Ugyanaz a "kereszt" lekepezes, mint a LockThemeController-ben: a MUTED
    // kulcs az `outline`-ba megy, a LIGHT_FOREGROUND pedig a `muted`-be.
    readonly property string background: colors.BACKGROUND || "#1e1e2e"
    readonly property string foreground: colors.FOREGROUND || "#cdd6f4"
    readonly property string accent: colors.ACCENT || "#89b4fa"
    readonly property string surface: colors.SURFACE || "#181825"
    readonly property string muted: colors.LIGHT_FOREGROUND || "#bac2de"
    readonly property string outline: colors.MUTED || "#9399b2"
    readonly property string alert: colors.RED || "#d7472f"

    // Relativ nev az allapotmappahoz kepest; ures, ha nincs masolat.
    readonly property string wallpaper: data && data.background
        ? stateDir + "/" + data.background
        : ""

    // A lockscreen-monitor parja: azon a kijelzon van a jelszomezo.
    property string inputScreen: ""
    // A felhasznalo billentyuzetkiosztasai a greeter compositoranak konfigjabol.
    property var keyboardLayouts: []

    function parseTheme(text) {
        try {
            var parsed = JSON.parse(text)
            root.data = parsed && typeof parsed === "object" ? parsed : ({})
        } catch (error) {
            console.warn("Greeter: a theme.json nem ertelmezheto:", error)
            root.data = ({})
        }
    }

    function parseLayout(text) {
        var layouts = []
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            if (lines[i].indexOf("kb_layout=") !== 0) continue
            var value = lines[i].substring("kb_layout=".length).trim()
            if (value !== "") layouts = value.split(",")
        }
        root.keyboardLayouts = layouts
    }

    property FileView themeFile: FileView {
        path: root.stateDir + "/theme.json"
        printErrors: false
        watchChanges: true
        onLoaded: root.parseTheme(root.themeFile.text())
        onFileChanged: root.themeFile.reload()
    }

    property FileView inputScreenFile: FileView {
        path: root.stateDir + "/input-screen"
        printErrors: false
        onLoaded: root.inputScreen = root.inputScreenFile.text().trim()
    }

    property FileView layoutFile: FileView {
        path: root.stateDir + "/layout.conf"
        printErrors: false
        onLoaded: root.parseLayout(root.layoutFile.text())
    }
}

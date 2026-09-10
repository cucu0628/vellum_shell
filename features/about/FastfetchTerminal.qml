import QtQuick
import Quickshell
import Quickshell.Hyprland

// Az about feluletet nem a QML rajzolja: egy lebego kitty ablak, amiben a
// fastfetch fut. Igy pontosan az latszik, amit a generalt fastfetch config ad
// -- a kitty grafikus protokollal rajzolt Vellum logoval egyutt, amit QML
// szovegelem nem tudna megjeleniteni --, es a temaval is egyutt mozog, mert a
// kitty a generalt kitty-theme.conf-ot importalja.
QtObject {
    id: root

    property string shellDir: ""
    // A Hyprland app id alapjan talalja meg az ablakot; a kitty ezt a
    // `--class`-bol veszi. Sajat osztaly kell, hogy a kozos floating-terminal
    // ablakaitol meg tudjuk kulonboztetni.
    readonly property string appId: "vellum.fastfetch"
    readonly property int windowWidth: 860
    readonly property int windowHeight: 545

    property int pendingRefreshes: 0

    readonly property var toplevel: {
        var windows = Hyprland.toplevels ? Hyprland.toplevels.values : []
        for (var i = 0; i < windows.length; i++) {
            var info = windows[i].lastIpcObject
            if (info && info["class"] === root.appId) return windows[i]
        }
        return null
    }

    readonly property bool opened: toplevel !== null

    // A Quickshell csak keresre tolti fel az ablakok reszleteit: induláskor ures
    // a lista, az ujonnan nyilo ablak pedig cim nelkul kerul bele. Ezert
    // inditaskor egyszer, nyitas utan pedig par masodpercig kerunk frissitest,
    // kulonben a toggle nem talalna meg a sajat ablakat.
    Component.onCompleted: Hyprland.refreshToplevels()

    function open() {
        if (opened) {
            toplevel.activate()
            return
        }
        if (shellDir === "") return
        Quickshell.execDetached([
            shellDir + "/scripts/floating-terminal",
            "--class", appId,
            "--size", windowWidth + "x" + windowHeight,
            shellDir + "/scripts/fastfetch-panel"
        ])
        pendingRefreshes = 4
        detailsTimer.restart()
    }

    // Az ablakot osztaly szerint zarjuk: a cim nem egyedi, a cim szerinti
    // keresest pedig a felhasznalo ablakai is eltalalhatnak.
    function close() {
        if (!opened) return
        Hyprland.dispatch(Hyprland.usingLua
            ? "hl.dsp.window.close(\"class:" + appId + "\")"
            : "closewindow class:" + appId)
    }

    function toggle() {
        if (opened) close()
        else open()
    }

    property Timer detailsTimer: Timer {
        interval: 700
        repeat: true
        onTriggered: {
            Hyprland.refreshToplevels()
            root.pendingRefreshes--
            if (root.pendingRefreshes <= 0) stop()
        }
    }
}

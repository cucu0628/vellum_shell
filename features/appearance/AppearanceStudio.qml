import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

// Nincs mock felulet es nincs teljes kepernyos takaras: ez az ablak csak az also
// dokk. Folotte a sajat asztal latszik -- a valodi hatterkep, a valodi bar es a
// nyitott ablakok --, es a shell sajat szinei elo kovetik a valasztast.
//
// A kulso alkalmazasok temazasa (GTK, kitty, ikonok, Zen...) Enterre fut le.
PanelWindow {
    id: studio

    property alias backend: appearanceController.backend
    property alias theme: appearanceController.theme
    property alias wallpaperController: appearanceController.wallpaperController
    property alias opened: appearanceController.opened
    property alias mode: appearanceController.mode
    property alias themeItems: appearanceController.themeItems
    property alias wallpaperItems: appearanceController.wallpaperItems
    property alias selectedThemeIndex: appearanceController.selectedThemeIndex
    property alias selectedWallpaperIndex: appearanceController.selectedWallpaperIndex
    property alias applying: appearanceController.applying

    property bool dockVisible: true

    readonly property var selectedTheme: appearanceController.selectedTheme
    readonly property var selectedWallpaper: appearanceController.selectedWallpaper

    readonly property int dockMargin: 22
    readonly property bool revealed: opened && dockVisible

    function loadItems() { appearanceController.loadItems() }
    function releaseResources() { appearanceController.releaseResources() }
    function imageSource(path) { return appearanceController.imageSource(path) }
    function handleKey(event) { appearanceController.handleKey(event) }

    // A magassag allando, amig a felulet el: igy a nyitas, a zaras es a SPACE
    // becsukas mind egyszeru mozgatas, nem layer-shell atmeretezes kepkockankent.
    visible: opened || dock.opacity > 0
    color: "transparent"
    anchors { bottom: true; left: true; right: true }
    implicitHeight: dock.implicitHeight + studio.dockMargin * 2
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "quickshell.appearance-studio"
    WlrLayershell.exclusiveZone: -1
    // A dokk nem tolti ki a kepernyot, ezert nem eleg az OnDemand: kattintas
    // nelkul is nala kell lennie a billentyuzetnek, amig nyitva van.
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Az ablak magasabb, mint a lathato dokk, ezert az egermutatot csak a dokk
    // teruleten fogjuk el -- mellette a kattintas az asztalra megy.
    mask: Region { item: studio.revealed ? dock : sliver }

    AppearanceController {
        id: appearanceController
        onFocusRequested: focusTimer.start()
        onDockToggleRequested: studio.dockVisible = !studio.dockVisible
    }

    onOpenedChanged: if (opened) dockVisible = true

    Timer { id: focusTimer; interval: 60; onTriggered: keyScope.forceActiveFocus() }

    FocusScope {
        id: keyScope
        anchors.fill: parent
        focus: true
        Keys.onPressed: (event) => studio.handleKey(event)

        // Osszecsukva ez marad a kepernyo aljan: jelzi, hogy a valaszto meg el.
        Rectangle {
            id: sliver
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 3
            color: studio.theme ? studio.theme.accent : "#b7372f"
            opacity: studio.opened && !studio.dockVisible ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }

        StudioDock {
            id: dock

            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(1180, studio.width - 96)

            // Alulrol csuszik be, es oda is megy vissza. A zaras rovidebb, mint a
            // nyitas -- ugyanaz az arany, amit a shell tobbi felulete hasznal.
            y: studio.revealed
                ? parent.height - height - studio.dockMargin
                : parent.height - studio.dockMargin * 0.4
            opacity: studio.revealed ? 1 : 0
            Behavior on y {
                NumberAnimation {
                    duration: studio.revealed ? 280 : 160
                    easing.type: studio.revealed ? Easing.OutQuint : Easing.InQuad
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: studio.revealed ? 200 : 140
                    easing.type: studio.revealed ? Easing.OutQuart : Easing.InQuad
                }
            }

            theme: studio.theme
            wallpaperItems: studio.wallpaperItems
            themeItems: studio.themeItems
            selectedWallpaperIndex: studio.selectedWallpaperIndex
            selectedThemeIndex: studio.selectedThemeIndex
            selectedWallpaper: studio.selectedWallpaper
            selectedTheme: studio.selectedTheme
            emphasisRail: studio.mode === "theme" ? "theme" : "wallpaper"
            applying: appearanceController.applying
            dirty: appearanceController.dirty
            imageSource: studio.imageSource

            onWallpaperSelected: (index) => appearanceController.selectWallpaper(index)
            onPaletteSelected: (index) => appearanceController.selectPalette(index)
            onWallpaperStepRequested: (delta) => appearanceController.moveWallpaper(delta)
            onPaletteStepRequested: (delta) => appearanceController.movePalette(delta)
            onApplyRequested: appearanceController.applyAndClose()
            onCancelRequested: appearanceController.cancelAndClose()
        }
    }
}

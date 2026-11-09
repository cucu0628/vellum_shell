import QtQuick
import Quickshell
import Quickshell.Wayland
import "." as Screensaver
import "ScreensaverThemes.js" as Themes

// Egy monitor teljes kepernyos retege. A billentyuzetet egyszerre csak egy
// exkluziv felulet kaphatja, ezert csak a fokuszalt monitore veszi at.
PanelWindow {
    id: window

    required property var saver
    required property var theme
    required property real seed
    property bool takesKeyboard: false
    // Az unnepi temak sajat szint hoznak; a "shapes" a shell temajat koveti.
    readonly property var look: Themes.colors(saver.scene, theme)

    // Az elso esemeny csak a kurzor helyet jelzi, nem mozgast.
    property bool pointerKnown: false
    property real pointerX: 0
    property real pointerY: 0

    function pointerMoved(x, y) {
        if (!pointerKnown) {
            pointerKnown = true
            pointerX = x
            pointerY = y
            return
        }
        if (Math.abs(x - pointerX) + Math.abs(y - pointerY) > 4) saver.dismiss()
    }

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "quickshell.screensaver"
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: takesKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Screensaver.AsciiScene {
        id: scene

        anchors.fill: parent
        time: window.saver.time
        reveal: window.saver.reveal
        seed: window.seed
        devicePixelRatio: window.screen ? window.screen.devicePixelRatio : 1
        sceneName: window.saver.scene
        screenOrigin: window.screen ? Qt.point(window.screen.x - window.saver.canvas.x, window.screen.y - window.saver.canvas.y) : Qt.point(0, 0)
        canvasSize: Qt.size(window.saver.canvas.width, window.saver.canvas.height)
        backgroundColor: window.look.background
        lightColor: window.look.light
        highlight: window.look.highlight
        inkColors: window.look.palette
        // Shader nelkul egy lathatatlan ablak fogna a bemenetet.
        onFailedChanged: if (failed) window.saver.stop()
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        cursorShape: Qt.BlankCursor
        onPositionChanged: (mouse) => window.pointerMoved(mouse.x, mouse.y)
        onPressed: window.saver.dismiss()
        onWheel: window.saver.dismiss()
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: (event) => {
            event.accepted = true
            window.saver.dismiss()
        }
    }
}

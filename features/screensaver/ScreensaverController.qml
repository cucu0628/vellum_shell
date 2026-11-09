import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "." as Screensaver
import "ScreensaverThemes.js" as Themes

// Tetlenseg utan minden monitoron ASCII animacio; barmilyen bemenetre eltunik.
// Nem zarol: a zarolas kulon beallitas, es ha bekapcsol, a kepernyovedo atadja
// a helyet. Amig nem fut, csak az IdleMonitor el, a jelenet fel sem epul.
Item {
    id: controller

    required property string shellDir
    required property var theme
    required property var screens
    required property var focusedScreenProvider
    // Igaz, amig a munkamenet zarolva van.
    property bool blocked: false

    // Percben, a `screensaver-idle-minutes` fajlbol (a Settings System oldala
    // irja); 0 vagy hianyzo fajl = kikapcsolva.
    property int idleMinutes: 0
    // A `screensaver-theme` fajlbol: "shapes", "auto" (evszak szerint) vagy egy
    // tema neve (ScreensaverThemes.js). Hianyzo fajl = az alapjelenet.
    property string themeSetting: "shapes"
    // Az inditaskor kivalasztott jelenet; futas kozben nem valt.
    property string scene: "shapes"
    property bool running: false
    property bool closing: false
    // A bemenetet csak ez utan figyeljuk, hogy az indito billentyu elengedese
    // vagy egy utolso egermozdulat ne zarja be rogton.
    property bool armed: false
    property bool settled: false
    property string keyboardScreenName: ""
    property real time: 0
    property real reveal: 0
    property real startedAt: 0
    property real startOffset: 0

    readonly property bool shown: running || closing
    // Az osszes monitort befoglalo teglalap (logikai pixel). A monitorokon
    // atnyulo jelenet ebben szamol, igy a kep a hataron folytonos.
    readonly property rect canvas: {
        var list = screens || []
        if (list.length === 0) return Qt.rect(0, 0, 1, 1)
        var left = Infinity, top = Infinity, right = -Infinity, bottom = -Infinity
        for (var i = 0; i < list.length; i++) {
            var s = list[i]
            left = Math.min(left, s.x)
            top = Math.min(top, s.y)
            right = Math.max(right, s.x + s.width)
            bottom = Math.max(bottom, s.y + s.height)
        }
        return Qt.rect(left, top, Math.max(1, right - left), Math.max(1, bottom - top))
    }
    // A shader lebego szammal szamol: sok ora utan szemcses lenne a mozgas.
    readonly property real timeWrap: 36000

    width: 0
    height: 0
    visible: false

    // Az allo eger alatt a compositor kurzora latszana: a felulet csak
    // mozdulatra kapja meg a sajat ures kurzorat. Ezert a Hyprlandben rejtjuk el.
    function setCursorHidden(hidden) {
        Quickshell.execDetached([shellDir + "/scripts/screensaver-cursor",
            hidden ? "hide" : "show", Hyprland.usingLua ? "lua" : "legacy"])
    }

    function start() {
        if (running || blocked) return
        var target = focusedScreenProvider()
        keyboardScreenName = target ? target.name : ""
        startOffset = Math.random() * 100
        startedAt = Date.now()
        scene = Themes.resolve(themeSetting, new Date())
        time = startOffset
        armed = false
        settled = false
        running = true
        closing = false
        closeAnimation.stop()
        openAnimation.restart()
        armTimer.restart()
        setCursorHidden(true)
    }

    function stop() {
        if (!running) return
        running = false
        armTimer.stop()
        openAnimation.stop()
        closing = true
        closeAnimation.restart()
        setCursorHidden(false)
    }

    function toggle() {
        if (running) stop()
        else start()
    }

    // A felulet bemenete: a kesleltetes alatt meg nem szamit.
    function dismiss() {
        if (armed) stop()
    }

    function startFromIdle() {
        // A kontrolleres jatek vagy a teljes kepernyos alkalmazas nem latszik
        // bemenetnek, megis figyelnek ra.
        var active = ToplevelManager.activeToplevel
        if (active && active.fullscreen) return
        start()
    }

    onBlockedChanged: if (blocked) stop()
    // Ha a shell futo kepernyovedo kozben allt le, a kurzor rejtve maradt volna.
    Component.onCompleted: setCursorHidden(false)

    FileView {
        id: idleSetting

        path: controller.shellDir + "/screensaver-idle-minutes"
        watchChanges: true
        printErrors: false
        onLoaded: controller.idleMinutes = Math.max(0, parseInt(idleSetting.text().trim(), 10) || 0)
        onFileChanged: idleSetting.reload()
        onLoadFailed: controller.idleMinutes = 0
    }

    FileView {
        id: themeFile

        path: controller.shellDir + "/screensaver-theme"
        watchChanges: true
        printErrors: false
        onLoaded: controller.themeSetting = themeFile.text().trim() || "shapes"
        onFileChanged: themeFile.reload()
        onLoadFailed: controller.themeSetting = "shapes"
    }

    IdleMonitor {
        enabled: controller.idleMinutes > 0 && !controller.blocked
        timeout: controller.idleMinutes * 60
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) controller.startFromIdle()
    }

    // A compositor kotesei (pl. Super+...) nem jutnak el a felulethez. Ez a
    // figyelo minden bemenetet lat: elobb megvarja a csendet, utana az elso
    // jel bezar. A Hyprland idle-gatloi itt nem szamitanak.
    IdleMonitor {
        enabled: controller.running
        timeout: 1
        respectInhibitors: false
        onIsIdleChanged: {
            if (isIdle) controller.settled = true
            else if (controller.settled) controller.stop()
        }
    }

    Timer {
        id: armTimer
        interval: 500
        onTriggered: controller.armed = true
    }

    Timer {
        interval: 33
        repeat: true
        running: controller.shown
        onTriggered: controller.time = (controller.startOffset + (Date.now() - controller.startedAt) / 1000) % controller.timeWrap
    }

    NumberAnimation {
        id: openAnimation
        target: controller
        property: "reveal"
        to: 1
        duration: 900
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: closeAnimation
        target: controller
        property: "reveal"
        to: 0
        duration: 220
        easing.type: Easing.InCubic
        onFinished: controller.closing = false
    }

    Instantiator {
        active: controller.shown
        model: controller.screens

        delegate: Screensaver.ScreensaverWindow {
            required property var modelData
            required property int index

            screen: modelData
            saver: controller
            theme: controller.theme
            seed: 0.13 + index * 0.37
            takesKeyboard: controller.running && modelData.name === controller.keyboardScreenName
        }
    }
}

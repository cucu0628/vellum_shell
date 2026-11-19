pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../core" as Core
import "." as SplashUi

// Az inditokepernyo: a bejelentkezes es a kesz asztal kozotti fedolap.
//
// Kulon, konnyu Quickshell-peldany (SplashShell.qml), amit a `shell-start`
// legelol indit, meg a backend ujrainditasa es a kimenetek bevarasa elott --
// igy a logo mar akkor latszik, amikor a fo shell meg csak toltodik. A fo shell
// a `splash dismiss` IPC-hivassal jelez (features/splash/SplashHandoff.qml),
// amint a hatterkep minden kijelzon all; ekkor a lap felszakad, es alatta mar
// a kesz asztal van.
//
// Feketerol indul: a greeter feketebe usztat ki, es a ket compositor kozotti
// TTY-szunet is fekete, igy a lanc vegig varrat nelkuli.
//
//   1. a papir tuscseppkent terul szet a feketen, mogotte felizzik az akcentus;
//   2. a logo ket vonasban megirodik, kozben korbefut az enso;
//   3. alatta a nev es egy udvozles;
//   4. varakozas kozben az enso lassan forog;
//   5. kilepeskor a jel felemelkedik, a papir a kozeprol kifele felszakad.
//
// A bemenetet atengedi, es ha a jelzes nem jon meg, magatol is eltunik.
ShellRoot {
    id: root

    // 0..1 animalt allapotok; a nezetek csak olvassak oket.
    property real spread: 0
    property real glow: 0
    property real leftStroke: 0
    property real rightStroke: 0
    property real enso: 0
    property real words: 0
    property real lift: 0
    property real open: 0

    property bool written: false
    // A kesz jel egy ideig all, mielott a lap felszakadhat: egy gyors asztal
    // se vagja el a logot.
    property bool held: false
    property bool waiting: false
    property bool dismissRequested: false
    property bool leaving: false

    // Kijelzonkent ugyanaz a zaj: a monitorok kozott a perem nem ugrik.
    readonly property real seed: Math.random() * 100
    readonly property alias theme: themeStore
    property string greetingName: ""
    // A `settings.json` `effects.shaders` kulcsa: gyengebb gepen a tus-shader
    // helyett sima atusztatas. Csak olvassuk; irni a fo shell ir.
    readonly property bool shadersEnabled: settingsStore.value("effects", "shaders", true) !== false

    // Az indulas idovonala a Quickshell naplojaba (`quickshell log`): ha a
    // splash egyszer nem latszik, ebbol derul ki, miert.
    readonly property double startedAt: Date.now()

    function trace(message) {
        console.info("splash +" + (Date.now() - startedAt) + "ms: " + message)
    }

    function screenSummary() {
        var names = []
        var screens = Quickshell.screens
        for (var i = 0; i < screens.length; i++)
            names.push(screens[i].name + " " + screens[i].width + "x" + screens[i].height)
        return names.length > 0 ? names.join(", ") : "none"
    }

    Component.onCompleted: trace("loaded, screens: " + screenSummary())

    Connections {
        target: Quickshell

        function onScreensChanged() { root.trace("screens changed: " + root.screenSummary()) }
    }

    function dismiss() {
        trace("dismiss requested")
        dismissRequested = true
        if (held) leave()
    }

    function leave() {
        if (leaving) return
        leaving = true
        trace("leaving")
        // Az intro mar futo reszei (pl. a felirat) a kilepessel egyutt
        // fejezodnek be; a lap mindenkeppen teljesen beteritve indul.
        spread = 1
        outro.start()
    }

    function begin() {
        if (intro.running || written || leaving) return
        trace("intro begins (palette: " + themeStore.hasPalette + ", settings: " + settingsStore.loaded + ")")
        intro.start()
    }

    // A papir modja (shader vagy atusztatas) a beallitastol fugg: ha lehet,
    // a paletta mellett azt is bevarjuk, hogy kozben ne valtson.
    function beginWhenReady() {
        if (themeStore.hasPalette && settingsStore.loaded) begin()
    }

    // A /etc/passwd GECOS mezojenek elso szava: "Welcome back, Adam".
    function parseGreetingName(text) {
        var user = Quickshell.env("USER")
        if (!user) return ""
        var lines = (text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var fields = lines[i].split(":")
            if (fields.length < 5 || fields[0] !== user) continue
            var full = fields[4].split(",")[0].trim()
            return full !== "" ? full.split(/\s+/)[0] : ""
        }
        return ""
    }

    // A daemon nelkuli tartalek-olvasas: a `current-theme` es a tema
    // theme.conf-ja. Backend itt szandekosan nincs, hogy semmire ne kelljen varni.
    Core.ThemeStore {
        id: themeStore

        backend: null
        shellDir: Quickshell.env("VELLUM_SHELL_DIR") || Quickshell.shellDir
        transitionDuration: 0
        onHasPaletteChanged: root.beginWhenReady()
    }

    Core.SettingsStore {
        id: settingsStore

        shellDir: Quickshell.env("VELLUM_SHELL_DIR") || Quickshell.shellDir
        onLoadedChanged: root.beginWhenReady()
    }

    FileView {
        id: passwdFile

        path: "/etc/passwd"
        printErrors: false
        onLoaded: root.greetingName = root.parseGreetingName(passwdFile.text())
    }

    IpcHandler {
        target: "splash"

        function dismiss(): void { root.dismiss() }
    }

    // A paletta es a beallitasok altalaban nehany ms alatt betoltodnek; ha
    // nincsenek, a beepitett szinekkel es alapertekekkel indulunk, nem varakozunk.
    Timer {
        running: true
        interval: 160
        onTriggered: root.begin()
    }

    // Biztositek: egy elakadt fo shell se hagyja itt a fedolapot.
    Timer {
        running: true
        interval: 12000
        onTriggered: {
            root.trace("safety timeout")
            root.leave()
        }
    }

    ParallelAnimation {
        id: intro

        NumberAnimation {
            target: root
            property: "spread"
            to: 1
            duration: 1150
            easing.type: Easing.OutCubic
        }

        SequentialAnimation {
            PauseAnimation { duration: 220 }
            NumberAnimation {
                target: root
                property: "glow"
                to: 1
                duration: 1000
                easing.type: Easing.OutCubic
            }
        }

        SequentialAnimation {
            PauseAnimation { duration: 320 }
            NumberAnimation {
                target: root
                property: "leftStroke"
                to: 1
                duration: 440
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: root
                property: "rightStroke"
                to: 1
                duration: 540
                easing.type: Easing.OutQuart
            }
        }

        SequentialAnimation {
            PauseAnimation { duration: 420 }
            NumberAnimation {
                target: root
                property: "enso"
                to: 1
                duration: 1080
                easing.type: Easing.InOutCubic
            }
        }

        SequentialAnimation {
            PauseAnimation { duration: 1050 }
            NumberAnimation {
                target: root
                property: "words"
                to: 1
                duration: 800
                easing.type: Easing.OutCubic
            }
        }

        // A jel kesz: innentol a fo shell jelzese azonnal kilepest indit.
        SequentialAnimation {
            PauseAnimation { duration: 1500 }
            ScriptAction {
                script: {
                    root.written = true
                    root.trace("mark written")
                }
            }
            PauseAnimation { duration: 700 }
            ScriptAction {
                script: {
                    root.held = true
                    if (root.dismissRequested) root.leave()
                    else root.waiting = true
                }
            }
        }
    }

    ParallelAnimation {
        id: outro

        NumberAnimation {
            target: root
            property: "lift"
            to: 1
            duration: 480
            easing.type: Easing.InCubic
        }

        SequentialAnimation {
            PauseAnimation { duration: 200 }
            NumberAnimation {
                target: root
                property: "open"
                to: 1
                duration: 1050
                easing.type: Easing.InOutCubic
            }
        }

        onFinished: {
            root.trace("done")
            Qt.quit()
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: splashWindow

            required property var modelData
            property bool firstFrame: false

            screen: modelData
            onVisibleChanged: root.trace(modelData.name + " visible: " + visible)
            Component.onCompleted: root.trace(modelData.name + " window created")

            Connections {
                target: splashWindow.contentItem.Window.window
                enabled: !splashWindow.firstFrame

                function onFrameSwapped() {
                    splashWindow.firstFrame = true
                    root.trace(splashWindow.modelData.name + " first frame")
                }
            }
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            // Ures bemeneti terulet: a kattintas atmegy, a fokuszt nem veszi el.
            mask: Region {}

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "vellum-splash"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            SplashUi.SplashView {
                anchors.fill: parent
                splashRoot: root
            }
        }
    }
}

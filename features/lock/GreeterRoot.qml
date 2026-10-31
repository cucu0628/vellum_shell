pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "." as LockUi

// A Vellum greeter: greetd + Quickshell egy minimalis Hyprlandben
// (greeter/hyprland.lua). A zarolokepernyo vizualis nyelve, kiegeszitve azzal,
// amit csak a greeter tud: felhasznalo- es munkamenet-valaszto,
// billentyuzetkiosztas es energia-muveletek.
//
// A megosztott lock-komponensek (LockBackground, LockClock, PasswordField,
// AmbientLockView, ...) egy `lockRoot`-ot varnak: ez az objektum ugyanazt a
// feluletet adja, mint a LockRoot, csak greetd-vel a PAM helyett.
//
// greetd nelkul (pl. a felhasznalo munkamenetebol inditva) elonezet modban
// fut: nem jelentkeztet be, nem kapcsol ki semmit, es Esc-re kilep.
ShellRoot {
    id: root

    readonly property bool preview: !auth.available

    // --- a lockRoot felulet ---
    property string password: ""
    property alias unlockInProgress: auth.busy
    property alias failed: auth.failed
    property alias statusText: auth.statusText
    property alias prompt: auth.prompt
    property alias background: themeController.background
    property alias foreground: themeController.foreground
    property alias accent: themeController.accent
    property alias surface: themeController.surface
    property alias muted: themeController.muted
    property alias outline: themeController.outline
    property alias wallpaper: themeController.wallpaper
    property alias alertColor: themeController.alert
    readonly property var theme: themeController
    property bool ready: false
    property bool closing: false
    property bool thawing: false
    property int revealStep: 0
    property var currentTime: new Date()
    readonly property string timeText: two(currentTime.getHours()) + ":" + two(currentTime.getMinutes())

    // --- a greeter tobblete ---
    property alias users: accounts.users
    property alias userIndex: accounts.userIndex
    property alias userLabel: accounts.userLabel
    property alias sessions: accounts.sessions
    property alias sessionIndex: accounts.sessionIndex
    property alias sessionLabel: accounts.sessionLabel
    property alias keyboardLayouts: themeController.keyboardLayouts
    property int keyboardIndex: 0
    readonly property string keyboardLabel: keyboardLayouts.length > 0
        ? keyboardLayouts[keyboardIndex % keyboardLayouts.length].toUpperCase()
        : ""
    property string hostName: ""
    readonly property bool powerActionsEnabled: !preview && !closing

    // A jelszomezo a lockscreen-monitoron jelenik meg; ha az nincs bekotve,
    // az elso kijelzon.
    readonly property string effectiveInputMonitorName: {
        var wanted = themeController.inputScreen
        var screens = Quickshell.screens
        for (var i = 0; i < screens.length; i++) {
            if (screens[i].name === wanted) return wanted
        }
        return screens.length > 0 ? screens[0].name : ""
    }

    function two(value) {
        return value < 10 ? "0" + value : "" + value
    }

    function clearPassword() {
        if (unlockInProgress) return
        // Az elonezetbol Esc-cel lehet kilepni; az igazi greeterbol nem.
        if (password === "" && preview) {
            Qt.quit()
            return
        }
        password = ""
    }

    // A PasswordField es az AmbientLockView ezt hivja Enterre.
    function tryUnlock() {
        if (closing || unlockInProgress) return
        if (password === "" && !auth.awaitingAnswer) return

        if (preview) {
            auth.failed = false
            auth.failed = true
            auth.statusText = "Preview: greetd is not running"
            password = ""
            return
        }
        if (!accounts.user) {
            auth.fail("No user account found")
            return
        }
        if (!accounts.session) {
            auth.fail("No Wayland session found")
            return
        }

        var secret = password
        password = ""
        auth.submit(accounts.userName, secret)
    }

    function selectUser(index) {
        if (index === accounts.userIndex) return
        auth.reset()
        password = ""
        accounts.selectUser(index)
    }

    function selectSession(index) {
        accounts.selectSession(index)
    }

    function nextKeyboardLayout() {
        if (keyboardLayouts.length < 2) return
        keyboardIndex = (keyboardIndex + 1) % keyboardLayouts.length
        // Az elonezet a felhasznalo elo munkamenetet nem allitja at.
        if (preview) return
        keyboardSwitch.running = false
        keyboardSwitch.running = true
    }

    function power(action) {
        if (!powerActionsEnabled) return
        powerProcess.command = ["systemctl", action]
        powerProcess.running = true
    }

    function launchSession() {
        var session = accounts.session
        if (!session) {
            auth.fail("No Wayland session found")
            return
        }
        accounts.remember()

        var environment = ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=" + session.id]
        if (session.desktopNames.length > 0)
            environment.push("XDG_CURRENT_DESKTOP=" + session.desktopNames.join(":"))
        // Az Exec sort egyben adjuk at. A greetd a parancs elemeit szokozzel
        // osszefuzi egy `/bin/sh -c '. /etc/profile; ...; exec <parancs>'`
        // sorba, tehat egy sajat `sh -c` csak a szot ("exec") futtatna, es a
        // munkamenet azonnal kilepne.
        auth.launch([session.exec], environment)
    }

    // Ugyanaz a ket utemu kilepes, mint a zarolasnal: eloszor a panel tunik el,
    // aztan felenged a hatter, es csak a tiszta hatterkep utan lepunk ki.
    function finishLogin() {
        if (closing) return
        closing = true
        thawTimer.restart()
        quitTimer.restart()
    }

    Component.onCompleted: introTimer.start()

    // A greeter felhasznalo a ~/.local/share/fonts-ot nem latja, ezert a
    // `greeter-install` a jel-fontot a telepitett peldany melle masolja. A
    // repobol inditott elonezetben a fajl hianyzik, ott a felhasznalo fontja jon.
    FontLoader {
        source: Qt.resolvedUrl("../../fonts/SymbolsNerdFontMono-Regular.ttf")
    }

    LockUi.GreeterThemeController {
        id: themeController
    }

    LockUi.GreeterAccounts {
        id: accounts
    }

    LockUi.GreeterSessionController {
        id: auth

        onReadyToLaunch: root.launchSession()
        onLaunched: root.finishLogin()
    }

    FileView {
        id: hostFile

        path: "/etc/hostname"
        printErrors: false
        onLoaded: root.hostName = hostFile.text().trim()
    }

    Process {
        id: keyboardSwitch

        command: ["hyprctl", "switchxkblayout", "all", "next"]
    }

    Process {
        id: powerProcess
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = new Date()
    }

    Timer {
        id: introTimer

        interval: 60
        onTriggered: {
            root.ready = true
            revealTimer.start()
        }
    }

    // Lepcsozetes megjelenes: 1 = a hatter fagy be, 2 = ora, 3 = bevitel.
    Timer {
        id: revealTimer

        interval: 110
        repeat: true
        onTriggered: {
            root.revealStep += 1
            if (root.revealStep >= 3) revealTimer.stop()
        }
    }

    Timer {
        id: thawTimer

        interval: 130
        onTriggered: root.thawing = true
    }

    // A greetd csak a greeter kilepese utan inditja a munkamenetet, ezert a
    // kilepes nem varhat tovabb, mint amennyi a felengedeshez kell.
    Timer {
        id: quitTimer

        interval: 520
        onTriggered: Qt.quit()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: surface

            required property var modelData

            readonly property bool isInputScreen: modelData.name === root.effectiveInputMonitorName

            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: root.background

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "vellum-greeter"
            // Csak a beviteli kijelzo kap billentyuzetet: a gepeles mindig oda
            // erkezik, akarhol all az eger.
            WlrLayershell.keyboardFocus: isInputScreen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            LockUi.LockBackground {
                anchors.fill: parent
                lockRoot: root
            }

            Loader {
                anchors.fill: parent
                active: surface.isInputScreen
                focus: active

                sourceComponent: LockUi.GreeterInputView {
                    lockRoot: root
                    screenName: surface.modelData.name
                }
            }

            Loader {
                anchors.fill: parent
                active: !surface.isInputScreen

                sourceComponent: LockUi.AmbientLockView {
                    lockRoot: root
                    screenName: surface.modelData.name
                    idleText: root.preview ? "Greeter preview" : "Ready to sign in"
                    inputHint: "Sign in on " + root.effectiveInputMonitorName
                }
            }
        }
    }
}

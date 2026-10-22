import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "." as LockUi
import "../../core" as Core

ShellRoot {
    id: root

    property alias password: authentication.password
    property alias submittedPassword: authentication.submittedPassword
    property alias unlockInProgress: authentication.unlockInProgress
    property alias failed: authentication.failed
    property alias statusText: authentication.statusText
    property alias background: themeController.background
    property alias foreground: themeController.foreground
    property alias accent: themeController.accent
    property alias surface: themeController.surface
    property alias muted: themeController.muted
    property alias outline: themeController.outline
    property alias wallpaper: themeController.wallpaper
    // A megosztott ui/ komponensek egy paletta-objektumot varnak, nem hat
    // kulon propertyt -- a temavezerlo pont ilyen alaku.
    readonly property var theme: themeController
    property bool ready: false
    property bool closing: false
    // A kilepes ket utemu: eloszor a panel tunik el, csak utana enged fel a
    // dermedt hatter. Ha egyszerre tortenne, a felszabadulasnak nem lenne oka,
    // es a lap egyben kapcsolna at.
    property bool thawing: false
    property bool lockOnStartup: false
    property bool quitAfterUnlock: false

    // A fo shell atadja a sajat backendjet. Az onallo LockShell.qml nem tud
    // atadni semmit, ezert ilyenkor sajat klienst epitunk -- de csak akkor, hogy
    // a beagyazott esetben ne nyiljon feleslegesen masodik socket.
    property var backend: null
    readonly property var effectiveBackend: backend ? backend : ownBackend.item
    // A zárolt ciklus egyetlen igazságforrása: ez hajtja a WlSessionLockot és az ütemezőket is.
    property bool sessionActive: false
    // Az altatas csak azutan indulhat, hogy a compositor minden kijelzon
    // visszaigazolta a session lock feluletet.
    property bool suspendPending: false
    property int revealStep: 0
    property var currentTime: new Date()
    property alias powerText: powerController.powerText
    property alias inputMonitorName: settingsController.inputMonitorName
    property alias settingsReady: settingsController.ready

    readonly property string alertColor: "#d7472f"
    readonly property string userName: Quickshell.env("USER") || "user"
    readonly property string timeText: two(currentTime.getHours()) + ":" + two(currentTime.getMinutes())
    readonly property string secondsText: two(currentTime.getSeconds())
    readonly property string weekdayText: Qt.formatDate(currentTime, "dddd").toUpperCase()
    readonly property string dateText: Qt.formatDate(currentTime, "MMMM d yyyy").toUpperCase()
    readonly property real dayProgress: (currentTime.getHours() * 3600 + currentTime.getMinutes() * 60 + currentTime.getSeconds()) / 86400

    readonly property string effectiveInputMonitorName: inputMonitorName !== ""
        ? inputMonitorName
        : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "")

    function two(value) {
        return value < 10 ? "0" + value : "" + value
    }

    function refreshPowerStatus() {
        powerController.refreshPowerStatus()
    }

    function tryUnlock() {
        authentication.tryUnlock()
    }

    function clearPassword() {
        if (unlockInProgress) return
        password = ""
    }

    function finishUnlock() {
        if (closing) return
        closing = true
        statusText = "Unlocked"
        thawTimer.restart()
        unlockAnimationTimer.restart()
    }

    function resetCycleState() {
        introTimer.stop()
        revealTimer.stop()
        thawTimer.stop()
        unlockAnimationTimer.stop()
        unlockExitTimer.stop()
        ready = false
        closing = false
        thawing = false
        revealStep = 0
        currentTime = new Date()
        authentication.reset()
    }

    function lock() {
        if (sessionActive || closing) return
        resetCycleState()
        refreshPowerStatus()
        settingsController.load()
        sessionActive = true
        introTimer.restart()
    }

    // Zarolas kivulrol jovo okbol (alvas, lock-session, tetlenseg). A sima
    // `lock()` a feloldasi animacio alatt nem csinal semmit; itt viszont a
    // feloldast meg kell szakitani, kulonben a gep zaratlanul aludna el, vagy
    // a kert zarolas elveszne.
    function lockNow() {
        if (closing && sessionActive) {
            // A zar meg all, csak a feloldasi animacio fut: visszaforditjuk.
            thawTimer.stop()
            unlockAnimationTimer.stop()
            closing = false
            thawing = false
            authentication.reset()
            return
        }
        if (closing) {
            // A zar mar elengedve, csak a kilepo utem van hatra: ujrakezdjuk.
            unlockExitTimer.stop()
            closing = false
        }
        lock()
    }

    function suspend() {
        if (closing || suspendPending || suspendProcess.running) return
        if (!sessionActive) lock()
        suspendPending = true
        suspendWhenSecure()
    }

    function suspendWhenSecure() {
        if (!suspendPending || !sessionLock.secure || suspendProcess.running) return
        suspendPending = false
        suspendProcess.running = true
    }

    // Alvas elotti zarolas. Ha nem mi altatunk (fedel, `systemctl suspend`,
    // idle-demon), a backend `session` topicja szol, mikozben egy logind
    // inhibitorral visszatartja az alvast. Zarolunk, es amint a compositor
    // visszaigazolta a feluletet, a `sleepReady` elengedi.
    property bool sleepLockPending: false
    readonly property bool systemSleeping: backend && backend.topics.session
        ? backend.topics.session.sleeping === true
        : false

    onSystemSleepingChanged: {
        if (!systemSleeping) {
            sleepLockPending = false
            return
        }
        lockNow()
        sleepLockPending = true
        releaseSleepWhenSecure()
    }

    // `loginctl lock-session` (es az erre epulo idle-demonok, pl. hypridle).
    // A backend szamlalja a kereseket; a novekedesre zarolunk. Az elso ertek
    // (es egy daemon-ujrainditas utani) csak alapvonal.
    readonly property int sessionLockRequests: backend && backend.topics.session
        ? (backend.topics.session.lockRequests || 0)
        : -1
    property int seenLockRequests: -1

    onSessionLockRequestsChanged: {
        if (sessionLockRequests >= 0 && seenLockRequests >= 0 && sessionLockRequests > seenLockRequests)
            lockNow()
        seenLockRequests = sessionLockRequests
    }

    // Tetlenseg utani zarolas. Az ido percben a `lock-idle-minutes` fajlban (a
    // Settings System oldala irja); 0 vagy hianyzo fajl = kikapcsolva. Az idle
    // inhibitorokat (pl. teljes kepernyos video) tiszteletben tartjuk.
    property int idleLockMinutes: 0

    property FileView idleSetting: FileView {
        path: settingsController.shellDir + "/lock-idle-minutes"
        watchChanges: true
        printErrors: false
        onLoaded: root.idleLockMinutes = Math.max(0, parseInt(root.idleSetting.text().trim(), 10) || 0)
        onFileChanged: root.idleSetting.reload()
        onLoadFailed: root.idleLockMinutes = 0
    }

    IdleMonitor {
        enabled: root.idleLockMinutes > 0 && !root.sessionActive
        timeout: root.idleLockMinutes * 60
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) root.lockNow()
    }

    function releaseSleepWhenSecure() {
        if (!sleepLockPending || !sessionLock.secure) return
        sleepLockPending = false
        if (backend) backend.call("session", "sleepReady", {})
    }

    // Ha a shell zarolt allapotban hal el, a felugyelo (`scripts/shell-run`)
    // ujrainditja, es ez a jelolo mondja meg az uj peldanynak, hogy azonnal
    // zaroljon. A jelolo a Hyprland-peldany azonositojat tartalmazza: ha maga a
    // compositor halt el, es a felhasznalo ujra bejelentkezett, a regi jelolo
    // nem zarolja le az uj munkamenetet.
    readonly property string lockMarkerPath: Quickshell.env("XDG_RUNTIME_DIR")
        ? Quickshell.env("XDG_RUNTIME_DIR") + "/vellum-shell-locked"
        : ""
    readonly property string lockMarkerValue: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "locked"

    property FileView lockMarker: FileView {
        path: root.lockMarkerPath
        printErrors: false
        onLoaded: if (root.lockMarker.text().trim() === root.lockMarkerValue) root.lock()
    }

    onSessionActiveChanged: {
        if (lockMarkerPath !== "") lockMarker.setText(sessionActive ? lockMarkerValue : "")
        // A logind `LockedHint`; egy regebbi daemon hibajat szandekosan elnyeljuk.
        if (backend) backend.call("session", "setLocked", { "locked": sessionActive }, function() {})
    }

    Component.onCompleted: {
        if (lockOnStartup) lock()
        // Az onallo LockShell.qml mar zarolva indul; az alvasi jelzes csak a
        // beagyazott, tartosan futo lockot erdekli.
        if (backend) backend.subscribe("session")
    }

    Loader {
        id: ownBackend
        active: !root.backend
        sourceComponent: Component {
            Core.Backend {}
        }
    }

    LockUi.LockThemeController {
        id: themeController
        backend: root.effectiveBackend
    }

    LockUi.PowerStatusController {
        id: powerController
    }

    LockUi.LockScreenSettingsController {
        id: settingsController
    }

    LockUi.AuthenticationController {
        id: authentication
        onSucceeded: root.finishUnlock()
    }

    Process {
        id: suspendProcess
        command: ["systemctl", "suspend"]
    }

    Timer {
        interval: 1000
        running: root.sessionActive
        repeat: true
        onTriggered: currentTime = new Date()
    }

    Timer {
        interval: 30000
        running: root.sessionActive
        repeat: true
        onTriggered: refreshPowerStatus()
    }

    Timer {
        id: introTimer
        interval: 60
        onTriggered: {
            root.ready = true
            revealTimer.start()
        }
    }

    // Lepcsozetes megjelenes: 1 = a hatter fagy be, 2 = ora, 3 = felhasznalo
    // es beviteli mezo.
    Timer {
        id: revealTimer
        interval: 110
        repeat: true
        onTriggered: {
            root.revealStep += 1
            if (root.revealStep >= 3) revealTimer.stop()
        }
    }

    // A panel eltunese utan enged fel a dermedes.
    Timer {
        id: thawTimer
        interval: 130
        onTriggered: root.thawing = true
    }

    // A zarolast csak akkor engedjuk el, amikor a felulet mar pontosan az
    // asztali hatterkep: se fatyol, se vignetta, se vizjel. Igy az utolso kocka
    // es az asztal kozott nincs ugras -- 130 ms panel + 340 ms felenges + egy
    // rovid megallapodas.
    Timer {
        id: unlockAnimationTimer
        interval: 500
        onTriggered: {
            root.sessionActive = false
            if (!sessionLock.secure) unlockExitTimer.start()
        }
    }

    Timer {
        id: unlockExitTimer
        interval: 120
        onTriggered: {
            if (root.quitAfterUnlock) Qt.quit()
            else root.resetCycleState()
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: root.sessionActive

        onSecureChanged: {
            if (secure) root.suspendWhenSecure()
            if (secure) root.releaseSleepWhenSecure()
            if (root.closing && !secure) unlockExitTimer.restart()
        }

        WlSessionLockSurface {
            id: lockSurface

            readonly property string surfaceName: screen ? screen.name : ""
            readonly property bool isInputScreen: Quickshell.screens.length <= 1
                || (root.settingsReady && screen && screen.name === root.effectiveInputMonitorName)

            color: root.background

            LockUi.LockBackground {
                anchors.fill: parent
                lockRoot: root
            }

            Loader {
                anchors.fill: parent
                active: lockSurface.isInputScreen

                sourceComponent: LockUi.InputLockView {
                    lockRoot: root
                    screenName: lockSurface.surfaceName
                }
            }

            Loader {
                anchors.fill: parent
                active: root.settingsReady && !lockSurface.isInputScreen

                sourceComponent: LockUi.AmbientLockView {
                    lockRoot: root
                    screenName: lockSurface.surfaceName
                }
            }
        }
    }
}

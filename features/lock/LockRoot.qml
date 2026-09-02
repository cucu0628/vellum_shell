import QtQuick
import Quickshell
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
    property int revealStep: 0
    property var currentTime: new Date()
    property alias powerText: powerController.powerText
    property alias inputMonitorName: settingsController.inputMonitorName
    property alias settingsReady: settingsController.ready

    readonly property string alertColor: "#d7472f"
    readonly property string userName: Quickshell.env("USER") || "user"
    readonly property var dayNames: ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"]
    readonly property var monthNames: ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]

    readonly property int weekdayIndex: (currentTime.getDay() + 6) % 7
    readonly property string timeText: two(currentTime.getHours()) + ":" + two(currentTime.getMinutes())
    readonly property string secondsText: two(currentTime.getSeconds())
    readonly property string weekdayText: dayNames[weekdayIndex]
    readonly property string dateText: monthNames[currentTime.getMonth()] + " " + currentTime.getDate() + " " + currentTime.getFullYear()
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

    Component.onCompleted: {
        if (lockOnStartup) lock()
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

    // Lepcsozetes megjelenes: 1 = a hatter fagy be, 2 = ora, 3 = panel,
    // 4 = beviteli mezo es allapotsor.
    Timer {
        id: revealTimer
        interval: 110
        repeat: true
        onTriggered: {
            root.revealStep += 1
            if (root.revealStep >= 4) revealTimer.stop()
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

                sourceComponent: LockUi.LockCard {
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

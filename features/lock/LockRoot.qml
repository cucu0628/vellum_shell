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
    property bool ready: false
    property bool closing: false
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
    readonly property string dateText: monthNames[currentTime.getMonth()] + " " + currentTime.getDate() + "  ·  " + currentTime.getFullYear()
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
        unlockAnimationTimer.start()
    }

    function resetCycleState() {
        introTimer.stop()
        revealTimer.stop()
        unlockAnimationTimer.stop()
        unlockExitTimer.stop()
        ready = false
        closing = false
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
        interval: 80
        onTriggered: {
            root.ready = true
            revealTimer.start()
        }
    }

    // Lépcsőzetes megjelenés: minden ütem egy réteget hoz be a felületen.
    Timer {
        id: revealTimer
        interval: 130
        repeat: true
        onTriggered: {
            root.revealStep += 1
            if (root.revealStep >= 6) revealTimer.stop()
        }
    }

    Timer {
        id: unlockAnimationTimer
        interval: 640
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

            LockUi.LockShutter {
                anchors.fill: parent
                lockRoot: root
                z: 100
            }
        }
    }
}

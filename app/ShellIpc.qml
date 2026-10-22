import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property var coordinator
    required property var lockProvider
    required property var focusedScreenProvider
    required property var screenshotCaptureProvider
    // Az eppen szolo (vagy utolso) MPRIS lejatszo a medagombokhoz.
    property var activePlayer: null
    // Az alapertelmezett kimenet es bemenet: core/AudioSummaryController.
    property var audioController: null
    // A beepitett kijelzo fenyereje: core/BrightnessController.
    property var brightnessController: null
    property string pendingAboutAction: ""

    width: 0
    height: 0
    visible: false

    function scheduleAboutAction(action) {
        pendingAboutAction = action
        aboutMonitorDelay.restart()
    }

    function openMedia(card) {
        coordinator.mediaPopup.initialCard = card || ""
        coordinator.setMediaOpen(true, focusedScreenProvider())
    }

    Timer {
        id: aboutMonitorDelay
        interval: 75
        onTriggered: {
            var action = root.pendingAboutAction
            root.pendingAboutAction = ""
            var targetScreen = root.focusedScreenProvider()
            if (action === "toggle") root.coordinator.toggleAbout(targetScreen)
            else if (action === "open") root.coordinator.setAboutOpen(true, targetScreen)
        }
    }

    IpcHandler {
        target: "settings"

        function toggle(): void { coordinator.toggleSettings() }
        function open(): void { coordinator.setSettingsOpen(true) }
        function close(): void { coordinator.setSettingsOpen(false) }
    }

    // A `menu` es `power` nev kompatibilitasi szerzodes (layout.md): a menu
    // palettat a settings app valtotta ki, de a regi hivasok tovabbra is mukodnek.
    IpcHandler {
        target: "menu"

        function toggle(): void { coordinator.toggleSettings() }
        function open(): void { coordinator.setSettingsOpen(true) }
        function close(): void { coordinator.setSettingsOpen(false) }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            coordinator.toggleLauncher(focusedScreenProvider())
        }
        function open(): void {
            coordinator.setLauncherOpen(true, focusedScreenProvider())
        }
        function close(): void { coordinator.setLauncherOpen(false) }
    }

    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            coordinator.toggleClipboard(focusedScreenProvider())
        }
        function open(): void {
            coordinator.setClipboardOpen(true, focusedScreenProvider())
        }
        function close(): void { coordinator.setClipboardOpen(false) }
    }

    IpcHandler {
        target: "style"

        function theme(): void {
            coordinator.setThemeSwitcherOpen(true, "theme", focusedScreenProvider())
        }
        function wallpaper(): void {
            coordinator.setThemeSwitcherOpen(true, "wallpaper", focusedScreenProvider())
        }
        function close(): void { coordinator.closeThemeSwitcher() }
    }

    IpcHandler {
        target: "power"

        function toggle(): void { coordinator.toggleSettings() }
        function open(): void { coordinator.setSettingsOpen(true) }
        function close(): void { coordinator.setSettingsOpen(false) }
    }

    IpcHandler {
        target: "lock"

        function lock(): void { lockProvider.lock() }
        function suspend(): void { lockProvider.suspend() }
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void { coordinator.toggleNotifications(focusedScreenProvider()) }
        function dnd(): void { coordinator.toggleNotificationsDnd() }
        function close(): void { coordinator.setNotificationsOpen(false) }
        function clear(): void { coordinator.clearNotifications() }
        function grouping(): void { coordinator.toggleNotificationsGrouping() }
        function expand(): void { coordinator.setNotificationGroupsExpanded(true) }
        function collapse(): void { coordinator.setNotificationGroupsExpanded(false) }
    }

    IpcHandler {
        target: "audio"

        // Ugyanaz a monitorvalasztas, mint a tobbi IPC utvonalon: a panel ott
        // nyilik, ahol a felhasznalo epp dolgozik. (A `toggleAudioScreenAgnostic`
        // annak maradt, aki tenyleg nem tudja a kepernyot.)
        function toggle(): void { coordinator.toggleAudio(focusedScreenProvider()) }
        function open(): void { coordinator.setAudioOpen(true, focusedScreenProvider()) }
        function close(): void { coordinator.setAudioOpen(false) }
        // Az alapertelmezett kimenet 5%-os lepesben; az OSD a PipeWire
        // valtozasabol magatol megjelenik.
        function volumeUp(): void { if (root.audioController) root.audioController.stepVolume(true) }
        function volumeDown(): void { if (root.audioController) root.audioController.stepVolume(false) }
        function mute(): void { if (root.audioController) root.audioController.toggleMute() }
        function micMute(): void { if (root.audioController) root.audioController.toggleMicMute() }
    }

    IpcHandler {
        target: "brightness"

        // 5%-os lepes; hattervilagitas vagy daemon nelkul nem csinal semmit.
        // A billentyuk a `vellum call brightness step` parancsot hasznaljak,
        // ami a shell nelkul is mukodik.
        function up(): void { if (root.brightnessController) root.brightnessController.step(5) }
        function down(): void { if (root.brightnessController) root.brightnessController.step(-5) }
    }

    IpcHandler {
        target: "media"

        function toggle(): void { coordinator.toggleCenterPopup(focusedScreenProvider()) }
        function open(): void { root.openMedia() }
        // A dashboard mar egyetlen lap; a regi fulnevek megmaradnak, hogy a
        // meglevo billentyuparancsok es szkriptek ne torjenek el.
        function overview(): void { root.openMedia() }
        function player(): void { root.openMedia() }
        // A dashboard egy kinagyitott kartyaval.
        function weather(): void { root.openMedia("weather") }
        function calendar(): void { root.openMedia("calendar") }
        // Medagombok: nem kell hozzajuk playerctl, a shell maga vezerli az
        // aktiv lejatszot.
        function playPause(): void {
            if (root.activePlayer && root.activePlayer.canTogglePlaying) root.activePlayer.togglePlaying()
        }
        function next(): void {
            if (root.activePlayer && root.activePlayer.canGoNext) root.activePlayer.next()
        }
        function previous(): void {
            if (root.activePlayer && root.activePlayer.canGoPrevious) root.activePlayer.previous()
        }
        function close(): void { coordinator.setMediaOpen(false) }
    }

    IpcHandler {
        target: "network"

        function toggle(): void { coordinator.toggleNetwork(focusedScreenProvider()) }
        function open(): void { coordinator.setNetworkOpen(true, focusedScreenProvider()) }
        function close(): void { coordinator.setNetworkOpen(false) }
    }

    IpcHandler {
        target: "bluetooth"

        function toggle(): void { coordinator.toggleBluetooth(focusedScreenProvider()) }
        function open(): void { coordinator.setBluetoothOpen(true, focusedScreenProvider()) }
        function close(): void { coordinator.setBluetoothOpen(false) }
    }

    IpcHandler {
        target: "removable"

        function toggle(): void { coordinator.toggleRemovable(focusedScreenProvider()) }
        function open(): void { coordinator.setRemovableOpen(true, focusedScreenProvider()) }
        function close(): void { coordinator.setRemovableOpen(false) }
    }

    IpcHandler {
        target: "vpn"

        function toggle(): void { coordinator.toggleVpn(focusedScreenProvider()) }
        function open(): void { coordinator.setVpnOpen(true, focusedScreenProvider()) }
        function close(): void { coordinator.setVpnOpen(false) }
        function connect(): void { coordinator.vpnQuickConnect(focusedScreenProvider()) }
        function disconnect(): void { coordinator.vpnDisconnect(focusedScreenProvider()) }
        function app(): void { coordinator.vpnOpenApp() }
    }

    IpcHandler {
        target: "about"

        function toggle(): void { root.scheduleAboutAction("toggle") }
        function open(): void { root.scheduleAboutAction("open") }
        function close(): void {
            aboutMonitorDelay.stop()
            root.pendingAboutAction = ""
            coordinator.setAboutOpen(false)
        }
    }

    IpcHandler {
        target: "screenshot"

        function capture(): void { screenshotCaptureProvider("smart") }
        function window(): void { screenshotCaptureProvider("window") }
        function workspace(): void { screenshotCaptureProvider("workspace") }
        function region(): void { screenshotCaptureProvider("region") }
    }
}

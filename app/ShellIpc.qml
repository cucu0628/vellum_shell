import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property var coordinator
    required property var lockProvider
    required property var focusedScreenProvider
    required property var screenshotCaptureProvider
    property string pendingAboutAction: ""

    width: 0
    height: 0
    visible: false

    function scheduleAboutAction(action) {
        pendingAboutAction = action
        aboutMonitorDelay.restart()
    }

    function openMediaTab(tab) {
        coordinator.openMediaTab(tab, focusedScreenProvider())
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
    }

    IpcHandler {
        target: "media"

        function toggle(): void { coordinator.toggleCenterPopup(focusedScreenProvider()) }
        function open(): void { root.openMediaTab(coordinator.mediaPopup.currentTab) }
        function overview(): void { root.openMediaTab(0) }
        function player(): void { root.openMediaTab(1) }
        function weather(): void { root.openMediaTab(2) }
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

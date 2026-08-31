import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "app" as App
import "core" as Core
import "features/about" as AboutFeature
import "features/ai" as AiFeature
import "features/appearance" as AppearanceFeature
import "features/audio" as AudioFeature
import "features/bar" as BarUi
import "features/clipboard" as ClipboardFeature
import "features/launcher" as LauncherFeature
import "features/lock" as LockFeature
import "features/media" as MediaFeature
import "features/settings" as SettingsFeature
import "features/bluetooth" as BluetoothFeature
import "features/network" as NetworkFeature
import "features/notifications" as NotificationFeature
import "features/osd" as OsdFeature
import "features/polkit" as PolkitFeature
import "features/privacy" as PrivacyFeature
import "features/removable" as RemovableFeature
import "features/screenshot" as ScreenshotFeature
import "features/tray" as TrayFeature

ShellRoot {
    id: shellRoot

    // Globális beállítások
    property int barHeight: 26
    property alias preferredPlayerDbusName: mprisController.preferredPlayerDbusName
    property alias audioVolumePercent: audioSummaryController.volumePercent
    property alias audioMuted: audioSummaryController.muted
    property alias visibleWorkspaceIds: workspaceController.visibleWorkspaceIds
    property alias occupiedWorkspaceIds: workspaceController.occupiedWorkspaceIds
    property alias vpnActive: vpnController.active
    property alias vpnName: vpnController.name
    property alias networkType: networkStatusController.connectionType
    property alias currentWallpaper: wallpaperStore.currentWallpaper
    property alias activePlayer: mprisController.activePlayer
    property var calendarNow: new Date()
    property bool audioOsdReady: false
    readonly property string homeDir: Quickshell.env("HOME")
    // Ugyanaz a szabaly, mint a backend `theme::paths::shell_dir()`-jeben,
    // hogy a ket oldal ne csusszon szet athelyezett repo eseten.
    readonly property string shellDir: Quickshell.env("VELLUM_SHELL_DIR")
        || (homeDir + "/.config/quickshell/vellum_shell")
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property var dayNames: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    // A Rust backend kliense. Legelol jon letre, hogy a tobbi controller mar
    // atvehesse. Ha a daemon nem fut, a shell degradaltan, de mukodik.
    Core.Backend {
        id: backend
    }
    readonly property var shellBackend: backend

    Core.ThemeStore {
        id: theme
        backend: shellRoot.shellBackend
    }
    readonly property var shellTheme: theme

    Core.WallpaperController {
        id: wallpaperStore
        backend: shellRoot.shellBackend
        shellDir: shellRoot.shellDir
        screens: shellRoot.uniqueScreens
        onDoubleClicked: (targetScreen) => shellRoot.setThemeSwitcherOpen(true, "wallpaper", targetScreen)
    }

    Core.WorkspaceController {
        id: workspaceController
    }

    Core.AudioSummaryController {
        id: audioSummaryController
        onSinkChanged: audioSinkRefreshTimer.restart()
    }

    Core.VpnController {
        id: vpnController
        backend: shellRoot.shellBackend
    }

    Core.NetworkStatusController {
        id: networkStatusController
        backend: shellRoot.shellBackend
    }

    Core.BluetoothStatusController {
        id: bluetoothStatusController
    }

    Core.BatteryStatusController {
        id: batteryStatusController
    }

    Core.PrivacyController {
        id: privacyController
        backend: shellRoot.shellBackend
    }

    Core.RemovableDeviceController {
        id: removableDeviceController
        backend: shellRoot.shellBackend
        onDeviceAdded: popupCoordinator.setRemovableOpen(true, shellRoot.focusedScreen())
    }

    Core.MprisController {
        id: mprisController
    }

    Core.CavaController {
        id: cavaController
        active: shellRoot.activePlayer && shellRoot.activePlayer.playbackState === MprisPlaybackState.Playing
    }

    function setCurrentWallpaper(path) { wallpaperStore.setCurrentWallpaper(path) }
    function wallpaperSource(path) { return wallpaperStore.source(path) }

    Component.onCompleted: {
        refreshVisibleWorkspaces()
        audioOsdReadyTimer.start()
        shellBackend.call("hypr", "prepare", {}, null)
    }

    onAudioVolumePercentChanged: showVolumeOsd()
    onAudioMutedChanged: showVolumeOsd()

    function showVolumeOsd() {
        if (!audioOsdReady) return
        volumeOsd.showVolume(audioVolumePercent, audioMuted, focusedScreen())
    }

    Timer {
        id: audioOsdReadyTimer
        interval: 500
        onTriggered: shellRoot.audioOsdReady = true
    }

    Timer {
        id: audioSinkRefreshTimer
        interval: 200
        onTriggered: shellRoot.showVolumeOsd()
    }

    Process {
        id: processLauncher
    }

    function launchBarCommand(command) {
        processLauncher.command = command
        processLauncher.running = true
    }

    function refreshVisibleWorkspaces() { workspaceController.refresh() }
    function updateVisibleWorkspacesFromService() { workspaceController.updateFromService() }
    function updateVisibleWorkspaces(output) { workspaceController.update(output) }
    function workspaceWindowCount(workspace) { return workspaceController.windowCount(workspace) }
    function applyWorkspaceState(workspaces) { workspaceController.applyState(workspaces) }
    function isWorkspaceOccupied(id) { return workspaceController.isOccupied(id) }

    function focusedScreen() {
        var monitor = Hyprland.focusedMonitor
        if (monitor && monitor.name) {
            for (var i = 0; i < uniqueScreens.length; i++) {
                if (uniqueScreens[i] && uniqueScreens[i].name === monitor.name) return uniqueScreens[i]
            }
        }
        return uniqueScreens.length > 0 ? uniqueScreens[0] : null
    }

    function toggleCenterPopup(nextScreen) { popupCoordinator.toggleCenterPopup(nextScreen) }
    function toggleNotificationsDnd() { popupCoordinator.toggleNotificationsDnd() }
    function setNotificationsOpen(open, nextScreen) { popupCoordinator.setNotificationsOpen(open, nextScreen) }
    function setSettingsOpen(open) { popupCoordinator.setSettingsOpen(open) }
    function setLauncherOpen(open, nextScreen) { popupCoordinator.setLauncherOpen(open, nextScreen) }
    function setClipboardOpen(open, nextScreen) { popupCoordinator.setClipboardOpen(open, nextScreen) }
    function setThemeSwitcherOpen(open, nextMode, nextScreen) { popupCoordinator.setThemeSwitcherOpen(open, nextMode, nextScreen) }
    function setAudioOpen(open, nextScreen) { popupCoordinator.setAudioOpen(open, nextScreen) }
    function setAboutOpen(open, nextScreen) { popupCoordinator.setAboutOpen(open, nextScreen) }
    function captureScreenshot(mode) {
        screenshotController.capture(mode)
    }

    // Az xdg-toplevel ablakot Hyprland alapbol csempezne. A backend egy pontos
    // class/title szabalyt regisztral meg az elso megnyitas elott; regi vagy
    // hianyzo daemon eseten ez szandekosan hangtalanul degradalodik.

    // A settings app igazi ablak, nem layer-shell overlay, ezert nem az
    // App.LazyPopup kezeli. A Loader viszont ugyanugy csak akkor epiti fel az
    // objektumfat, amikor tenyleg kell.
    Item {
        id: settingsApp

        property bool opened: false

        width: 0
        height: 0
        visible: false

        Loader {
            id: settingsLoader
            asynchronous: true
            active: settingsApp.opened
            sourceComponent: Component {
                SettingsFeature.SettingsWindow {
                    backend: shellRoot.shellBackend
                    theme: shellRoot.shellTheme
                    visible: settingsApp.opened
                    onClosed: settingsApp.opened = false
                    onCloseRequested: settingsApp.opened = false
                }
            }
        }
    }

    // Popup shells stay lightweight while their full object trees are unloaded.
    App.LazyPopup {
        id: appLauncher
        loaded: true
        unloadOnClose: false
        popupComponent: Component {
            LauncherFeature.LauncherPopup {
                theme: shellRoot.shellTheme
                screen: appLauncher.screen
            }
        }
    }

    ClipboardFeature.ClipboardController {
        id: clipboardStore
    }

    App.LazyPopup {
        id: clipboardHistory
        popupComponent: Component {
            ClipboardFeature.ClipboardPopup {
                theme: shellRoot.shellTheme
                clipboardController: clipboardStore
                screen: clipboardHistory.screen
            }
        }
    }

    App.LazyPopup {
        id: themeSwitcher
        popupComponent: Component {
            AppearanceFeature.AppearanceStudio {
                backend: shellRoot.shellBackend
                theme: shellRoot.shellTheme
                wallpaperController: shellRoot
                mode: themeSwitcher.mode
                screen: themeSwitcher.screen
            }
        }
    }

    App.LazyPopup {
        id: audioPopup
        popupComponent: Component {
            AudioFeature.AudioPopup {
                theme: shellRoot.shellTheme
                screen: audioPopup.screen
            }
        }
    }

    App.LazyPopup {
        id: connectivityPopup
        mode: "network"
        popupComponent: Component {
            NetworkFeature.ConnectivityPopup {
                theme: shellRoot.shellTheme
                statusController: networkStatusController
                vpnCli: vpnController
                screen: connectivityPopup.screen
                currentTab: connectivityPopup.mode === "vpn" ? 1 : 0
                onCurrentTabChanged: connectivityPopup.mode = currentTab === 1 ? "vpn" : "network"
            }
        }
    }

    App.LazyPopup {
        id: privacyPopup
        popupComponent: Component {
            PrivacyFeature.PrivacyPopup {
                theme: shellRoot.shellTheme
                statusController: privacyController
                screen: privacyPopup.screen
            }
        }
    }

    App.LazyPopup {
        id: bluetoothPopup
        popupComponent: Component {
            BluetoothFeature.BluetoothPopup {
                theme: shellRoot.shellTheme
                statusController: bluetoothStatusController
                screen: bluetoothPopup.screen
            }
        }
    }

    App.LazyPopup {
        id: removablePopup
        popupComponent: Component {
            RemovableFeature.RemovableDevicePopup {
                theme: shellRoot.shellTheme
                deviceController: removableDeviceController
                screen: removablePopup.screen
            }
        }
    }

    App.LazyPopup {
        id: aboutPopup
        popupComponent: Component {
            AboutFeature.AboutPopup {
                theme: shellRoot.shellTheme
                screen: aboutPopup.screen
            }
        }
    }

    App.LazyPopup {
        id: aiPopup
        popupComponent: Component {
            AiFeature.AiUsagePopup {
                theme: shellRoot.shellTheme
                screen: aiPopup.screen
            }
        }
    }

    ScreenshotFeature.ScreenshotController {
        id: screenshotController
        shellDir: shellRoot.shellDir
    }

    LockFeature.LockRoot {
        id: lockRoot
        backend: shellRoot.shellBackend
    }

    NotificationFeature.NotificationsHost {
        id: notifications
        theme: theme
    }

    OsdFeature.VolumeOsd {
        id: volumeOsd
        theme: theme
    }

    PolkitFeature.PolkitDialog {
        theme: shellRoot.shellTheme
        screenProvider: function() { return shellRoot.focusedScreen() }
    }

    App.PopupCoordinator {
        id: popupCoordinator
        settings: settingsApp
        launcher: appLauncher
        clipboard: clipboardHistory
        themeSwitcher: themeSwitcher
        mediaPopup: mediaPopup
        audioPopup: audioPopup
        connectivityPopup: connectivityPopup
        bluetoothPopup: bluetoothPopup
        removablePopup: removablePopup
        privacyPopup: privacyPopup
        aiPopup: aiPopup
        vpnCli: vpnController
        aboutPopup: aboutPopup
        notifications: notifications
        onCalendarRefreshRequested: shellRoot.calendarNow = new Date()
    }

    App.ShellIpc {
        coordinator: popupCoordinator
        lockProvider: lockRoot
        focusedScreenProvider: function() { return shellRoot.focusedScreen() }
        screenshotCaptureProvider: function(mode) { shellRoot.captureScreenshot(mode) }
    }

    // AGRESSZÍV MONITOR SZŰRÉS (Csak egyedi nevű monitorok)
    readonly property var uniqueScreens: {
        var screens = Quickshell.screens
        var seenNames = {}
        var result = []
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i]
            if (s && s.name && !seenNames[s.name]) {
                seenNames[s.name] = true
                result.push(s)
            }
        }
        return result
    }

    function isBrowserPlayer(player) { return mprisController.isBrowserPlayer(player) }
    function chooseActivePlayer() { return mprisController.chooseActivePlayer() }
    function updateActivePlayer() { mprisController.updateActivePlayer() }

    function volumePercent() {
        return audioVolumePercent
    }

    // TOPBAR LÉTREHOZÁSA (DMS stílusú Instantiatorral)
    Instantiator {
        model: shellRoot.uniqueScreens
        delegate: BarUi.BarWindow {
            required property var modelData

            targetScreen: modelData
            theme: shellRoot.shellTheme
            barHeight: shellRoot.barHeight
            visibleWorkspaceIds: shellRoot.visibleWorkspaceIds
            occupiedWorkspaceIds: shellRoot.occupiedWorkspaceIds
            activePlayer: shellRoot.activePlayer
            hasMediaSource: Mpris.players.values.length > 0
            cavaValues: cavaController.values
            settingsOpen: settingsApp.opened
            centerPopupOpen: mediaPopup.opened && mediaPopup.screen === targetScreen
            audioPopupOpen: audioPopup.opened && audioPopup.screen === targetScreen
            audioVolumePercent: shellRoot.audioVolumePercent
            vpnActive: shellRoot.vpnActive
            vpnName: shellRoot.vpnName
            networkType: shellRoot.networkType
            connectivityPopupOpen: connectivityPopup.opened && connectivityPopup.screen === targetScreen
            bluetoothAvailable: bluetoothStatusController.available
            bluetoothEnabled: bluetoothStatusController.adapterEnabled
            bluetoothConnected: bluetoothStatusController.connected
            bluetoothPopupOpen: bluetoothPopup.opened && bluetoothPopup.screen === targetScreen
            removableDeviceCount: removableDeviceController.deviceCount
            mountedRemovableCount: removableDeviceController.mountedCount
            removablePopupOpen: removablePopup.opened && removablePopup.screen === targetScreen
            batteryAvailable: batteryStatusController.available
            batteryPercentage: batteryStatusController.percentage
            batteryCharging: batteryStatusController.charging
            notificationsDnd: notifications.dnd
            notificationsHasToast: notifications.hasToast
            notificationsUnreadCount: notifications.unreadCount
            notificationsMenuOpened: notifications.menuOpened
            aiPopupOpen: aiPopup.opened && aiPopup.screen === targetScreen
            trayMenuOpen: trayMenu.visible && trayMenu.screen === targetScreen
            micActive: privacyController.micActive
            cameraActive: privacyController.cameraActive
            privacyPopupOpen: privacyPopup.opened && privacyPopup.screen === targetScreen

            onSettingsToggleRequested: popupCoordinator.toggleSettings()
            onCenterToggleRequested: popupCoordinator.toggleCenterPopup(targetScreen)
            onAudioToggleRequested: popupCoordinator.toggleAudio(targetScreen)
            onPrivacyToggleRequested: popupCoordinator.togglePrivacy(targetScreen)
            onConnectivityToggleRequested: popupCoordinator.toggleConnectivity(connectivityPopup.mode, targetScreen)
            onConnectivityVpnRequested: popupCoordinator.toggleConnectivity("vpn", targetScreen)
            onBluetoothToggleRequested: popupCoordinator.toggleBluetooth(targetScreen)
            onRemovableToggleRequested: popupCoordinator.toggleRemovable(targetScreen)
            onNotificationsToggleRequested: popupCoordinator.toggleNotifications(targetScreen)
            onAiToggleRequested: popupCoordinator.toggleAi(targetScreen)
            onLaunchCommand: command => launchBarCommand(command)
            onAudioVolumeStepRequested: increase => audioSummaryController.stepVolume(increase)
            onTrayMenuRequested: (model, globalX) => trayMenu.openFor(targetScreen, model, globalX)
        }
    }

    App.LazyPopup {
        id: mediaPopup
        property int currentTab: 0
        property string selectedPlayerDbusName: ""
        popupComponent: Component {
            MediaFeature.MediaPopup {
                backend: shellRoot.shellBackend
                theme: shellRoot.shellTheme
                screen: mediaPopup.screen
                currentTab: mediaPopup.currentTab
                selectedPlayerDbusName: mediaPopup.selectedPlayerDbusName
                barHeight: shellRoot.barHeight
                activePlayer: shellRoot.activePlayer
                cavaValues: cavaController.values
                calendarNow: shellRoot.calendarNow
                monthNames: shellRoot.monthNames
                dayNames: shellRoot.dayNames
                onCurrentTabChanged: mediaPopup.currentTab = currentTab
                onSelectedPlayerDbusNameChanged: mediaPopup.selectedPlayerDbusName = selectedPlayerDbusName
            }
        }
    }

    TrayFeature.TrayMenu {
        id: trayMenu
        theme: theme
        barHeight: shellRoot.barHeight
    }
}

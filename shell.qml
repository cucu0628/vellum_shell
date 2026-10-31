import QtQuick
import Quickshell
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
import "features/connectivity" as ConnectivityFeature
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
    property alias audioVolumePercent: audioSummaryController.volumePercent
    property alias audioMuted: audioSummaryController.muted
    property alias visibleWorkspaceIds: workspaceController.visibleWorkspaceIds
    property alias occupiedWorkspaceIds: workspaceController.occupiedWorkspaceIds
    property alias vpnActive: vpnController.active
    property alias vpnName: vpnController.name
    property alias networkType: networkStatusController.connectionType
    property alias activePlayer: mprisController.activePlayer
    property var calendarNow: new Date()
    property bool audioOsdReady: false
    readonly property string homeDir: paths.homeDir
    readonly property string shellDir: paths.shellDir
    readonly property var monthNames: localizedMonthNames()
    readonly property var dayNames: localizedDayNames()

    function localizedMonthNames() {
        var names = [];
        for (var month = 0; month < 12; month++)
            names.push(Qt.formatDate(new Date(2024, month, 15), "MMMM"));
        return names;
    }

    function localizedDayNames() {
        var names = [];
        // 2024-01-01 hetfo volt, igy az eredmeny tovabbra is hetfovel kezdodik.
        for (var day = 1; day <= 7; day++)
            names.push(Qt.formatDate(new Date(2024, 0, day), "ddd"));
        return names;
    }

    Core.Paths {
        id: paths
        homeDir: Quickshell.env("HOME")
        configHomeOverride: Quickshell.env("XDG_CONFIG_HOME")
        stateHomeOverride: Quickshell.env("XDG_STATE_HOME")
        cacheHomeOverride: Quickshell.env("XDG_CACHE_HOME")
        shellDirOverride: Quickshell.env("VELLUM_SHELL_DIR")
    }

    // A Rust backend kliense. Legelol jon letre, hogy a tobbi controller mar
    // atvehesse. Ha a daemon nem fut, a shell degradaltan, de mukodik.
    Core.Backend {
        id: backend

        // Az offline parancsokat szandekosan nem jatszuk vissza. A prepare
        // idempotens startup-muvelet, ezert minden friss kapcsolatnal explicit
        // ujra kiadjuk.
        onConnectedChanged: {
            if (connected) backend.call("hypr", "prepare", {}, null)
        }
    }
    readonly property var shellBackend: backend

    Core.ThemeStore {
        id: theme
        backend: shellRoot.shellBackend
        shellDir: shellRoot.shellDir
    }
    readonly property var shellTheme: theme

    Core.BarLayoutController {
        id: barLayoutController

        shellDir: shellRoot.shellDir
    }
    readonly property var barLayoutState: barLayoutController

    Core.WallpaperController {
        id: wallpaperStore
        backend: shellRoot.shellBackend
        shellDir: shellRoot.shellDir
        screens: shellRoot.uniqueScreens
        onDoubleClicked: (targetScreen) => popupCoordinator.setThemeSwitcherOpen(true, "wallpaper", targetScreen)
    }

    Core.WorkspaceController {
        id: workspaceController
    }

    // A Settings > Default apps-ban valasztott terminal; a launcher ezzel nyitja
    // a terminalt es a Terminal=true alkalmazasokat.
    Core.TerminalController {
        id: terminalController
        configHome: paths.configHome
    }

    Core.BrightnessController {
        id: brightnessController
        backend: shellRoot.shellBackend
        onPercentChanged: shellRoot.showBrightnessOsd()
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
        shellDir: shellRoot.shellDir
    }

    // Mindig fut (masodpercenkent egy /proc-olvasas a backendben), hogy a
    // dashboard CPU-grafikonja megnyitaskor mar teljes legyen.
    MediaFeature.SystemStatsController {
        id: systemStats
        backend: shellRoot.shellBackend
        active: true
    }

    Core.CavaController {
        id: cavaController
        active: shellRoot.activePlayer && shellRoot.activePlayer.playbackState === MprisPlaybackState.Playing
    }

    Component.onCompleted: {
        workspaceController.refresh()
        audioOsdReadyTimer.start()
    }

    onAudioVolumePercentChanged: showVolumeOsd()
    onAudioMutedChanged: showVolumeOsd()

    // Az elso ertek (inditas, daemon-ujracsatlakozas) nem allitas: csak a
    // mar ismert ertekhez kepesti valtozasra mutatjuk.
    property int lastBrightness: -1

    function showBrightnessOsd() {
        var percent = brightnessController.percent
        var previous = lastBrightness
        lastBrightness = percent
        if (!audioOsdReady || percent < 0 || previous < 0 || percent === previous) return
        volumeOsd.showBrightness(percent, focusedScreen())
    }

    function showVolumeOsd() {
        if (!audioOsdReady) return
        volumeOsd.showVolume(audioVolumePercent, audioMuted, focusedScreen(), audioSummaryController.deviceName)
    }

    // A zene sajat (MPRIS) hangereje kulon OSD-valtozatot kap, barhonnan
    // allitjak (lejatszo, dashboard, Ctrl + hangerogomb). A billentyus lepes
    // azonnal, a kert ertekkel jelez; a kivulrol jovo valtozast a jelentett
    // ertekbol vesszuk. Lejatszovaltas utan egy masodpercig csak megjegyezzuk
    // az erteket: ekkor toltodnek be a lejatszo tulajdonsagai, az nem allitas.
    property real lastPlayerVolume: -1

    onActivePlayerChanged: {
        lastPlayerVolume = activePlayer && activePlayer.volumeSupported ? activePlayer.volume : -1
        playerVolumeSettleTimer.restart()
    }

    Timer {
        id: playerVolumeSettleTimer
        interval: 1000
    }

    Connections {
        target: mprisController

        function onVolumeStepped(player, volume) {
            shellRoot.lastPlayerVolume = volume
            shellRoot.showPlayerVolumeOsd(player, volume)
        }
    }

    Connections {
        target: shellRoot.activePlayer

        function onVolumeChanged() {
            shellRoot.playerVolumeChanged()
        }
    }

    function playerVolumeChanged() {
        var player = activePlayer
        if (!player || !player.volumeSupported) return
        var volume = player.volume
        // Nehany lejatszo valtozatlan hangerot is jelent; a sajat lepesunk
        // visszaigazolasa is ide fut be.
        if (lastPlayerVolume >= 0 && Math.abs(volume - lastPlayerVolume) < 0.005) return
        lastPlayerVolume = volume
        if (playerVolumeSettleTimer.running) return
        showPlayerVolumeOsd(player, volume)
    }

    function showPlayerVolumeOsd(player, volume) {
        if (!audioOsdReady) return
        volumeOsd.showPlayerVolume(Math.round(Math.max(0, Math.min(1, volume)) * 100), player, focusedScreen())
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

    // Levalasztva indul: egy kozos Process-szel a gyors masodik kattintas
    // elveszett volna, mert a futo peldanyt nem lehet ujrainditani.
    function launchBarCommand(command) {
        Quickshell.execDetached(command)
    }

    function focusedScreen() {
        var monitor = Hyprland.focusedMonitor
        if (monitor && monitor.name) {
            for (var i = 0; i < uniqueScreens.length; i++) {
                if (uniqueScreens[i] && uniqueScreens[i].name === monitor.name) return uniqueScreens[i]
            }
        }
        return uniqueScreens.length > 0 ? uniqueScreens[0] : null
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
                    mpris: mprisController
                    barLayout: shellRoot.barLayoutState
                    theme: shellRoot.shellTheme
                    terminal: terminalController
                    shellDir: shellRoot.shellDir
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
                barHeight: shellRoot.barHeight
                screen: appLauncher.screen
                homeDir: shellRoot.homeDir
                shellDir: shellRoot.shellDir
                terminal: terminalController
            }
        }
    }

    ClipboardFeature.ClipboardController {
        id: clipboardStore
        backend: shellRoot.shellBackend
    }

    App.LazyPopup {
        id: clipboardHistory
        popupComponent: Component {
            ClipboardFeature.ClipboardPopup {
                theme: shellRoot.shellTheme
                barHeight: shellRoot.barHeight
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
                wallpaperController: wallpaperStore
                barHeight: shellRoot.barHeight
                mode: themeSwitcher.mode
                screen: themeSwitcher.screen
                onModeRequested: (nextMode) => themeSwitcher.mode = nextMode
            }
        }
    }

    App.LazyPopup {
        id: audioPopup
        popupComponent: Component {
            AudioFeature.AudioPopup {
                theme: shellRoot.shellTheme
                barHeight: shellRoot.barHeight
                screen: audioPopup.screen
            }
        }
    }

    App.LazyPopup {
        id: connectivityPopup
        mode: "network"
        popupComponent: Component {
            ConnectivityFeature.ConnectivityPopup {
                theme: shellRoot.shellTheme
                barHeight: shellRoot.barHeight
                backend: shellRoot.shellBackend
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
                barHeight: shellRoot.barHeight
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
                barHeight: shellRoot.barHeight
                statusController: bluetoothStatusController
                screen: bluetoothPopup.screen
                shellDir: shellRoot.shellDir
            }
        }
    }

    App.LazyPopup {
        id: removablePopup
        popupComponent: Component {
            RemovableFeature.RemovableDevicePopup {
                theme: shellRoot.shellTheme
                barHeight: shellRoot.barHeight
                deviceController: removableDeviceController
                screen: removablePopup.screen
            }
        }
    }

    // Az about nem popup: egy lebego kitty ablak, amiben a fastfetch fut.
    AboutFeature.FastfetchTerminal {
        id: aboutTerminal
        shellDir: shellRoot.shellDir
    }

    App.LazyPopup {
        id: aiPopup
        popupComponent: Component {
            AiFeature.AiUsagePopup {
                theme: shellRoot.shellTheme
                barHeight: shellRoot.barHeight
                screen: aiPopup.screen
                shellDir: shellRoot.shellDir
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
        barHeight: shellRoot.barHeight
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
        aboutTerminal: aboutTerminal
        notifications: notifications
        trayMenu: trayMenu
        onCalendarRefreshRequested: shellRoot.calendarNow = new Date()
    }

    App.ShellIpc {
        coordinator: popupCoordinator
        lockProvider: lockRoot
        focusedScreenProvider: function() { return shellRoot.focusedScreen() }
        screenshotCaptureProvider: function(mode) { screenshotController.capture(mode) }
        activePlayer: shellRoot.activePlayer
        mediaController: mprisController
        audioController: audioSummaryController
        brightnessController: brightnessController
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

    // TOPBAR LÉTREHOZÁSA (DMS stílusú Instantiatorral)
    Instantiator {
        model: shellRoot.uniqueScreens
        delegate: BarUi.BarWindow {
            required property var modelData

            targetScreen: modelData
            theme: shellRoot.shellTheme
            barHeight: shellRoot.barHeight
            shellDir: shellRoot.shellDir
            visibleWorkspaceIds: shellRoot.visibleWorkspaceIds
            occupiedWorkspaceIds: shellRoot.occupiedWorkspaceIds
            layoutController: shellRoot.barLayoutState
            activePlayer: shellRoot.activePlayer
            hasMediaSource: mprisController.players.length > 0
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
            onTrayMenuRequested: (model, globalX) => popupCoordinator.openTrayMenu(targetScreen, model, globalX)
        }
    }

    App.LazyPopup {
        id: mediaPopup
        // A valasztott lejatszo a kozos MprisControllerben el: a sav jelzoje is
        // ugyanazt mutatja, es a popup lebontasa utan is megmarad.
        property alias selectedPlayerDbusName: mprisController.pinnedDbusName
        // Az IPC kerhet kinagyitott kartyat ("calendar" / "weather"); csak az
        // adott megnyitasra szol, zaraskor torlodik.
        property string initialCard: ""
        onOpenedChanged: if (!opened) initialCard = ""
        popupComponent: Component {
            MediaFeature.MediaPopup {
                stats: systemStats
                players: mprisController.players
                initialCard: mediaPopup.initialCard
                backend: shellRoot.shellBackend
                theme: shellRoot.shellTheme
                screen: mediaPopup.screen
                selectedPlayerDbusName: mediaPopup.selectedPlayerDbusName
                barHeight: shellRoot.barHeight
                activePlayer: shellRoot.activePlayer
                cavaValues: cavaController.spectrum
                calendarNow: shellRoot.calendarNow
                monthNames: shellRoot.monthNames
                dayNames: shellRoot.dayNames
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

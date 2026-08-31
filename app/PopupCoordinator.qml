import QtQuick

// A fedoreteg-popupok kolcsonos kizarasa egyetlen helyen.
//
// Korabban tiz `setXOpen()` fuggveny sorolta fel kezzel a tobbi tizenegy popup
// zarasat. A masolatok szet is csusztak: a notifications nyitasa nyitva hagyta a
// privacy panelt, a launcher/clipboard/appearance pedig a media popupot. Itt
// egyetlen lista (`overlayNames`) a forras -- uj popup felvetele egy sor, es a
// kizaras onmagatol teljes marad.
//
// A settings SZANDEKOSAN nincs a listaban: az igazi ablak, nem overlay, tehat
// nem takarja el a shellt. Csak azt a ket feluletet zarja, amibol el szoktak
// inditani.
QtObject {
    id: coordinator

    required property var settings
    required property var launcher
    required property var clipboard
    required property var themeSwitcher
    required property var mediaPopup
    required property var audioPopup
    required property var connectivityPopup
    required property var bluetoothPopup
    required property var removablePopup
    required property var privacyPopup
    required property var aiPopup
    required property var vpnCli
    required property var aboutPopup
    required property var notifications

    signal calendarRefreshRequested()

    readonly property var overlayNames: [
        "launcher",
        "clipboard",
        "themeSwitcher",
        "media",
        "audio",
        "connectivity",
        "bluetooth",
        "removable",
        "privacy",
        "ai",
        "about",
        "notifications"
    ]

    function overlayItem(name) {
        switch (name) {
        case "launcher": return launcher
        case "clipboard": return clipboard
        case "themeSwitcher": return themeSwitcher
        case "media": return mediaPopup
        case "audio": return audioPopup
        case "connectivity": return connectivityPopup
        case "bluetooth": return bluetoothPopup
        case "removable": return removablePopup
        case "privacy": return privacyPopup
        case "ai": return aiPopup
        case "about": return aboutPopup
        case "notifications": return notifications
        }
        return null
    }

    // A notifications sajat feluletet hasznal (`menuOpened` / `setMenuOpen`),
    // ezert az allapotat mindig ezen a harom fuggvenyen keresztul erjuk el.
    function isOverlayOpen(name) {
        if (name === "notifications") return notifications.menuOpened === true
        var item = overlayItem(name)
        return !!item && item.opened === true
    }

    function overlayScreen(name) {
        var item = overlayItem(name)
        return item ? item.screen : null
    }

    function closeOverlays(except) {
        for (var i = 0; i < overlayNames.length; i++) {
            var name = overlayNames[i]
            if (name === except) continue
            if (name === "notifications") notifications.menuOpened = false
            else overlayItem(name).opened = false
        }
    }

    // Az egyetlen belepesi pont: nyitaskor bezarja az osszes tobbi fedoreteget,
    // atallitja a kepernyot, majd nyit. Zaraskor csak a sajat allapotat allitja.
    function setOverlayOpen(name, open, nextScreen) {
        if (open) closeOverlays(name)

        if (name === "notifications") {
            notifications.setMenuOpen(open, nextScreen)
            return
        }

        var item = overlayItem(name)
        if (open && nextScreen) item.screen = nextScreen
        item.opened = open
    }

    // Ugyanazon a kepernyon ujra kerve zar, masikon atkoltozik.
    function toggleOverlay(name, nextScreen) {
        var openHere = isOverlayOpen(name) && nextScreen && overlayScreen(name) === nextScreen
        setOverlayOpen(name, !openHere, nextScreen)
    }

    // -- notifications -------------------------------------------------------

    function setNotificationsOpen(open, nextScreen) {
        setOverlayOpen("notifications", open, nextScreen)
    }

    function toggleNotifications(nextScreen) {
        toggleOverlay("notifications", nextScreen)
    }

    function toggleNotificationsDnd() {
        notifications.dnd = !notifications.dnd
    }

    function clearNotifications() {
        notifications.clearHistory()
    }

    function toggleNotificationsGrouping() {
        notifications.grouping = !notifications.grouping
    }

    function setNotificationGroupsExpanded(expanded) {
        notifications.setAllGroupsExpanded(expanded)
    }

    // -- settings ------------------------------------------------------------

    function setSettingsOpen(open) {
        if (open) {
            launcher.opened = false
            clipboard.opened = false
        }
        settings.opened = open
    }

    function toggleSettings() {
        setSettingsOpen(!settings.opened)
    }

    // -- egyszeru fedoretegek ------------------------------------------------

    function setLauncherOpen(open, nextScreen) { setOverlayOpen("launcher", open, nextScreen) }
    function toggleLauncher(nextScreen) { toggleOverlay("launcher", nextScreen) }

    function setClipboardOpen(open, nextScreen) { setOverlayOpen("clipboard", open, nextScreen) }
    function toggleClipboard(nextScreen) { toggleOverlay("clipboard", nextScreen) }

    function setAudioOpen(open, nextScreen) { setOverlayOpen("audio", open, nextScreen) }
    function toggleAudio(nextScreen) { toggleOverlay("audio", nextScreen) }

    // A billentyukombinacio nem tudja, melyik kepernyon all a panel; ilyenkor
    // csak az allapotot valtjuk, a helyet nem.
    function toggleAudioScreenAgnostic() {
        setAudioOpen(!audioPopup.opened)
    }

    function setAboutOpen(open, nextScreen) { setOverlayOpen("about", open, nextScreen) }
    function toggleAbout(nextScreen) { toggleOverlay("about", nextScreen) }

    function setBluetoothOpen(open, nextScreen) { setOverlayOpen("bluetooth", open, nextScreen) }
    function toggleBluetooth(nextScreen) { toggleOverlay("bluetooth", nextScreen) }

    function setRemovableOpen(open, nextScreen) { setOverlayOpen("removable", open, nextScreen) }
    function toggleRemovable(nextScreen) { toggleOverlay("removable", nextScreen) }

    function setPrivacyOpen(open, nextScreen) { setOverlayOpen("privacy", open, nextScreen) }
    function togglePrivacy(nextScreen) { toggleOverlay("privacy", nextScreen) }

    function setAiOpen(open, nextScreen) { setOverlayOpen("ai", open, nextScreen) }
    function toggleAi(nextScreen) { toggleOverlay("ai", nextScreen) }

    // -- media ---------------------------------------------------------------

    // A naptar a nyitas pillanataban ervenyes datumot mutassa, ne azt, amivel a
    // shell elindult.
    function toggleCenterPopup(nextScreen) {
        calendarRefreshRequested()
        toggleOverlay("media", nextScreen)
    }

    // -- appearance ----------------------------------------------------------

    function setThemeSwitcherOpen(open, nextMode, nextScreen) {
        if (open && nextMode) themeSwitcher.mode = nextMode
        setOverlayOpen("themeSwitcher", open, nextScreen)
    }

    function closeThemeSwitcher() {
        setThemeSwitcherOpen(false, themeSwitcher.mode, themeSwitcher.screen)
    }

    // -- halozat es VPN ------------------------------------------------------

    // A Wi-Fi es a VPN egy panelben lakik; a `mode` csak azt valasztja ki,
    // melyik fulon nyilik meg.
    function setConnectivityOpen(open, mode, nextScreen) {
        if (open && mode) connectivityPopup.mode = mode
        setOverlayOpen("connectivity", open, nextScreen)
    }

    // Egy nem mutatott fulet kerve atvaltunk ra, ahelyett hogy bezarnank a
    // panelt, ami epp egy masik kerdesre valaszolt.
    function toggleConnectivity(mode, nextScreen) {
        var openHere = connectivityPopup.opened && nextScreen && connectivityPopup.screen === nextScreen
        if (openHere && mode && connectivityPopup.mode !== mode) {
            connectivityPopup.mode = mode
            return
        }
        setConnectivityOpen(!openHere, mode, nextScreen)
    }

    function setNetworkOpen(open, nextScreen) { setConnectivityOpen(open, "network", nextScreen) }
    function toggleNetwork(nextScreen) { toggleConnectivity("network", nextScreen) }

    function setVpnOpen(open, nextScreen) { setConnectivityOpen(open, "vpn", nextScreen) }
    function toggleVpn(nextScreen) { toggleConnectivity("vpn", nextScreen) }

    // A panel a muvelettel egyutt nyilik, hogy egy billentyukombinacio is adjon
    // lathato visszajelzest, amig a CLI dolgozik.
    function vpnQuickConnect(nextScreen) {
        setVpnOpen(true, nextScreen)
        vpnCli.connectFastest()
    }

    function vpnDisconnect(nextScreen) {
        setVpnOpen(true, nextScreen)
        vpnCli.disconnectVpn()
    }

    function vpnOpenApp() {
        setVpnOpen(false)
        vpnCli.openApp()
    }
}

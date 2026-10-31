pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// A settings app. A shell tobbi felulete layer-shell overlay, ez viszont igazi
// xdg-toplevel: atmeretezheto, a Hyprland ablakkent kezeli, es nyitva maradhat
// munka kozben. Ezert nem `App.LazyPopup` kezeli, hanem a shell.qml sajat
// Loadere.
FloatingWindow {
    id: window

    property var backend: null
    property var barLayout: null
    property var mpris: null
    property var theme: null
    property var terminal: null
    required property string shellDir
    property alias activePage: settingsController.activePage

    readonly property string background: theme ? theme.background : "#11130f"
    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"

    // Az oldalak sorrendje es csoportja az oldalsavban. A `keywords` a kereso
    // talalatait boviti: az oldalon allithato dolgok nevei, amelyek a cimben
    // nem szerepelnek.
    readonly property var pages: [{
        "id": "display",
        "label": "Display",
        "icon": "󰍹",
        "group": "Desktop",
        "description": "Arrange your displays and set their mode, scale and rotation.",
        "keywords": "monitor screen resolution refresh rate hz scale orientation rotate vrr arrangement output"
    }, {
        "id": "windows",
        "label": "Windows",
        "icon": "󰖯",
        "group": "Desktop",
        "description": "Tiling, gaps, borders and compositor effects for application windows.",
        "keywords": "gaps border tiling dwindle master layout rounding corner opacity blur shadow animations"
    }, {
        "id": "input",
        "label": "Input",
        "icon": "󰌌",
        "group": "Desktop",
        "description": "Keyboard layout, pointer speed and touchpad behaviour.",
        "keywords": "keyboard layout variant repeat delay mouse pointer sensitivity focus follows touchpad natural scrolling tap click"
    }, {
        "id": "topbar",
        "label": "Top bar",
        "icon": "󰍜",
        "group": "Shell",
        "description": "Arrange the top bar modules and choose which media players appear.",
        "keywords": "bar panel modules widgets layout media players mpris ignore hidden"
    }, {
        "id": "calendar",
        "label": "Calendar",
        "icon": "󰃭",
        "group": "Shell",
        "description": "Connect Google Calendar to show your events in the calendar panel.",
        "keywords": "google events oauth sign in account sync"
    }, {
        "id": "keybindings",
        "label": "Keybindings",
        "icon": "󰌆",
        "group": "Shell",
        "description": "Every shortcut Hyprland currently has bound.",
        "keywords": "shortcuts hotkeys keys binds"
    }, {
        "id": "defaults",
        "label": "Default apps",
        "icon": "󰏖",
        "group": "System",
        "description": "Pick the application that opens each kind of file and link.",
        "keywords": "default applications browser mail file manager terminal mime associations"
    }, {
        "id": "autostart",
        "label": "Autostart",
        "icon": "󰑓",
        "group": "System",
        "description": "Applications that start at login and your systemd user services.",
        "keywords": "login startup services systemd units"
    }, {
        "id": "system",
        "label": "System",
        "icon": "󰒓",
        "group": "System",
        "description": "Shell services, diagnostics and maintenance.",
        "keywords": "weather location power profile lock screen idle diagnostics backend daemon reset network hyprland"
    }]
    readonly property var currentPage: {
        for (var i = 0; i < pages.length; i++) {
            if (pages[i].id === settingsController.activePage)
                return pages[i];
        }
        return pages[0];
    }
    signal closeRequested()

    // A `settingsController` sajat `opened` bindingjere ujratolt, a tobbi
    // controller viszont nem figyeli az ablakot -- azokat itt inditjuk. Igy a
    // shell.qml-nek nem kell az ablak eletciklusaba nyulnia.
    function reload() {
        settingsController.reload();
        systemState.reload();
        defaultAppsState.reload();
        autostartState.reload();
        keybindingsState.reload();
    }

    Component.onCompleted: {
        systemState.reload();
        defaultAppsState.reload();
        autostartState.reload();
        keybindingsState.reload();
    }

    onVisibleChanged: {
        if (visible) {
            systemState.reload();
            defaultAppsState.reload();
            autostartState.reload();
            keybindingsState.reload();
        }
    }

    title: "Vellum Settings"
    minimumSize: Qt.size(840, 580)
    implicitWidth: 1080
    implicitHeight: 720
    color: background

    SettingsController {
        id: settingsController

        backend: window.backend
        theme: window.theme
        opened: window.visible
    }

    SystemController {
        id: systemState

        backend: window.backend
        shellDir: window.shellDir
    }

    DefaultAppsController {
        id: defaultAppsState
        terminal: window.terminal
    }

    AutostartController {
        id: autostartState
        shellDir: window.shellDir
    }

    KeybindingsController {
        id: keybindingsState
        shellDir: window.shellDir
    }

    // Oldalvaltas a tartalombol is: Ctrl+Tab / Ctrl+Shift+Tab es
    // Ctrl+PgDown / Ctrl+PgUp lep, a Ctrl+F az oldalsav keresojebe visz.
    function stepPage(delta) {
        var at = 0;
        for (var i = 0; i < pages.length; i++) {
            if (pages[i].id === settingsController.activePage)
                at = i;
        }
        settingsController.activePage = pages[(at + delta + pages.length) % pages.length].id;
    }

    // A shell mas felulete nem kap fokuszt, amig ez az ablak nyitva van, ezert
    // az Escape itt is zar -- ugyanaz a reflex, mint a popupoknal.
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: window.closeRequested()

        // A Shortcut-nak ablakbeli Item szulo kell: a FloatingWindow maga nem
        // QQuickWindow, alatta nem regisztralna.
        Shortcut {
            sequences: ["Ctrl+Tab", "Ctrl+PgDown"]
            onActivated: window.stepPage(1)
        }

        Shortcut {
            sequences: ["Ctrl+Shift+Tab", "Ctrl+Backtab", "Ctrl+PgUp"]
            onActivated: window.stepPage(-1)
        }

        Shortcut {
            sequences: [StandardKey.Find]
            onActivated: sidebar.focusSearch()
        }

        SettingsSidebar {
            id: sidebar

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 248
            theme: window.theme
            pages: window.pages
            activePage: settingsController.activePage
            backendOnline: settingsController.backendAvailable
            backendChecking: settingsController.loading
            onSelected: (page) => settingsController.activePage = page
        }

        Item {
            id: contentPane

            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            // A sorok szeles ablakban se nyuljanak szet: a tartalom legfeljebb
            // ilyen szeles, es a panel kozepere kerul.
            readonly property int maxContentWidth: 840

            Item {
                id: content

                // Oldalvaltaskor a fejlec es a lap puhan, par pixelrol ul be.
                property real reveal: 1

                anchors.top: parent.top
                anchors.topMargin: 28
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 24
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - 64, contentPane.maxContentWidth)

                NumberAnimation {
                    id: pageReveal

                    target: content
                    property: "reveal"
                    from: 0
                    to: 1
                    duration: 260
                    easing.type: Easing.OutCubic
                }

                Connections {
                    target: settingsController

                    function onActivePageChanged() {
                        pageReveal.restart();
                    }
                }

                Column {
                    id: pageHeader

                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 4
                    opacity: content.reveal

                    Text {
                        width: parent.width
                        text: window.currentPage.label
                        color: window.foreground
                        font.family: "serif"
                        font.pixelSize: 24
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: window.currentPage.description
                        color: window.muted
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                }

                // Daemon nelkul a Hyprland-oldalak csak olvashatok. Ezt csak
                // ott mondjuk, ahol szamit, nem minden oldal tetejen.
                Rectangle {
                    id: notice

                    readonly property color warningColor: window.theme && window.theme.warning ? window.theme.warning : "#c9693f"

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: pageHeader.bottom
                    anchors.topMargin: visible ? 16 : 0
                    height: visible ? 44 : 0
                    visible: pageLoader.hyprPage && !settingsController.backendAvailable && !settingsController.loading
                    radius: 10
                    color: Qt.rgba(notice.warningColor.r, notice.warningColor.g, notice.warningColor.b, 0.12)
                    opacity: content.reveal

                    Text {
                        id: noticeGlyph

                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰀦"
                        color: notice.warningColor
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 16
                    }

                    Text {
                        anchors.left: noticeGlyph.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: "The Vellum daemon is not reachable, so these Hyprland settings are read-only."
                        color: window.foreground
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                Loader {
                    id: pageLoader

                    readonly property bool hyprPage: settingsController.activePage === "display"
                        || settingsController.activePage === "windows"
                        || settingsController.activePage === "input"

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: notice.bottom
                    anchors.topMargin: 24
                    anchors.bottom: parent.bottom
                    asynchronous: false
                    // Letiltva a sorok maguk halvanyulnak; itt nem halvanyitunk
                    // meg egyszer, kulonben a szoveg olvashatatlanra fakulna.
                    enabled: !hyprPage || settingsController.backendAvailable
                    opacity: content.reveal
                    transform: Translate {
                        y: Math.round((1 - content.reveal) * 10)
                    }
                    sourceComponent: {
                        switch (settingsController.activePage) {
                        case "windows":
                            return windowsPage;
                        case "input":
                            return inputPage;
                        case "topbar":
                            return topbarPage;
                        case "defaults":
                            return defaultAppsPage;
                        case "calendar":
                            return calendarPage;
                        case "system":
                            return systemPage;
                        case "autostart":
                            return autostartPage;
                        case "keybindings":
                            return keybindingsPage;
                        default:
                            return displayPage;
                        }
                    }
                }
            }
        }

    }

    Component {
        id: displayPage

        DisplayPage {
            controller: settingsController
            theme: window.theme
        }

    }

    Component {
        id: windowsPage

        WindowsPage {
            controller: settingsController
            theme: window.theme
        }

    }

    Component {
        id: inputPage

        InputPage {
            controller: settingsController
            theme: window.theme
        }

    }

    Component {
        id: topbarPage

        BarLayoutPage {
            controller: window.barLayout
            mpris: window.mpris
            theme: window.theme
        }

    }

    Component {
        id: defaultAppsPage

        DefaultAppsPage {
            controller: defaultAppsState
            theme: window.theme
        }

    }

    Component {
        id: calendarPage

        CalendarPage {
            backend: window.backend
            theme: window.theme
        }

    }

    Component {
        id: systemPage

        SystemPage {
            controller: settingsController
            systemController: systemState
            theme: window.theme
        }

    }

    Component {
        id: autostartPage

        AutostartPage {
            controller: autostartState
            theme: window.theme
        }

    }

    Component {
        id: keybindingsPage

        KeybindingsPage {
            controller: keybindingsState
            theme: window.theme
        }

    }

}

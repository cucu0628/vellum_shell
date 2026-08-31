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
    property var theme: null
    property alias activePage: settingsController.activePage

    readonly property string background: theme ? theme.background : "#11130f"
    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"

    readonly property var pages: [{
        "id": "display",
        "label": "Display",
        "icon": "󰍹"
    }, {
        "id": "windows",
        "label": "Windows",
        "icon": "󰖯"
    }, {
        "id": "input",
        "label": "Input",
        "icon": "󰌌"
    }, {
        "id": "system",
        "label": "System",
        "icon": "󰒓"
    }, {
        "id": "keybindings",
        "label": "Keybindings",
        "icon": "󰌆"
    }, {
        "id": "packages",
        "label": "Packages",
        "icon": "󰏗"
    }]

    signal closeRequested()

    // A `settingsController` sajat `opened` bindingjere ujratolt, a masik ketto
    // viszont nem figyeli az ablakot -- azokat itt inditjuk. Igy a shell.qml-nek
    // nem kell az ablak eletciklusaba nyulnia.
    function reload() {
        settingsController.reload();
        systemState.reload();
        keybindingsState.reload();
    }

    Component.onCompleted: {
        systemState.reload();
        keybindingsState.reload();
    }

    onVisibleChanged: {
        if (visible) {
            systemState.reload();
            keybindingsState.reload();
        }
    }

    title: "Vellum Settings"
    minimumSize: Qt.size(820, 560)
    implicitWidth: 1040
    implicitHeight: 700
    color: background

    SettingsController {
        id: settingsController

        backend: window.backend
        theme: window.theme
        opened: window.visible
    }

    SystemController {
        id: systemState
    }

    KeybindingsController {
        id: keybindingsState
    }

    // A shell mas felulete nem kap fokuszt, amig ez az ablak nyitva van, ezert
    // az Escape itt is zar -- ugyanaz a reflex, mint a popupoknal.
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: window.closeRequested()

        SettingsSidebar {
            id: sidebar

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 208
            theme: window.theme
            pages: window.pages
            activePage: settingsController.activePage
            onSelected: (page) => settingsController.activePage = page
        }

        Rectangle {
            id: banner

            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.top: parent.top
            height: visible ? 34 : 0
            visible: !settingsController.backendAvailable && !settingsController.loading
            color: window.theme && window.theme.surface ? window.theme.surface : "#1b1613"

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                text: "The Vellum daemon is not reachable, so Hyprland settings are read-only."
                color: window.muted
                font.pixelSize: 11
            }

        }

        Loader {
            id: pageLoader

            readonly property bool hyprPage: settingsController.activePage === "display"
                || settingsController.activePage === "windows"
                || settingsController.activePage === "input"

            anchors.left: sidebar.right
            anchors.leftMargin: 24
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.top: banner.bottom
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            asynchronous: false
            enabled: !hyprPage || settingsController.backendAvailable
            opacity: enabled ? 1 : 0.45
            sourceComponent: {
                switch (settingsController.activePage) {
                case "windows":
                    return windowsPage;
                case "input":
                    return inputPage;
                case "system":
                    return systemPage;
                case "keybindings":
                    return keybindingsPage;
                case "packages":
                    return packagesPage;
                default:
                    return displayPage;
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
        id: systemPage

        SystemPage {
            controller: settingsController
            systemController: systemState
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

    Component {
        id: packagesPage

        PackagesPage {
            controller: settingsController
            theme: window.theme
        }

    }

}

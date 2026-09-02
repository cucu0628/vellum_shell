pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../ui" as SharedUi

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
        "icon": "󰍹",
        "description": "Outputs, scale and physical arrangement",
        "group": "WORKSPACE",
        "startsGroup": true
    }, {
        "id": "windows",
        "label": "Windows",
        "icon": "󰖯",
        "description": "Tiling geometry, borders and visual effects",
        "group": "WORKSPACE",
        "startsGroup": false
    }, {
        "id": "input",
        "label": "Input",
        "icon": "󰌌",
        "description": "Keyboard, pointer and touchpad behaviour",
        "group": "WORKSPACE",
        "startsGroup": false
    }, {
        "id": "system",
        "label": "System",
        "icon": "󰒓",
        "description": "Shell services, power and external tools",
        "group": "SHELL",
        "startsGroup": true
    }, {
        "id": "keybindings",
        "label": "Keybindings",
        "icon": "󰌆",
        "description": "A searchable index of active shortcuts",
        "group": "SHELL",
        "startsGroup": false
    }]
    readonly property var currentPage: {
        for (var i = 0; i < pages.length; i++) {
            if (pages[i].id === settingsController.activePage)
                return pages[i];
        }
        return pages[0];
    }
    readonly property int currentPageIndex: {
        for (var i = 0; i < pages.length; i++) {
            if (pages[i].id === settingsController.activePage)
                return i;
        }
        return 0;
    }

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
            width: 232
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
            height: visible ? 38 : 0
            visible: !settingsController.backendAvailable && !settingsController.loading
            color: window.theme && window.theme.surface ? window.theme.surface : "#1b1613"

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 28
                anchors.verticalCenter: parent.verticalCenter
                text: "The Vellum daemon is not reachable, so Hyprland settings are read-only."
                color: window.muted
                font.pixelSize: 11
            }

        }

        SharedUi.PopupHeader {
            id: pageHeader

            anchors.left: sidebar.right
            anchors.leftMargin: 28
            anchors.right: parent.right
            anchors.rightMargin: 28
            anchors.top: banner.bottom
            anchors.topMargin: 20
            theme: window.theme
            title: window.currentPage.label
            subtitle: window.currentPage.description
            trailingWidth: 58

            Text {
                anchors.right: parent.right
                anchors.top: parent.top
                text: (window.currentPageIndex + 1).toString().padStart(2, "0") + " / " + window.pages.length.toString().padStart(2, "0")
                color: window.muted
                font.family: "monospace"
                font.pixelSize: 9
                font.letterSpacing: 1
            }
        }

        Loader {
            id: pageLoader

            readonly property bool hyprPage: settingsController.activePage === "display"
                || settingsController.activePage === "windows"
                || settingsController.activePage === "input"

            anchors.left: sidebar.right
            anchors.leftMargin: 28
            anchors.right: parent.right
            anchors.rightMargin: 28
            anchors.top: pageHeader.bottom
            anchors.topMargin: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 22
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
                default:
                    return displayPage;
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 2
            color: window.theme ? window.theme.accent : "#b7372f"
            z: 100
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

}

import QtQuick
import Quickshell
import Quickshell.Wayland
import "." as ConnectivityUi
import "../../ui" as SharedUi

// Wi-Fi and VPN share one bar module, so they also share one panel: the tabs
// swap the body while the window, its size animation and its focus stay put.
// Only the visible tab is `active`, which keeps Wi-Fi scan requests and the
// (slow) protonvpn CLI off the tab nobody is looking at.
PanelWindow {
    id: connectivityWindow

    property var theme: null
    property var backend: null
    property var statusController: null
    property var vpnCli: null
    property bool opened: false
    property int barHeight: 26
    property int currentTab: 0
    readonly property bool vpnTab: currentTab === 1
    readonly property int panelHeight: vpnTab ? vpnPanel.preferredHeight : networkPanel.preferredHeight
    readonly property string panelBg: theme ? theme.background : "#15110f"
    readonly property string panelFg: theme ? theme.foreground : "#f1e7d0"
    readonly property string panelAccent: theme ? theme.accent : "#d7472f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#9f8f7c"
    readonly property string inkBg: theme && theme.surface ? theme.surface : "#1b1613"

    visible: opened || sheet.reveal > 0
    color: "transparent"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "quickshell.connectivity"
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    MouseArea {
        anchors.fill: parent
        enabled: opened
        onClicked: opened = false
    }

    Item {
        id: content

        focus: connectivityWindow.opened
        Keys.onEscapePressed: connectivityWindow.opened = false
        anchors.right: parent.right
        anchors.rightMargin: 0
        enabled: opened
        // A sav aljahoz tapad: a panel a savbol nyilik le, nem lebeg alatta.
        y: connectivityWindow.barHeight
        width: Math.min(430, parent.width - 20)
        height: Math.min(connectivityWindow.panelHeight + 74, parent.height - connectivityWindow.barHeight - 12)
        clip: true

        SharedUi.PopupFrame {
            id: sheet
            rightEar: false
            squareRight: true
            shown: connectivityWindow.opened
            anchors.fill: parent
            theme: connectivityWindow.theme

            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => {
                    return mouse.accepted = true;
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Row {
                    id: tabs

                    width: parent.width
                    height: 30
                    spacing: 6

                    Repeater {
                        model: [{
                            "icon": "󰤨",
                            "label": "Network"
                        }, {
                            "icon": "󰦝",
                            "label": "VPN"
                        }]

                        Rectangle {
                            id: tab

                            required property int index
                            required property var modelData
                            readonly property bool selected: connectivityWindow.currentTab === index
                            readonly property string labelColor: selected || tabMouse.containsMouse ? panelFg : mutedFg

                            width: (tabs.width - tabs.spacing) / 2
                            height: tabs.height
                            color: "transparent"

                            // Egyetlen jelzo az elso tabon, ami a kivalasztotthoz csuszik.
                            Rectangle {
                                visible: tab.index === 0
                                anchors.bottom: parent.bottom
                                x: connectivityWindow.currentTab * (tab.width + tabs.spacing) + (tab.width - width) / 2
                                width: 72
                                height: 2
                                color: panelAccent
                                Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 7

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.modelData.icon
                                    color: tab.selected ? panelAccent : mutedFg
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 13
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.modelData.label
                                    color: tab.labelColor
                                    font.pixelSize: 12
                                    font.weight: tab.selected ? Font.Medium : Font.Normal
                                }

                                // A live dot for the tab that is not on screen,
                                // so the merged module still reports both states.
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 6
                                    height: 6
                                    radius: 3
                                    visible: tab.index === 0
                                        ? (statusController && statusController.connected)
                                        : (vpnCli && vpnCli.protonActive)
                                    color: panelAccent
                                }

                            }

                            SharedUi.Pressable {
                                id: tabMouse

                                anchors.fill: parent
                                theme: connectivityWindow.theme
                                accessibleName: tab.modelData.label
                                onClicked: connectivityWindow.currentTab = tab.index
                            }

                        }

                    }

                }

                Item {
                    width: parent.width
                    height: parent.height - tabs.height - parent.spacing

                    NetworkPanel {
                        id: networkPanel

                        anchors.fill: parent
                        visible: !connectivityWindow.vpnTab
                        theme: connectivityWindow.theme
                        backend: connectivityWindow.backend
                        statusController: connectivityWindow.statusController
                        active: connectivityWindow.opened && !connectivityWindow.vpnTab
                        onCloseRequested: connectivityWindow.opened = false
                    }

                    ConnectivityUi.VpnPanel {
                        id: vpnPanel

                        anchors.fill: parent
                        visible: connectivityWindow.vpnTab
                        theme: connectivityWindow.theme
                        controller: connectivityWindow.vpnCli
                        active: connectivityWindow.opened && connectivityWindow.vpnTab
                        onCloseRequested: connectivityWindow.opened = false
                    }

                }

            }

        }

        Behavior on height {
            NumberAnimation {
                duration: 210
                easing.type: Easing.OutCubic
            }

        }

    }

}

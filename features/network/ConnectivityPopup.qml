import QtQuick
import Quickshell
import Quickshell.Wayland
import "../vpn" as VpnFeature
import "../../ui" as SharedUi

// Wi-Fi and VPN share one bar module, so they also share one panel: the tabs
// swap the body while the window, its size animation and its focus stay put.
// Only the visible tab is `active`, which keeps nmcli scans and the (slow)
// protonvpn CLI off the tab nobody is looking at.
PanelWindow {
    id: connectivityWindow

    property var theme: null
    property var statusController: null
    property var vpnCli: null
    property bool opened: false
    property int currentTab: 0
    readonly property bool vpnTab: currentTab === 1
    readonly property int panelHeight: vpnTab ? vpnPanel.preferredHeight : networkPanel.preferredHeight
    readonly property string panelBg: theme ? theme.background : "#15110f"
    readonly property string panelFg: theme ? theme.foreground : "#f1e7d0"
    readonly property string panelAccent: theme ? theme.accent : "#d7472f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#9f8f7c"
    readonly property string inkBg: theme && theme.surface ? theme.surface : "#1b1613"

    visible: opened || content.opacity > 0
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

        anchors.right: parent.right
        anchors.rightMargin: 10
        enabled: opened
        y: 32
        width: Math.min(430, parent.width - 20)
        height: opened ? Math.min(connectivityWindow.panelHeight + 74, parent.height - 46) : 0
        clip: true
        opacity: opened ? 1 : 0

        SharedUi.PopupFrame {
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
                            "label": "NETWORK"
                        }, {
                            "icon": "󰦝",
                            "label": "VPN"
                        }]

                        Rectangle {
                            id: tab

                            required property int index
                            required property var modelData
                            readonly property bool selected: connectivityWindow.currentTab === index
                            readonly property string labelColor: selected ? panelAccent : (tabMouse.containsMouse ? panelFg : mutedFg)

                            width: (tabs.width - tabs.spacing) / 2
                            height: tabs.height
                            color: tabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.045) : "transparent"

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: tab.selected ? 2 : 1
                                color: tab.selected ? panelAccent : mutedFg
                                opacity: tab.selected ? 1 : 0.22
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 7

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.modelData.icon
                                    color: tab.labelColor
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 15
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.modelData.label
                                    color: tab.labelColor
                                    font.family: "monospace"
                                    font.pixelSize: 9
                                    font.letterSpacing: 2
                                    font.bold: true
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

                            MouseArea {
                                id: tabMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
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
                        statusController: connectivityWindow.statusController
                        active: connectivityWindow.opened && !connectivityWindow.vpnTab
                        onCloseRequested: connectivityWindow.opened = false
                    }

                    VpnFeature.VpnPanel {
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

        Behavior on opacity {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }

        }

    }

}

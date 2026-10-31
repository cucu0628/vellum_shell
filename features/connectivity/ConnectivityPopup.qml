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
        width: Math.min(420, parent.width - 20)
        height: Math.min(connectivityWindow.panelHeight + 76, parent.height - connectivityWindow.barHeight - 12)
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

                // A fulvalaszto egyben a panel cime: a kivalasztott fel egy
                // csendes, kerekitett lapka alatt all. Jobbra a Wi-Fi kapcsolo,
                // amig a halozati ful latszik.
                Item {
                    id: tabs

                    width: parent.width
                    height: 32

                    Rectangle {
                        id: tabTrack

                        width: Math.min(232, parent.width - wifiChip.width - 12)
                        height: parent.height
                        radius: 8
                        color: inkBg

                        Rectangle {
                            x: 2 + connectivityWindow.currentTab * (tabTrack.width - 4) / 2
                            y: 2
                            width: (tabTrack.width - 4) / 2
                            height: tabTrack.height - 4
                            radius: 6
                            color: Qt.rgba(1, 1, 1, 0.08)
                            Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.margins: 2

                            Repeater {
                                model: [{
                                    "icon": "󰤨",
                                    "label": "Network"
                                }, {
                                    "icon": "󰦝",
                                    "label": "VPN"
                                }]

                                Item {
                                    id: tab

                                    required property int index
                                    required property var modelData
                                    readonly property bool selected: connectivityWindow.currentTab === index

                                    width: (tabTrack.width - 4) / 2
                                    height: tabTrack.height - 4

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 8

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: tab.modelData.icon
                                            color: tab.selected ? panelFg : mutedFg
                                            font.family: "Symbols Nerd Font Mono"
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: tab.modelData.label
                                            color: tab.selected || tabMouse.containsMouse ? panelFg : mutedFg
                                            font.pixelSize: 12
                                            font.weight: tab.selected ? Font.Medium : Font.Normal
                                        }

                                        // A live dot for each side, so the merged
                                        // module still reports both states.
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
                                        focusRadius: 6
                                        accessibleName: tab.modelData.label
                                        accessibleRole: Accessible.PageTab
                                        onClicked: connectivityWindow.currentTab = tab.index
                                    }

                                }

                            }

                        }

                    }

                    SharedUi.HeaderChip {
                        id: wifiChip

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !connectivityWindow.vpnTab
                        enabled: !networkPanel.radioBusy
                        theme: connectivityWindow.theme
                        label: "Wi-Fi"
                        checkable: true
                        checked: networkPanel.wifiEnabled
                        accessibleName: networkPanel.wifiEnabled ? qsTr("Turn Wi-Fi off") : qsTr("Turn Wi-Fi on")
                        onClicked: networkPanel.toggleWifi()
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

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: popup

    property var theme: null
    property var deviceController: null
    property bool opened: false

    readonly property var devices: deviceController ? deviceController.devices : []
    readonly property string panelBg: theme ? theme.background : "#11130f"
    readonly property string panelFg: theme ? theme.foreground : "#e8ddc7"
    readonly property string panelAccent: theme ? theme.accent : "#b7372f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string inkBg: theme && theme.surface ? theme.surface : "#191b16"
    readonly property color hoverBg: Qt.rgba(1, 1, 1, 0.075)
    readonly property color lineBg: Qt.rgba(1, 1, 1, 0.07)

    function actionLabel(device) {
        if (deviceController && deviceController.busyPath === device.path) return "Busy"
        return device.mounted ? "Open" : "Mount"
    }

    function activate(device) {
        if (!deviceController || deviceController.busyPath !== "") return
        if (device.mounted) deviceController.open(device)
        else deviceController.mount(device.path)
    }

    onOpenedChanged: {
        if (opened && deviceController) {
            deviceController.errorMessage = ""
        }
    }

    visible: opened || content.opacity > 0
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "quickshell.removable"
    WlrLayershell.exclusiveZone: -1

    MouseArea {
        anchors.fill: parent
        enabled: popup.opened
        onClicked: popup.opened = false
    }

    Item {
        id: content
        anchors.right: parent.right
        anchors.rightMargin: 10
        y: 32
        width: Math.min(410, parent.width - 20)
        height: popup.opened ? Math.min(500, parent.height - 46, 104 + popup.devices.length * 78
            + (deviceController && deviceController.errorMessage !== "" ? 38 : 0)) : 0
        enabled: popup.opened
        opacity: popup.opened ? 1 : 0
        clip: true

        Behavior on height { NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            color: popup.panelBg
            border.color: popup.panelAccent
            border.width: 1
            clip: true

            MouseArea { anchors.fill: parent; onClicked: mouse => mouse.accepted = true }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Row {
                    width: parent.width
                    height: 36
                    spacing: 10

                    Rectangle {
                        width: 36
                        height: 36
                        color: popup.panelAccent

                        Text {
                            anchors.centerIn: parent
                            text: "󰕓"
                            color: popup.panelBg
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                        }
                    }

                    Column {
                        width: parent.width - 46
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: "REMOVABLE DEVICES"
                            color: popup.panelFg
                            font.pixelSize: 12
                            font.letterSpacing: 2.5
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: popup.devices.length + (popup.devices.length === 1 ? " volume available" : " volumes available")
                            color: popup.mutedFg
                            font.pixelSize: 9
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: parent.height - 46 - (deviceController && deviceController.errorMessage !== "" ? 28 : 0)

                    Text {
                        anchors.centerIn: parent
                        visible: popup.devices.length === 0
                        text: "No removable devices connected"
                        color: popup.mutedFg
                        font.pixelSize: 11
                    }

                    Flickable {
                        anchors.fill: parent
                        visible: popup.devices.length > 0
                        contentHeight: deviceColumn.height
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

                        Column {
                            id: deviceColumn
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: popup.devices

                                Rectangle {
                                    id: deviceRow
                                    required property var modelData
                                    readonly property bool busy: deviceController && (deviceController.busyPath === modelData.path
                                        || deviceController.busyPath === modelData.diskPath)

                                    width: deviceColumn.width
                                    height: 72
                                    color: popup.inkBg
                                    border.color: popup.lineBg
                                    opacity: busy ? 0.62 : 1

                                    Rectangle {
                                        anchors.left: parent.left
                                        width: 3
                                        height: parent.height
                                        color: deviceRow.modelData.mounted ? popup.panelAccent : popup.mutedFg
                                    }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: deviceRow.modelData.transport === "usb" ? "󰕓" : "󰋊"
                                        color: deviceRow.modelData.mounted ? popup.panelAccent : popup.panelFg
                                        font.family: "Symbols Nerd Font Mono"
                                        font.pixelSize: 22
                                    }

                                    Column {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 48
                                        anchors.right: actionRow.left
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 3

                                        Text {
                                            width: parent.width
                                            text: deviceRow.modelData.name
                                            color: popup.panelFg
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            text: deviceRow.modelData.size + "  ·  " + deviceRow.modelData.filesystem.toUpperCase()
                                            color: popup.mutedFg
                                            font.family: "monospace"
                                            font.pixelSize: 8
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            text: deviceRow.modelData.mounted ? deviceRow.modelData.mountpoint : "Not mounted"
                                            color: deviceRow.modelData.mounted ? popup.panelAccent : popup.mutedFg
                                            font.pixelSize: 9
                                            elide: Text.ElideMiddle
                                        }
                                    }

                                    Row {
                                        id: actionRow
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 5

                                        Rectangle {
                                            width: 58
                                            height: 30
                                            color: primaryMouse.containsMouse ? popup.panelAccent : "transparent"
                                            border.color: popup.panelAccent

                                            Text {
                                                anchors.centerIn: parent
                                                text: popup.actionLabel(deviceRow.modelData)
                                                color: primaryMouse.containsMouse ? popup.panelBg : popup.panelFg
                                                font.pixelSize: 9
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: primaryMouse
                                                anchors.fill: parent
                                                enabled: !deviceRow.busy
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: popup.activate(deviceRow.modelData)
                                            }
                                        }

                                        Rectangle {
                                            width: 58
                                            height: 30
                                            color: secondaryMouse.containsMouse ? popup.hoverBg : "transparent"
                                            border.color: popup.lineBg

                                            Text {
                                                anchors.centerIn: parent
                                                text: deviceRow.modelData.mounted ? "Unmount" : "Eject"
                                                color: popup.mutedFg
                                                font.pixelSize: 9
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: secondaryMouse
                                                anchors.fill: parent
                                                enabled: !deviceRow.busy
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (deviceRow.modelData.mounted) deviceController.unmount(deviceRow.modelData.path)
                                                    else deviceController.powerOff(deviceRow.modelData.diskPath)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: deviceController && deviceController.errorMessage !== ""
                    text: deviceController ? deviceController.errorMessage : ""
                    color: popup.panelAccent
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }
            }
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../ui" as SharedUi

PanelWindow {
    id: popup

    property var theme: null
    property var deviceController: null
    property bool opened: false
    property int barHeight: 26

    readonly property var devices: deviceController ? deviceController.devices : []
    readonly property string panelFg: theme ? theme.foreground : "#e8ddc7"
    readonly property string panelAccent: theme ? theme.accent : "#b7372f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property bool hasError: deviceController ? deviceController.errorMessage !== "" : false

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

    visible: opened || sheet.reveal > 0
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
        anchors.rightMargin: 0
        // A sav aljahoz tapad: a panel a savbol nyilik le, nem lebeg alatta.
        y: popup.barHeight
        width: Math.min(420, parent.width - 20)
        // Margok (32), fejlec es koz; soronkent 52 + 4.
        height: Math.min(500, parent.height - popup.barHeight - 12,
            44 + header.implicitHeight + Math.max(52, popup.devices.length * 56 - 4) + (popup.hasError ? 26 : 0))
        enabled: popup.opened
        clip: true

        Behavior on height { NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }

        SharedUi.PopupFrame {
            id: sheet
            rightEar: false
            squareRight: true
            shown: popup.opened
            anchors.fill: parent
            theme: popup.theme

            MouseArea { anchors.fill: parent; onClicked: mouse => mouse.accepted = true }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                SharedUi.PopupHeader {
                    id: header

                    width: parent.width
                    theme: popup.theme
                    title: "Removable"
                    // Ures listanal a lenti mondat mar elmondja.
                    subtitle: popup.devices.length === 0
                        ? ""
                        : popup.devices.length + (popup.devices.length === 1 ? " volume available" : " volumes available")
                }

                Item {
                    width: parent.width
                    height: parent.height - header.height - 12 - (popup.hasError ? 26 : 0)

                    Text {
                        anchors.centerIn: parent
                        visible: popup.devices.length === 0
                        text: "No removable drives connected."
                        color: popup.mutedFg
                        font.pixelSize: 12
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
                            spacing: 4

                            Repeater {
                                model: popup.devices

                                SharedUi.ListRow {
                                    id: deviceRow
                                    required property var modelData
                                    readonly property bool busy: deviceController && (deviceController.busyPath === modelData.path
                                        || deviceController.busyPath === modelData.diskPath)

                                    width: deviceColumn.width
                                    theme: popup.theme
                                    interactive: false
                                    active: modelData.mounted
                                    opacity: busy ? 0.6 : 1
                                    glyph: modelData.transport === "usb" ? "󰕓" : "󰋊"
                                    title: modelData.name
                                    // Csatolva a csatolasi pont a fontos, kulonben a fajlrendszer.
                                    subtitle: modelData.size + "  ·  " + (modelData.mounted
                                        ? modelData.mountpoint
                                        : modelData.filesystem.toUpperCase() + "  ·  Not mounted")
                                    subtitleElide: Text.ElideMiddle

                                    SharedUi.HeaderChip {
                                        theme: popup.theme
                                        emphasized: true
                                        enabled: !deviceRow.busy
                                        label: popup.actionLabel(deviceRow.modelData)
                                        accessibleName: (deviceRow.modelData.mounted ? qsTr("Open %1") : qsTr("Mount %1")).arg(deviceRow.modelData.name)
                                        onClicked: popup.activate(deviceRow.modelData)
                                    }

                                    SharedUi.HeaderChip {
                                        theme: popup.theme
                                        enabled: !deviceRow.busy
                                        label: deviceRow.modelData.mounted ? "Unmount" : "Eject"
                                        accessibleName: (deviceRow.modelData.mounted ? qsTr("Unmount %1") : qsTr("Eject %1")).arg(deviceRow.modelData.name)
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

                Text {
                    width: parent.width
                    height: 14
                    visible: popup.hasError
                    text: deviceController ? deviceController.errorMessage : ""
                    textFormat: Text.PlainText
                    color: popup.panelAccent
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }
    }
}

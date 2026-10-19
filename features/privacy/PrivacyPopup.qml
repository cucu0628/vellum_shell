import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../ui" as SharedUi

// Names whoever is holding the microphone or the camera. It sits on the left
// edge because the indicator that opens it lives next to the workspaces, and it
// closes itself once the last capture ends, so it never outlives its own icon.
PanelWindow {
    id: privacyWindow

    property var theme: null
    property var statusController: null
    property bool opened: false
    property int barHeight: 26

    readonly property var micUsers: statusController ? statusController.micUsers : []
    readonly property var cameraUsers: statusController ? statusController.cameraUsers : []
    readonly property bool anyActive: micUsers.length > 0 || cameraUsers.length > 0
    readonly property string panelBg: theme ? theme.background : "#15110f"
    readonly property string panelFg: theme ? theme.foreground : "#f1e7d0"
    readonly property string panelAccent: theme ? theme.accent : "#d7472f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#9f8f7c"
    readonly property string inkBg: theme && theme.surface ? theme.surface : "#1b1613"

    onAnyActiveChanged: if (!anyActive) opened = false

    visible: opened || sheet.reveal > 0
    color: "transparent"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "quickshell.privacy"
    WlrLayershell.exclusiveZone: -1

    anchors { top: true; bottom: true; left: true; right: true }

    MouseArea {
        anchors.fill: parent
        enabled: privacyWindow.opened
        onClicked: privacyWindow.opened = false
    }

    Item {
        id: content
        anchors.left: parent.left
        anchors.leftMargin: 0
        enabled: privacyWindow.opened
        // A sav aljahoz tapad: a panel a savbol nyilik le, nem lebeg alatta.
        y: privacyWindow.barHeight
        width: Math.min(340, parent.width - 20)
        height: Math.min(panel.implicitHeight + 32, parent.height - privacyWindow.barHeight - 12)
        clip: true

        SharedUi.PopupFrame {
            id: sheet
            leftEar: false
            shown: privacyWindow.opened
            anchors.fill: parent
            theme: privacyWindow.theme

            MouseArea { anchors.fill: parent; onClicked: mouse => mouse.accepted = true }

            Column {
                id: panel
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                SharedUi.PopupHeader {
                    width: parent.width
                    theme: privacyWindow.theme
                    title: "Privacy"
                    subtitle: "Live microphone and camera access"
                }

                Repeater {
                    model: [
                        { "title": "MICROPHONE", "icon": "󰍬", "users": privacyWindow.micUsers },
                        { "title": "CAMERA", "icon": "󰄀", "users": privacyWindow.cameraUsers }
                    ]

                    delegate: Rectangle {
                        id: sectionCard

                        required property var modelData
                        readonly property var users: modelData.users || []

                        width: parent.width
                        height: sectionColumn.implicitHeight + 24
                        color: privacyWindow.inkBg
                        border.color: Qt.rgba(1, 1, 1, 0.07)

                        Column {
                            id: sectionColumn
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 14
                            anchors.topMargin: 12
                            anchors.bottomMargin: 12
                            spacing: 9

                            Row {
                                width: parent.width
                                height: 18
                                spacing: 8

                                Text {
                                    text: sectionCard.modelData.icon
                                    color: sectionCard.users.length > 0 ? privacyWindow.panelAccent : privacyWindow.mutedFg
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 15
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    width: parent.width - 90
                                    height: parent.height
                                    text: sectionCard.modelData.title
                                    color: privacyWindow.panelFg
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.letterSpacing: 1
                                }
                                Text {
                                    width: 58
                                    height: parent.height
                                    text: sectionCard.users.length > 0 ? "IN USE" : "IDLE"
                                    color: sectionCard.users.length > 0 ? privacyWindow.panelAccent : privacyWindow.mutedFg
                                    horizontalAlignment: Text.AlignRight
                                    verticalAlignment: Text.AlignVCenter
                                    font.family: "monospace"
                                    font.pixelSize: 9
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: privacyWindow.panelAccent
                                opacity: 0.18
                            }

                            Repeater {
                                model: sectionCard.users

                                delegate: Column {
                                    required property var modelData

                                    width: parent.width
                                    spacing: 2

                                    Text {
                                        width: parent.width
                                        text: modelData.app
                                        color: privacyWindow.panelFg
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        visible: (modelData.device || "") !== ""
                                        text: modelData.device
                                        color: privacyWindow.mutedFg
                                        font.family: "monospace"
                                        font.pixelSize: 8
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                visible: sectionCard.users.length === 0
                                text: "Nothing is using it right now"
                                color: privacyWindow.mutedFg
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }

        Behavior on height { NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }
    }
}

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../ui" as SharedUi

// Names whoever is holding the microphone or the camera. It sits on the left
// edge because the indicator that opens it lives next to the workspaces, and it
// closes itself once the last capture ends, so it never outlives its own icon.
//
// Same anatomy as the other drop-down panels: one status card says what is
// being captured, then a section per device lists the apps behind it. Only the
// card carries the accent; the rows stay neutral, since every one of them is
// "in use" and marking them all would say nothing.
PanelWindow {
    id: privacyWindow

    property var theme: null
    property var statusController: null
    property bool opened: false
    property int barHeight: 26

    readonly property var micUsers: statusController ? statusController.micUsers : []
    readonly property var cameraUsers: statusController ? statusController.cameraUsers : []
    readonly property bool micActive: micUsers.length > 0
    readonly property bool cameraActive: cameraUsers.length > 0
    readonly property bool anyActive: micActive || cameraActive
    readonly property var sections: {
        var list = []
        if (micActive) list.push({ "title": "MICROPHONE", "glyph": "󰍬", "users": micUsers })
        if (cameraActive) list.push({ "title": "CAMERA", "glyph": "󰄀", "users": cameraUsers })
        return list
    }

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
        enabled: privacyWindow.opened
        // A sav aljahoz tapad: a panel a savbol nyilik le, nem lebeg alatta.
        y: privacyWindow.barHeight
        width: Math.min(360, parent.width - 20)
        // Margok (32), fejlec (34), allapotkartya (72), ket koz (24) es a szakaszok.
        height: Math.min(parent.height - privacyWindow.barHeight - 12, 162 + sectionColumn.implicitHeight)
        clip: true

        Behavior on height { NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }

        SharedUi.PopupFrame {
            id: sheet

            leftEar: false
            squareLeft: true
            shown: privacyWindow.opened
            anchors.fill: parent
            theme: privacyWindow.theme

            MouseArea { anchors.fill: parent; onClicked: mouse => mouse.accepted = true }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                SharedUi.PopupHeader {
                    width: parent.width
                    theme: privacyWindow.theme
                    title: "Privacy"
                }

                SharedUi.StatusCard {
                    width: parent.width
                    theme: privacyWindow.theme
                    active: privacyWindow.anyActive
                    glyph: privacyWindow.cameraActive ? "󰄀" : "󰍬"
                    title: privacyWindow.micActive && privacyWindow.cameraActive
                        ? "Microphone and camera in use"
                        : (privacyWindow.cameraActive ? "Camera in use"
                            : (privacyWindow.micActive ? "Microphone in use" : "Nothing is capturing"))
                    subtitle: privacyWindow.micActive && privacyWindow.cameraActive
                        ? "Recording audio and video"
                        : (privacyWindow.cameraActive ? "Microphone is idle"
                            : (privacyWindow.micActive ? "Camera is idle" : ""))
                }

                Flickable {
                    width: parent.width
                    height: parent.height - 130
                    contentHeight: sectionColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: sectionColumn

                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: privacyWindow.sections

                            delegate: Column {
                                id: section

                                required property var modelData

                                width: sectionColumn.width
                                spacing: 4

                                SharedUi.SectionBar {
                                    width: parent.width
                                    theme: privacyWindow.theme
                                    title: section.modelData.title
                                    detail: String(section.modelData.users.length)
                                }

                                Repeater {
                                    model: section.modelData.users

                                    SharedUi.ListRow {
                                        required property var modelData

                                        width: section.width
                                        theme: privacyWindow.theme
                                        interactive: false
                                        glyph: section.modelData.glyph
                                        title: modelData.app
                                        subtitle: modelData.device || ""
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

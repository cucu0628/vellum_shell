import QtQuick
import Quickshell.Services.Pipewire

Item {
    id: root
    required property var theme
    required property int barHeight
    property bool popupOpen: false
    property int volumePercent: 0

    signal clicked()
    signal volumeStepRequested(bool increase)

    width: mouse.containsMouse || popupOpen ? 54 : 22
    height: parent.height
    anchors.verticalCenter: parent.verticalCenter
    clip: true
    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 2
        color: root.theme.accent
        opacity: mouse.containsMouse || root.popupOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }
    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5
        Item {
            width: 22
            height: root.barHeight
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                text: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio.muted ? "" : ""
                color: mouse.containsMouse || root.popupOpen ? root.theme.accent : root.theme.foreground
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 16
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
        Text {
            text: root.volumePercent + "%"
            color: root.theme.accent
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
            opacity: mouse.containsMouse || root.popupOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onWheel: wheel => {
            root.volumeStepRequested(wheel.angleDelta.y > 0)
            wheel.accepted = true
        }
        onClicked: root.clicked()
    }
}

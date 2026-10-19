import QtQuick
import "../../ui" as SharedUi

Item {
    id: root
    required property var theme
    property bool popupOpen: false
    signal clicked()

    width: 22
    height: parent.height

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: "󰚩"
        color: root.popupOpen ? root.theme.accent : root.theme.foreground
        font.family: "Symbols Nerd Font Mono"
        font.pixelSize: 15
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    SharedUi.BarPill {
        theme: root.theme
        hovered: mouse.containsMouse
        active: root.popupOpen
        z: -1
    }

    SharedUi.Pressable {
        id: mouse
        anchors.fill: parent
        theme: root.theme
        accessibleName: qsTr("Open AI usage")
        onClicked: root.clicked()
    }
}

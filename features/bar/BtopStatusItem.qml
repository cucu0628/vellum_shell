import QtQuick
import "../../ui" as SharedUi

Item {
    id: root
    required property var theme
    signal clicked()

    width: 22
    height: parent.height
    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: "󰍛"
        color: mouse.containsMouse ? root.theme.accent : root.theme.foreground
        font.family: "Symbols Nerd Font Mono"
        font.pixelSize: 14
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 2
        color: root.theme.accent
        opacity: mouse.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }
    SharedUi.Pressable {
        id: mouse
        anchors.fill: parent
        theme: root.theme
        accessibleName: qsTr("Open system monitor")
        onClicked: root.clicked()
    }
}

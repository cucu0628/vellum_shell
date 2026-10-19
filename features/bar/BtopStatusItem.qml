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
        color: root.theme.foreground
        font.family: "Symbols Nerd Font Mono"
        font.pixelSize: 14
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    SharedUi.BarPill {
        theme: root.theme
        hovered: mouse.containsMouse
        active: false
        z: -1
    }
    SharedUi.Pressable {
        id: mouse
        anchors.fill: parent
        theme: root.theme
        accessibleName: qsTr("Open system monitor")
        onClicked: root.clicked()
    }
}

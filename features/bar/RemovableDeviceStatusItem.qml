import QtQuick
import "../../ui" as SharedUi

Item {
    id: root

    required property var theme
    property int deviceCount: 0
    property int mountedCount: 0
    property bool popupOpen: false
    signal clicked()

    visible: deviceCount > 0
    width: visible ? deviceRow.implicitWidth : 0
    height: parent.height

    Row {
        id: deviceRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            text: "󰕓"
            color: root.popupOpen || root.mountedCount > 0
                ? root.theme.accent : root.theme.foreground
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 15
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
            visible: root.deviceCount > 1
            text: root.deviceCount
            color: root.theme.foreground
            font.family: "monospace"
            font.pixelSize: 9
            font.bold: true
        }
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
        accessibleName: qsTr("Open removable devices, %1 available").arg(root.deviceCount)
        onClicked: root.clicked()
    }
}

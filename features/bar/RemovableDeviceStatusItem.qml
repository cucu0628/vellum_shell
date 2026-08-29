import QtQuick

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
            color: mouse.containsMouse || root.popupOpen || root.mountedCount > 0
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

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 2
        color: root.theme.accent
        opacity: mouse.containsMouse || root.popupOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

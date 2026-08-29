import QtQuick

Item {
    id: root
    required property var theme
    property bool available: false
    property bool enabled: false
    property bool connected: false
    property bool popupOpen: false
    signal clicked()

    width: 22
    height: parent.height

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: !root.available || !root.enabled ? "󰂲" : (root.connected ? "󰂱" : "󰂯")
        color: mouse.containsMouse || root.popupOpen ? root.theme.accent : root.theme.foreground
        opacity: root.available && root.enabled ? 1 : 0.55
        font.family: "Symbols Nerd Font Mono"
        font.pixelSize: 14
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 2
        color: root.theme.accent
        opacity: mouse.containsMouse || root.popupOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

import QtQuick

Item {
    id: root
    required property var theme
    property bool dnd: false
    property bool hasToast: false
    property int unreadCount: 0
    property bool menuOpened: false
    signal clicked()

    readonly property bool highlighted: menuOpened || dnd || hasToast || unreadCount > 0
    width: 22
    height: parent.height

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: root.dnd ? "󰂛" : (root.hasToast || root.unreadCount > 0 ? "󰂚" : "󰂞")
        color: mouse.containsMouse || root.highlighted ? root.theme.accent : root.theme.foreground
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
        opacity: mouse.containsMouse || root.highlighted ? 1 : 0
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

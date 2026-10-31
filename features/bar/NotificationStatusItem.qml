import QtQuick
import "../../ui" as SharedUi

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
        color: root.highlighted ? root.theme.accent : root.theme.foreground
        font.family: "Symbols Nerd Font Mono"
        font.pixelSize: 14
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    SharedUi.BarPill {
        theme: root.theme
        hovered: mouse.containsMouse
        active: root.menuOpened
        z: -1
    }
    SharedUi.Pressable {
        id: mouse
        anchors.fill: parent
        theme: root.theme
        accessibleName: qsTr("Open notifications, %1 unread").arg(root.unreadCount)
        onClicked: root.clicked()
    }
}

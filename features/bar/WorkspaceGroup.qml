import QtQuick
import Quickshell.Hyprland
import "../../ui" as SharedUi

Row {
    id: root

    required property var theme
    required property var visibleWorkspaceIds
    required property var occupiedWorkspaceIds
    property bool menuOpen: false

    signal menuClicked()

    height: parent.height

    Rectangle {
        id: menuItem
        width: 30
        height: parent.height
        color: "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            color: root.theme.accent
            opacity: menuMouse.containsMouse || root.menuOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }

        SharedUi.ShellLogo {
            anchors.centerIn: parent
            size: 14
            color: menuMouse.containsMouse || root.menuOpen ? root.theme.accent : root.theme.foreground
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        MouseArea {
            id: menuMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.menuClicked()
        }
    }

    Repeater {
        model: root.visibleWorkspaceIds

        Rectangle {
            required property int modelData
            property int wsId: modelData
            property bool isFocused: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsId
            property bool isOccupied: root.occupiedWorkspaceIds.indexOf(wsId) !== -1

            width: 25
            height: parent.height
            color: "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.isFocused ? 2 : 1
                color: root.theme.accent
                opacity: wsMouse.containsMouse || parent.isFocused ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }

            Text {
                anchors.centerIn: parent
                text: parent.wsId.toString()
                color: wsMouse.containsMouse || parent.isFocused ? root.theme.accent : (parent.isOccupied ? Qt.lighter(root.theme.foreground, 1.25) : root.theme.foreground)
                opacity: parent.isFocused || parent.isOccupied || wsMouse.containsMouse ? 1 : 0.62
                font.pixelSize: 12
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                id: wsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch(Hyprland.usingLua
                    ? "hl.dsp.focus({ workspace = " + parent.wsId + " })"
                    : "workspace " + parent.wsId)
            }
        }
    }
}

import QtQuick

// Wi-Fi/Ethernet state and the VPN shield in one module: the link icon carries
// the connection, the badge next to it only appears while a tunnel is up, and
// hovering it spells out which one. Right click jumps straight to the VPN tab.
Item {
    id: root

    required property var theme
    required property int barHeight
    property string connectionType: "offline"
    property bool vpnActive: false
    property string vpnName: ""
    property bool popupOpen: false
    readonly property bool highlighted: mouse.containsMouse || root.popupOpen
    readonly property int badgeWidth: 15
    readonly property int gap: 3
    readonly property int baseWidth: 22 + (root.vpnActive ? gap + badgeWidth : 0)

    signal clicked()
    signal vpnRequested()

    width: mouse.containsMouse && vpnActive ? Math.min(132, baseWidth + gap + label.implicitWidth) : baseWidth
    height: parent.height
    clip: true
    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 2
        color: root.theme.accent
        opacity: root.highlighted || root.vpnActive ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.gap

        Item {
            width: 22
            height: root.barHeight

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                text: root.connectionType === "ethernet" ? "󰈀" : (root.connectionType === "wifi" ? "󰤨" : "󰤭")
                color: root.highlighted ? root.theme.accent : root.theme.foreground
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 14
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }

        // Below ~16px the check inside the shield turns to mush, so the badge
        // gets its own room instead of being squeezed against the link icon.
        Item {
            width: root.badgeWidth
            height: root.barHeight
            visible: root.vpnActive

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -2
                text: "󰦝"
                color: root.theme.accent
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 13
            }
        }

        Text {
            id: label
            text: root.vpnName
            color: root.theme.accent
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 3
            visible: root.vpnActive
            opacity: mouse.containsMouse ? 1 : 0
            elide: Text.ElideRight
            width: Math.min(92, implicitWidth)
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (event) => {
            if (event.button === Qt.RightButton) root.vpnRequested()
            else root.clicked()
        }
    }
}

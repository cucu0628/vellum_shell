import QtQuick

// Ki/be kapcsolo. A shell tobbi resze nem hasznal QtQuick.Controls-t, ezert ez
// is sima Rectangle + MouseArea.
Item {
    id: toggle

    property var theme: null
    property bool checked: false

    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string surface: theme && theme.surface ? theme.surface : "#1b1613"

    signal toggled(bool value)

    implicitWidth: 46
    implicitHeight: 24

    Rectangle {
        id: track

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 46
        height: 24
        radius: 0
        color: toggle.checked ? toggle.accent : toggle.surface
        border.color: toggle.checked ? toggle.accent : toggle.muted
        border.width: 1

        Behavior on color {
            ColorAnimation {
                duration: 130
            }

        }

        Rectangle {
            width: 16
            height: 16
            radius: 0
            color: toggle.checked ? toggle.surface : toggle.muted
            anchors.verticalCenter: parent.verticalCenter
            x: toggle.checked ? parent.width - width - 4 : 4

            Behavior on x {
                NumberAnimation {
                    duration: 130
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

    MouseArea {
        anchors.fill: track
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.toggled(!toggle.checked)
    }

}

import QtQuick

Rectangle {
    id: frame

    property var theme: null
    default property alias content: contentLayer.data

    readonly property string background: theme ? theme.background : "#11130f"
    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"

    color: background
    border.color: Qt.rgba(1, 1, 1, 0.12)
    border.width: 1
    radius: 0
    clip: true

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 1
        height: 2
        color: frame.accent
    }

    ShellLogo {
        anchors.right: parent.right
        anchors.rightMargin: -26
        anchors.top: parent.top
        anchors.topMargin: -42
        size: 150
        color: frame.foreground
        opacity: 0.022
    }

    Item {
        id: contentLayer
        anchors.fill: parent
    }
}

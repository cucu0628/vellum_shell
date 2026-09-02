import QtQuick

Item {
    id: header

    property var theme: null
    property string title: "Vellum"
    property string subtitle: ""
    property int trailingWidth: 0
    default property alias trailing: trailingSlot.data

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"

    implicitHeight: 52
    height: implicitHeight

    ShellLogo {
        id: mark
        anchors.left: parent.left
        anchors.top: parent.top
        size: 34
        color: header.accent
    }

    Column {
        anchors.left: mark.right
        anchors.leftMargin: 12
        anchors.right: trailingSlot.left
        anchors.rightMargin: header.trailingWidth > 0 ? 12 : 0
        anchors.top: parent.top
        spacing: 1

        Text {
            width: parent.width
            text: header.title
            color: header.foreground
            font.family: "serif"
            font.pixelSize: 19
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: header.subtitle.toUpperCase()
            color: header.muted
            font.pixelSize: 8
            font.letterSpacing: 1.3
            elide: Text.ElideRight
        }
    }

    Item {
        id: trailingSlot
        anchors.right: parent.right
        anchors.top: parent.top
        width: header.trailingWidth
        height: 34
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: header.muted
        opacity: 0.2
    }
}

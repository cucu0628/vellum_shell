import QtQuick

Rectangle {
    id: tile

    property var theme: null
    property string heading: ""
    property string glyph: ""
    property string value: ""
    property string label: ""

    readonly property string background: theme ? theme.background : "#11130f"
    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"

    radius: 0
    color: background
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 10
        anchors.topMargin: 9
        width: 14
        height: 2
        color: tile.accent
        opacity: 0.75
    }

    Column {
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tile.heading
            color: tile.foreground
            font.family: "serif"
            font.pixelSize: 11
            font.weight: Font.DemiBold
            visible: tile.heading !== ""
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tile.glyph
            color: tile.accent
            font.pixelSize: 19
            visible: tile.glyph !== ""
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tile.value
            color: tile.foreground
            font.family: "serif"
            font.pixelSize: 17
            font.weight: Font.Medium
            visible: tile.value !== ""
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tile.label
            color: tile.muted
            font.pixelSize: 8
            font.letterSpacing: 1
            visible: tile.label !== ""
        }
    }
}

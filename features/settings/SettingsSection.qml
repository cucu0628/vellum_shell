import QtQuick

// Szakaszcim egy beallitasoldalon belul.
Item {
    id: section

    property var theme: null
    property string title: ""
    property string description: ""

    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"

    height: description === "" ? 52 : 66

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: 21
        width: 22
        height: 1
        color: section.accent
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 34
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 10
        spacing: 2

        Text {
            width: parent.width
            text: section.title
            color: section.foreground
            font.family: "serif"
            font.pixelSize: 17
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: section.description !== ""
            text: section.description.toUpperCase()
            color: section.muted
            font.pixelSize: 7
            font.letterSpacing: 1.1
            elide: Text.ElideRight
        }
    }

}

import QtQuick

Rectangle {
    id: row

    property var theme: null
    property var entry: null

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"

    height: 38
    radius: 0
    color: "transparent"

    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 12
        height: 1
        color: row.accent
    }

    Text {
        id: rowIcon
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        text: row.entry ? row.entry.icon : ""
        color: row.accent
        font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter
    }

    Text {
        id: rowLabel

        anchors.left: rowIcon.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 92
        text: row.entry ? row.entry.label.toUpperCase() : ""
        color: row.muted
        font.pixelSize: 7
        font.letterSpacing: 1.2
        font.bold: true
        elide: Text.ElideRight
    }

    Text {
        anchors.left: rowLabel.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        text: row.entry ? row.entry.value : ""
        color: row.foreground
        font.family: "monospace"
        font.pixelSize: 9
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideMiddle
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: row.muted
        opacity: 0.13
    }
}

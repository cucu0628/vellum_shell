import QtQuick

Item {
    id: header

    property var theme: null
    property string title: "Vellum"
    property string subtitle: ""
    property int trailingWidth: 0
    default property alias trailing: trailingSlot.data

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"

    // Alcim nelkul alacsonyabb, hogy ne maradjon ures sav a tartalom felett.
    implicitHeight: subtitle !== "" ? 44 : 34
    height: implicitHeight

    Column {
        anchors.left: parent.left
        anchors.right: trailingSlot.left
        anchors.rightMargin: header.trailingWidth > 0 ? 12 : 0
        anchors.top: parent.top
        spacing: 2

        Text {
            width: parent.width
            text: header.title
            color: header.foreground
            font.family: "serif"
            font.pixelSize: 18
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: header.subtitle !== ""
            text: header.subtitle
            color: header.muted
            font.pixelSize: 10
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
}

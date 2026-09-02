import QtQuick

Rectangle {
    id: panel

    property var theme: null
    property string title: ""
    property string kanji: ""
    property string trailing: ""
    property real contentSpacing: 10
    property bool editorial: false
    default property alias content: body.data

    readonly property string background: theme ? theme.background : "#11130f"
    readonly property string surface: theme && theme.surface ? theme.surface : "#191b16"
    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property real bodyHeight: body.height

    radius: 0
    color: surface
    border.color: Qt.rgba(1, 1, 1, editorial ? 0.09 : 0.07)
    border.width: 1
    clip: true

    Item {
        id: head

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 12
        height: 16

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: panel.editorial ? 9 : 7

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                height: 2
                color: panel.accent
                visible: panel.editorial
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: panel.title
                color: panel.editorial ? panel.foreground : panel.accent
                font.pixelSize: 9
                font.letterSpacing: panel.editorial ? 2 : 3
                font.bold: true
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: panel.kanji
                color: panel.muted
                font.pixelSize: 10
                font.letterSpacing: 2
                opacity: 0.75
                visible: panel.kanji !== ""
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: panel.trailing
            color: panel.muted
            font.pixelSize: 9
            font.letterSpacing: 1
            visible: panel.trailing !== ""
        }
    }

    Rectangle {
        id: rule

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 9
        height: 1
        color: panel.editorial ? panel.muted : panel.accent
        opacity: panel.editorial ? 0.18 : 0.26
    }

    Item {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: rule.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: panel.contentSpacing
        anchors.bottomMargin: 12
    }
}

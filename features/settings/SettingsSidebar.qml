pragma ComponentBehavior: Bound

import QtQuick

// Oldalsav. A lista statikus, ezert nem ListView, csak egy Repeater -- igy a
// kijelolt elem stilusa egyszeru marad.
Rectangle {
    id: sidebar

    property var theme: null
    property string activePage: ""
    property var pages: []

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string surface: theme && theme.surface ? theme.surface : "#1b1613"

    signal selected(string page)

    color: surface

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 18
        spacing: 0

        Text {
            x: 18
            text: "VELLUM"
            color: sidebar.foreground
            font.pixelSize: 12
            font.bold: true
            font.letterSpacing: 3
            bottomPadding: 2
        }

        Text {
            x: 18
            text: "Settings"
            color: sidebar.muted
            font.pixelSize: 10
            bottomPadding: 18
        }

        Repeater {
            model: sidebar.pages

            Rectangle {
                id: entry

                required property var modelData

                readonly property bool current: entry.modelData.id === sidebar.activePage

                width: sidebar.width
                height: 38
                color: entry.current || entryMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 2
                    color: sidebar.accent
                    visible: entry.current
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    text: entry.modelData.icon
                    color: entry.current ? sidebar.accent : sidebar.muted
                    font.pixelSize: 14
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 44
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: entry.modelData.label
                    color: entry.current ? sidebar.foreground : sidebar.muted
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: entryMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sidebar.selected(entry.modelData.id)
                }

            }

        }

    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: sidebar.muted
        opacity: 0.2
    }

}

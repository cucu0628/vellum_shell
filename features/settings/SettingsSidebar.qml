pragma ComponentBehavior: Bound

import QtQuick
import "../../ui" as SharedUi

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

    Item {
        id: masthead

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 88

        SharedUi.ShellLogo {
            id: mark

            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.top: parent.top
            anchors.topMargin: 22
            size: 36
            color: sidebar.accent
        }

        Text {
            anchors.left: mark.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: mark.verticalCenter
            text: "Settings"
            color: sidebar.foreground
            font.family: "serif"
            font.pixelSize: 20
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.bottom: parent.bottom
            height: 1
            color: sidebar.muted
            opacity: 0.18
        }
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: masthead.bottom
        spacing: 0

        Repeater {
            model: sidebar.pages

            Item {
                id: entry

                required property var modelData

                readonly property bool current: entry.modelData.id === sidebar.activePage

                width: sidebar.width
                height: 48

                Rectangle {
                    id: navigationRow

                    anchors.fill: parent
                    color: entry.current || entryMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.045) : "transparent"

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2
                        height: 25
                        color: sidebar.accent
                        visible: entry.current
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        text: entry.modelData.icon
                        color: entry.current ? sidebar.accent : sidebar.muted
                        font.pixelSize: 13
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 54
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.label
                        color: entry.current ? sidebar.foreground : sidebar.muted
                        font.family: entry.current ? "serif" : "sans-serif"
                        font.pixelSize: entry.current ? 14 : 12
                        font.weight: entry.current ? Font.Medium : Font.Normal
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

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
        height: 104

        SharedUi.ShellLogo {
            id: mark

            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.top: parent.top
            anchors.topMargin: 22
            size: 36
            color: sidebar.accent
        }

        Column {
            anchors.left: mark.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: mark.verticalCenter
            spacing: 0

            Text {
                width: parent.width
                text: "Settings"
                color: sidebar.foreground
                font.family: "serif"
                font.pixelSize: 20
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: "VELLUM / CONFIGURATION"
                color: sidebar.muted
                font.pixelSize: 7
                font.letterSpacing: 1.2
                elide: Text.ElideRight
            }
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
                required property int index

                readonly property bool current: entry.modelData.id === sidebar.activePage

                width: sidebar.width
                height: entry.modelData.startsGroup ? 70 : 43

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    visible: entry.modelData.startsGroup
                    text: entry.modelData.group
                    color: sidebar.muted
                    font.pixelSize: 7
                    font.bold: true
                    font.letterSpacing: 1.7
                }

                Rectangle {
                    id: navigationRow

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 43
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
                        anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        text: (entry.index + 1).toString().padStart(2, "0")
                        color: entry.current ? sidebar.accent : sidebar.muted
                        opacity: entry.current ? 1 : 0.55
                        font.family: "monospace"
                        font.pixelSize: 8
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 46
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        text: entry.modelData.icon
                        color: entry.current ? sidebar.accent : sidebar.muted
                        font.pixelSize: 13
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 76
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

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        text: "HYPRLAND / DESKTOP SHELL"
        color: sidebar.muted
        opacity: 0.55
        font.pixelSize: 7
        font.letterSpacing: 1.2
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

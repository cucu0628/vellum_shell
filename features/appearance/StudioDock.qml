import QtQuick
import "../../ui" as SharedUi

// Az Appearance Studio egyetlen, osszefuggo also muhelyfelulete. A nagy kepek
// es a valodi szinmintak viszik a hierarchiat; a szoveg csak azonositasra es a
// ket vegso muveletre marad.
Rectangle {
    id: dock

    property var theme: null
    property var wallpaperItems: []
    property var themeItems: []
    property int selectedWallpaperIndex: 0
    property int selectedThemeIndex: 0
    property var selectedWallpaper: null
    property var selectedTheme: null
    property string emphasisRail: "wallpaper"
    property bool applying: false
    property bool dirty: false
    property var imageSource: function (path) { return path }

    readonly property color bg: theme ? theme.background : "#11130f"
    readonly property color fg: theme ? theme.foreground : "#e8ddc7"
    readonly property color accent: theme ? theme.accent : "#b7372f"
    readonly property color surfaceColor: theme && theme.surface ? theme.surface : "#191b16"
    readonly property color mutedFg: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property color hairline: Qt.rgba(fg.r, fg.g, fg.b, 0.11)
    readonly property int sideMargin: 22

    signal wallpaperSelected(int index)
    signal paletteSelected(int index)
    signal wallpaperStepRequested(int delta)
    signal paletteStepRequested(int delta)
    signal dockToggleRequested
    signal applyRequested
    signal cancelRequested

    implicitHeight: footer.y + footer.height + 18
    color: dock.surfaceColor
    border.color: dock.hairline
    border.width: 1
    radius: 0
    clip: true

    Behavior on color { ColorAnimation { duration: 190; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: 190; easing.type: Easing.OutCubic } }

    Rectangle {
        id: topRule
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 1
        height: 2
        color: dock.accent
        Behavior on color { ColorAnimation { duration: 190; easing.type: Easing.OutCubic } }
    }

    SharedUi.ShellLogo {
        anchors.right: parent.right
        anchors.rightMargin: -34
        anchors.top: parent.top
        anchors.topMargin: -54
        size: 190
        color: dock.fg
        opacity: 0.022
    }

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: topRule.bottom
        anchors.leftMargin: dock.sideMargin
        anchors.rightMargin: dock.sideMargin
        anchors.topMargin: 14
        height: 47

        SharedUi.ShellLogo {
            id: seal
            anchors.left: parent.left
            anchors.top: parent.top
            size: 34
            color: dock.accent
            Behavior on color { ColorAnimation { duration: 190; easing.type: Easing.OutCubic } }
        }

        Text {
            anchors.left: seal.right
            anchors.leftMargin: 12
            anchors.verticalCenter: seal.verticalCenter
            text: "Appearance"
            color: dock.fg
            font.family: "serif"
            font.pixelSize: 23
            font.weight: Font.Medium
            Behavior on color { ColorAnimation { duration: 190; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            id: closeButton
            anchors.right: parent.right
            anchors.top: parent.top
            width: 30
            height: 30
            color: closeMouse.containsMouse ? Qt.rgba(dock.fg.r, dock.fg.g, dock.fg.b, 0.08) : "transparent"
            border.color: dock.hairline
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "×"
                color: closeMouse.containsMouse ? dock.accent : dock.mutedFg
                font.pixelSize: 16
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: dock.cancelRequested()
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: dock.hairline
        }
    }

    Item {
        id: wallpaperHeading
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.leftMargin: dock.sideMargin
        anchors.rightMargin: dock.sideMargin
        anchors.topMargin: 11
        height: 22

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 2
                color: dock.accent
                opacity: dock.emphasisRail === "wallpaper" ? 1 : 0.35
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "WALLPAPER"
                color: dock.emphasisRail === "wallpaper" ? dock.fg : dock.mutedFg
                font.pixelSize: 9
                font.bold: true
                font.letterSpacing: 2
                Behavior on color { ColorAnimation { duration: 190; easing.type: Easing.OutCubic } }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(480, parent.width * 0.55)
            text: dock.selectedWallpaper ? dock.selectedWallpaper.name : ""
            color: dock.fg
            font.family: "serif"
            font.pixelSize: 15
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideMiddle
            Behavior on color { ColorAnimation { duration: 190; easing.type: Easing.OutCubic } }
        }
    }

    Rectangle {
        id: wallpaperStage
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: wallpaperHeading.bottom
        anchors.leftMargin: dock.sideMargin
        anchors.rightMargin: dock.sideMargin
        anchors.topMargin: 5
        height: 142
        color: dock.bg
        border.color: dock.hairline
        border.width: 1
        clip: true
        Behavior on color { ColorAnimation { duration: 190; easing.type: Easing.OutCubic } }

        WallpaperRail {
            anchors.fill: parent
            anchors.margins: 9
            theme: dock.theme
            wallpaperItems: dock.wallpaperItems
            selectedIndex: dock.selectedWallpaperIndex
            imageSource: dock.imageSource
            wellColor: dock.bg
            onWallpaperSelected: (index) => dock.wallpaperSelected(index)
            onStepRequested: (delta) => dock.wallpaperStepRequested(delta)
        }
    }

    Item {
        id: paletteHeading
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: wallpaperStage.bottom
        anchors.leftMargin: dock.sideMargin
        anchors.rightMargin: dock.sideMargin
        anchors.topMargin: 9
        height: 20

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 2
                color: dock.accent
                opacity: dock.emphasisRail === "theme" ? 1 : 0.35
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "PALETTE"
                color: dock.emphasisRail === "theme" ? dock.fg : dock.mutedFg
                font.pixelSize: 9
                font.bold: true
                font.letterSpacing: 2
                Behavior on color { ColorAnimation { duration: 190; easing.type: Easing.OutCubic } }
            }
        }
    }

    Rectangle {
        id: paletteStage
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: paletteHeading.bottom
        anchors.leftMargin: dock.sideMargin
        anchors.rightMargin: dock.sideMargin
        anchors.topMargin: 4
        height: 70
        color: dock.bg
        border.color: dock.hairline
        border.width: 1
        clip: true
        Behavior on color { ColorAnimation { duration: 190; easing.type: Easing.OutCubic } }

        PaletteRail {
            anchors.fill: parent
            anchors.margins: 7
            theme: dock.theme
            themeItems: dock.themeItems
            selectedIndex: dock.selectedThemeIndex
            wellColor: dock.bg
            onPaletteSelected: (index) => dock.paletteSelected(index)
            onStepRequested: (delta) => dock.paletteStepRequested(delta)
        }
    }

    Item {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: paletteStage.bottom
        anchors.leftMargin: dock.sideMargin
        anchors.rightMargin: dock.sideMargin
        anchors.topMargin: 12
        height: 34

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Rectangle {
                id: helpButton
                width: 34
                height: 34
                color: helpMouse.containsMouse ? Qt.rgba(dock.fg.r, dock.fg.g, dock.fg.b, 0.08) : "transparent"
                border.color: dock.hairline
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "?"
                    color: helpMouse.containsMouse ? dock.accent : dock.mutedFg
                    font.family: "serif"
                    font.pixelSize: 15
                    font.bold: true
                }

                MouseArea { id: helpMouse; anchors.fill: parent; hoverEnabled: true }
            }

            Rectangle {
                width: 34
                height: 34
                color: hideMouse.containsMouse ? Qt.rgba(dock.fg.r, dock.fg.g, dock.fg.b, 0.08) : "transparent"
                border.color: dock.hairline
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "—"
                    color: hideMouse.containsMouse ? dock.accent : dock.mutedFg
                    font.pixelSize: 13
                }

                MouseArea {
                    id: hideMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dock.dockToggleRequested()
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.top
            anchors.bottomMargin: 8
            width: 292
            height: 48
            z: 10
            visible: helpMouse.containsMouse
            color: dock.surfaceColor
            border.color: dock.hairline
            border.width: 1

            Text {
                anchors.fill: parent
                anchors.margins: 10
                text: "← →  wallpaper     ↑ ↓  palette     D  dynamic\nSpace  hide     Enter  apply     Esc  cancel"
                color: dock.mutedFg
                font.pixelSize: 9
                font.letterSpacing: 0.6
                lineHeight: 1.35
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Rectangle {
                width: 96
                height: 34
                color: cancelMouseArea.containsMouse ? Qt.rgba(dock.fg.r, dock.fg.g, dock.fg.b, 0.08) : "transparent"
                border.color: dock.hairline
                border.width: 1
                Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: "CANCEL"
                    color: dock.fg
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1.7
                }

                MouseArea {
                    id: cancelMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dock.cancelRequested()
                }
            }

            Rectangle {
                width: 128
                height: 34
                color: dock.applying
                    ? dock.surfaceColor
                    : (applyMouse.containsMouse ? Qt.lighter(dock.accent, 1.12) : dock.accent)
                border.color: dock.accent
                border.width: 1
                opacity: dock.dirty || dock.applying ? 1 : 0.44
                Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: dock.applying ? "APPLYING…" : "APPLY  ↵"
                    color: dock.applying ? dock.accent : dock.bg
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1.7
                }

                MouseArea {
                    id: applyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !dock.applying
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dock.applyRequested()
                }
            }
        }
    }
}

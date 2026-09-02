import QtQuick
import "../../ui" as SharedUi

// A valaszto teljes felulete. Nem a kepernyo szelessegeben ul, hanem kozepre
// igazitott, tartalomhoz meretezett panel -- igy targynak latszik, nem savnak.
//
// A dokk maga is shell felulet, ezert egyben az elonezet is: a paletta accent,
// surface, muted es foreground erteke mind latszik rajta.
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

    readonly property string bg: theme ? theme.background : "#11130f"
    readonly property string fg: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string surfaceColor: theme && theme.surface ? theme.surface : "#191b16"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#958b7a"

    readonly property int sideMargin: 18
    readonly property int labelWidth: 96

    signal wallpaperSelected(int index)
    signal paletteSelected(int index)
    signal wallpaperStepRequested(int delta)
    signal paletteStepRequested(int delta)
    signal applyRequested
    signal cancelRequested

    implicitHeight: footer.y + footer.height + 16

    color: dock.surfaceColor
    radius: 0
    border.color: Qt.rgba(1, 1, 1, 0.09)
    border.width: 1
    clip: true

    // A paletta valtasa a dokkon is latszik, ezert az atmenet szamit: enelkul a
    // sav egyik kepkockarol a masikra atvalt, ami rantasnak hat.
    Behavior on color { ColorAnimation { duration: 190; easing.type: Easing.OutCubic } }

    // Ugyanaz az akcentel, ami a bar also szelen fut: ez koti a dokkot a shell
    // tobbi feluletehez, es megtori a lapos sotet tomboket.
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
        height: 50

        SharedUi.ShellLogo {
            id: seal
            anchors.left: parent.left
            anchors.top: parent.top
            size: 38
            color: dock.accent
            Behavior on color { ColorAnimation { duration: 190; easing.type: Easing.OutCubic } }
        }

        Column {
            anchors.left: seal.right
            anchors.leftMargin: 14
            anchors.right: closeButton.left
            anchors.rightMargin: 16
            anchors.top: parent.top
            spacing: 1

            Text {
                width: parent.width
                text: dock.selectedWallpaper ? dock.selectedWallpaper.name : "Loading scene…"
                color: dock.fg
                font.family: "serif"
                font.pixelSize: 20
                font.weight: Font.Medium
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: 190; easing.type: Easing.OutCubic } }
            }

            Row {
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: dock.selectedTheme ? dock.selectedTheme.name.toUpperCase() : ""
                    color: dock.accent
                    font.pixelSize: 8
                    font.bold: true
                    font.letterSpacing: 1.8
                    Behavior on color { ColorAnimation { duration: 190; easing.type: Easing.OutCubic } }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: dock.selectedTheme
                        ? (dock.selectedTheme.kind === "dynamic" ? "· from this image" : "· static palette")
                        : ""
                    color: dock.mutedFg
                    font.pixelSize: 8
                }
            }
        }

        Rectangle {
            id: closeButton
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 4
            width: 26
            height: 26
            color: closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.075) : "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.09)
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "✕"
                color: closeMouse.containsMouse ? dock.accent : dock.mutedFg
                font.pixelSize: 11
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
            color: dock.mutedFg
            opacity: 0.18
        }
    }

    // A savok sotetebb alapon ulnek, mint a dokk: a ket ertek adja a melyseget.
    Rectangle {
        id: wallpaperWell

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.leftMargin: dock.sideMargin
        anchors.rightMargin: dock.sideMargin
        anchors.topMargin: 12
        height: 128
        color: dock.bg
        Behavior on color { ColorAnimation { duration: 190; easing.type: Easing.OutCubic } }
        border.color: Qt.rgba(1, 1, 1, 0.05)
        border.width: 1

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -22
            width: 14
            height: 2
            color: dock.accent
            opacity: dock.emphasisRail === "wallpaper" ? 1 : 0.35
        }

        Text {
            id: wallpaperLabel
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -2
            width: dock.labelWidth - 14
            text: "WALLPAPER"
            color: dock.emphasisRail === "wallpaper" ? dock.accent : dock.mutedFg
            Behavior on color { ColorAnimation { duration: 190; easing.type: Easing.OutCubic } }
            font.pixelSize: 9
            font.letterSpacing: 2
            font.bold: true
            wrapMode: Text.WordWrap
        }

        Text {
            anchors.left: wallpaperLabel.left
            anchors.top: wallpaperLabel.bottom
            anchors.topMargin: 4
            text: dock.wallpaperItems.length + " images"
            color: dock.mutedFg
            opacity: 0.7
            font.pixelSize: 8
        }

        WallpaperRail {
            id: wallpaperRail

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: dock.labelWidth
            anchors.rightMargin: 10
            anchors.topMargin: 10
            anchors.bottomMargin: 10
            theme: dock.theme
            wallpaperItems: dock.wallpaperItems
            selectedIndex: dock.selectedWallpaperIndex
            imageSource: dock.imageSource
            wellColor: dock.bg
            onWallpaperSelected: (index) => dock.wallpaperSelected(index)
            onStepRequested: (delta) => dock.wallpaperStepRequested(delta)
        }
    }

    Rectangle {
        id: paletteWell

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: wallpaperWell.bottom
        anchors.leftMargin: dock.sideMargin
        anchors.rightMargin: dock.sideMargin
        anchors.topMargin: 10
        height: 76
        color: dock.bg
        Behavior on color { ColorAnimation { duration: 190; easing.type: Easing.OutCubic } }
        border.color: Qt.rgba(1, 1, 1, 0.05)
        border.width: 1

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -22
            width: 14
            height: 2
            color: dock.accent
            opacity: dock.emphasisRail === "theme" ? 1 : 0.35
        }

        Text {
            id: paletteLabel
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -2
            width: dock.labelWidth - 14
            text: "PALETTE"
            color: dock.emphasisRail === "theme" ? dock.accent : dock.mutedFg
            Behavior on color { ColorAnimation { duration: 190; easing.type: Easing.OutCubic } }
            font.pixelSize: 9
            font.letterSpacing: 2
            font.bold: true
            wrapMode: Text.WordWrap
        }

        Text {
            anchors.left: paletteLabel.left
            anchors.top: paletteLabel.bottom
            anchors.topMargin: 4
            text: dock.themeItems.length + " themes"
            color: dock.mutedFg
            opacity: 0.7
            font.pixelSize: 8
        }

        PaletteRail {
            id: paletteRail

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: dock.labelWidth
            anchors.rightMargin: 10
            anchors.topMargin: 9
            anchors.bottomMargin: 9
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
        anchors.top: paletteWell.bottom
        anchors.leftMargin: dock.sideMargin
        anchors.rightMargin: dock.sideMargin
        anchors.topMargin: 14
        height: 32

        Text {
            anchors.left: parent.left
            anchors.right: actions.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: "← →  wallpaper      ↑ ↓  palette      D  dynamic      SPACE  hide"
            color: dock.mutedFg
            opacity: 0.72
            font.pixelSize: 9
            font.letterSpacing: 1
            elide: Text.ElideRight
        }

        Row {
            id: actions
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Rectangle {
                width: 108
                height: 32
                color: cancelMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.075) : "transparent"
                border.color: Qt.rgba(1, 1, 1, 0.11)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: "ESC  CANCEL"
                    color: dock.fg
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 2
                }

                MouseArea {
                    id: cancelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dock.cancelRequested()
                }
            }

            // Enter irja ki mindenre a temat: ez az egyetlen muvelet, ami
            // lemezhez es kulso alkalmazasokhoz nyul.
            Rectangle {
                width: 152
                height: 32
                color: dock.applying
                    ? dock.surfaceColor
                    : (applyMouse.containsMouse ? Qt.lighter(dock.accent, 1.15) : dock.accent)
                border.color: dock.accent
                border.width: 1
                opacity: dock.dirty || dock.applying ? 1 : 0.45
                Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: dock.applying ? "APPLYING…" : "APPLY EVERYWHERE  ↵"
                    color: dock.applying ? dock.accent : dock.bg
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 2
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

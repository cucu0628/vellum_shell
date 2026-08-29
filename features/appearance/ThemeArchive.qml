import QtQuick
import "../../ui" as SharedUi

Item {
    id: archive

    property var theme: null
    property var selectedTheme: null
    property var selectedWallpaper: null
    property var themeItems: []
    property int selectedThemeIndex: 0
    property string activeSection: "wallpaper"
    property bool applying: false
    property color previewBg: "#11130f"
    property color previewAccent: "#b7372f"
    property color panelBg: "#11130f"
    property color panelFg: "#e8ddc7"
    property color panelAccent: "#b7372f"
    property color panelSurface: "#191b16"
    property color mutedFg: "#958b7a"

    readonly property bool dynamicSelected: selectedTheme && selectedTheme.kind === "dynamic"
    readonly property color lineBg: Qt.rgba(1, 1, 1, 0.055)
    readonly property color hoverBg: Qt.rgba(1, 1, 1, 0.075)

    signal themeSelected(int index)
    signal dynamicRequested
    signal applyRequested

    function ensureVisible() {
        var itemHeight = 66
        var top = selectedThemeIndex * itemHeight
        var maxY = Math.max(0, themeFlick.contentHeight - themeFlick.height)
        themeFlick.contentY = Math.max(0, Math.min(top - themeFlick.height * 0.35, maxY))
    }

    SharedUi.DashPanel {
        id: scenePanel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 208
        theme: archive.theme
        title: "SCENE"
        kanji: ""
        trailing: archive.selectedTheme ? archive.selectedTheme.kind.toUpperCase() : ""

        Text {
            id: sceneName
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            text: archive.selectedWallpaper ? archive.selectedWallpaper.name : "Loading scene..."
            color: archive.panelFg
            font.pixelSize: 19
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            id: scenePalette
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: sceneName.bottom
            anchors.topMargin: 3
            text: archive.selectedTheme ? archive.selectedTheme.name : "Loading palette..."
            color: archive.mutedFg
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        Row {
            id: swatches
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: scenePalette.bottom
            anchors.topMargin: 12
            height: 28
            spacing: 5

            Repeater {
                model: archive.selectedTheme
                    ? [archive.selectedTheme.background, archive.selectedTheme.surface, archive.selectedTheme.accent, archive.selectedTheme.foreground, archive.selectedTheme.muted]
                    : []

                Rectangle {
                    width: (swatches.width - 20) / 5
                    height: swatches.height
                    color: modelData
                    border.color: Qt.rgba(1, 1, 1, 0.16)
                    border.width: 1
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 44
            color: archive.dynamicSelected ? archive.panelAccent : (dynamicMouse.containsMouse ? archive.hoverBg : "transparent")
            border.color: archive.dynamicSelected ? archive.panelAccent : archive.lineBg
            border.width: 1
            Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: archive.dynamicSelected ? "FROM THIS IMAGE" : "STATIC PALETTE"
                    color: archive.dynamicSelected ? archive.panelBg : archive.panelFg
                    font.pixelSize: 9
                    font.letterSpacing: 1
                    font.bold: true
                }

                Text {
                    width: parent.width
                    text: archive.dynamicSelected ? "Matugen regenerates on apply" : "Wallpaper changes independently"
                    color: archive.dynamicSelected ? archive.panelBg : archive.mutedFg
                    opacity: archive.dynamicSelected ? 0.85 : 1
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: dynamicMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: archive.dynamicRequested()
            }
        }
    }

    SharedUi.DashPanel {
        id: archivePanel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: scenePanel.bottom
        anchors.bottom: applyButton.top
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        theme: archive.theme
        title: "PALETTE ARCHIVE"
        kanji: ""
        trailing: archive.themeItems.length + "  ·  D DYNAMIC"

        Flickable {
            id: themeFlick
            anchors.fill: parent
            contentHeight: themeColumn.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: themeColumn
                width: parent.width
                spacing: 6

                Repeater {
                    model: archive.themeItems

                    Rectangle {
                        id: themeRow
                        property bool current: index === archive.selectedThemeIndex

                        width: themeColumn.width
                        height: 60
                        radius: 0
                        color: themeRow.current ? archive.panelSurface : (themeMouse.containsMouse ? archive.hoverBg : archive.panelBg)
                        border.color: themeRow.current ? archive.panelAccent : Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 2
                            color: modelData.accent
                            opacity: themeRow.current ? 1 : 0.5
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 13
                            anchors.right: themeBadge.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Text {
                                width: parent.width
                                text: modelData.name
                                color: themeRow.current ? archive.panelAccent : archive.panelFg
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Row {
                                spacing: 3
                                Repeater {
                                    model: [modelData.background, modelData.surface, modelData.accent, modelData.foreground, modelData.muted]
                                    Rectangle { width: 17; height: 6; color: modelData }
                                }
                            }

                            Text {
                                width: parent.width
                                text: (modelData.kind === "dynamic" ? "dominant wallpaper colour" : "static palette")
                                    + "  ·  " + (modelData.iconTheme === "auto" ? "Yaru auto" : modelData.iconTheme)
                                color: archive.mutedFg
                                font.pixelSize: 8
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            id: themeBadge
                            anchors.right: parent.right
                            anchors.rightMargin: 9
                            anchors.verticalCenter: parent.verticalCenter
                            width: 54
                            text: modelData.current ? "CURRENT" : (modelData.kind === "dynamic" ? "DYNAMIC" : "")
                            color: modelData.accent
                            font.pixelSize: 8
                            font.bold: true
                            font.letterSpacing: 1
                            horizontalAlignment: Text.AlignRight
                        }

                        MouseArea {
                            id: themeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: archive.themeSelected(index)
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: applyButton
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: hint.top
        anchors.bottomMargin: 8
        height: 46
        radius: 0
        color: archive.applying ? archive.panelSurface : (applyMouse.containsMouse ? Qt.lighter(archive.panelAccent, 1.15) : archive.panelAccent)
        border.color: archive.panelAccent
        border.width: 1
        opacity: archive.selectedTheme && archive.selectedWallpaper ? 1 : 0.45
        Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            text: archive.applying ? "COMPOSING..." : "APPLY SCENE   ↵"
            color: archive.applying ? archive.panelAccent : archive.panelBg
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 2
        }

        MouseArea {
            id: applyMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: !archive.applying && archive.selectedTheme && archive.selectedWallpaper
            cursorShape: Qt.PointingHandCursor
            onClicked: archive.applyRequested()
        }
    }

    Text {
        id: hint
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 14
        text: "TAB  switch focus      ESC  close"
        color: archive.mutedFg
        opacity: 0.72
        font.pixelSize: 9
        font.letterSpacing: 1
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}

import QtQuick
import Quickshell
import Quickshell.Wayland
import "."
import "../../ui" as SharedUi

PanelWindow {
    id: studio

    property alias backend: appearanceController.backend
    property alias theme: appearanceController.theme
    property alias wallpaperController: appearanceController.wallpaperController
    property alias opened: appearanceController.opened
    property alias mode: appearanceController.mode
    property alias activeSection: appearanceController.activeSection
    property alias themeItems: appearanceController.themeItems
    property alias wallpaperItems: appearanceController.wallpaperItems
    property alias selectedThemeIndex: appearanceController.selectedThemeIndex
    property alias selectedWallpaperIndex: appearanceController.selectedWallpaperIndex
    property alias applying: appearanceController.applying
    property alias sceneApplied: appearanceController.sceneApplied

    readonly property var selectedTheme: appearanceController.selectedTheme
    readonly property var selectedWallpaper: appearanceController.selectedWallpaper
    readonly property string previewBg: selectedTheme ? selectedTheme.background : (theme ? theme.background : "#15110f")
    readonly property string previewFg: selectedTheme ? selectedTheme.foreground : (theme ? theme.foreground : "#f1e7d0")
    readonly property string previewAccent: selectedTheme ? selectedTheme.accent : (theme ? theme.accent : "#d7472f")
    readonly property string previewSurface: selectedTheme ? selectedTheme.surface : (theme && theme.surface ? theme.surface : "#1b1613")
    readonly property string previewMuted: selectedTheme ? selectedTheme.muted : (theme && theme.muted ? theme.muted : "#9f8f7c")
    readonly property string panelBg: theme ? theme.background : "#15110f"
    readonly property string panelFg: theme ? theme.foreground : "#f1e7d0"
    readonly property string panelAccent: theme ? theme.accent : "#d7472f"
    readonly property string panelSurface: theme && theme.surface ? theme.surface : "#1b1613"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#9f8f7c"

    function loadItems() { appearanceController.loadItems() }
    function releaseResources() { appearanceController.releaseResources() }
    function imageSource(path) { return appearanceController.imageSource(path) }
    function setSection(section) { appearanceController.setSection(section) }
    function moveSelection(delta) { appearanceController.moveSelection(delta) }
    function selectDynamicTheme() { appearanceController.selectDynamicTheme() }
    function ensureThemeVisible() { themeArchive.ensureVisible() }
    function ensureWallpaperVisible() { wallpaperFilmstrip.ensureVisible() }
    function applyScene() { appearanceController.applyScene() }
    function handleKey(event) { appearanceController.handleKey(event) }

    visible: opened || content.opacity > 0
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "quickshell.keshiki-studio"
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: opened ? 1 : 0

    AppearanceController {
        id: appearanceController
        onFocusRequested: focusTimer.start()
        onThemeScrollRequested: themeScrollTimer.restart()
        onWallpaperScrollRequested: wallpaperScrollTimer.restart()
    }

    Timer { id: focusTimer; interval: 60; onTriggered: keyScope.forceActiveFocus() }
    Timer { id: themeScrollTimer; interval: 30; onTriggered: ensureThemeVisible() }
    Timer { id: wallpaperScrollTimer; interval: 30; onTriggered: ensureWallpaperVisible() }

    Rectangle {
        anchors.fill: parent
        color: panelBg
        opacity: content.opacity > 0 ? 0.78 * content.opacity : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    MouseArea { anchors.fill: parent; enabled: studio.opened; onClicked: opened = false }

    FocusScope {
        id: keyScope
        anchors.fill: parent
        focus: true
        Keys.onPressed: (event) => handleKey(event)

        Item {
            id: content
            anchors.centerIn: parent
            enabled: studio.opened
            width: Math.max(780, Math.min(1120, studio.width - 56))
            height: Math.max(560, Math.min(720, studio.height - 64))
            opacity: opened ? 1 : 0
            scale: opened ? 1 : 0.96
            transform: Translate {
                y: studio.opened ? 0 : 12
                Behavior on y { NumberAnimation { duration: studio.opened ? 240 : 120; easing.type: studio.opened ? Easing.OutQuart : Easing.InQuad } }
            }
            Behavior on opacity { NumberAnimation { duration: studio.opened ? 160 : 110; easing.type: studio.opened ? Easing.OutQuart : Easing.InQuad } }
            Behavior on scale { NumberAnimation { duration: studio.opened ? 260 : 130; easing.type: studio.opened ? Easing.OutQuart : Easing.InQuad } }

            Rectangle {
                anchors.fill: parent
                color: panelBg
                border.color: panelAccent
                border.width: 1
                clip: true

                MouseArea { anchors.fill: parent; onClicked: (mouse) => mouse.accepted = true }

                Item {
                    id: header
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.topMargin: 16
                    height: 44

                    Rectangle {
                        id: headerSeal
                        width: 44
                        height: 44
                        color: panelAccent

                        SharedUi.ShellLogo {
                            anchors.centerIn: parent
                            size: 26
                            color: panelBg
                        }
                    }

                    Column {
                        anchors.left: headerSeal.right
                        anchors.leftMargin: 12
                        anchors.right: sectionTabs.left
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            text: "APPEARANCE STUDIO"
                            color: panelFg
                            font.pixelSize: 12
                            font.letterSpacing: 3
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            text: "Wallpaper and palette as one scene"
                            color: mutedFg
                            font.pixelSize: 9
                            elide: Text.ElideRight
                        }
                    }

                    Row {
                        id: sectionTabs
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 32
                        spacing: 8

                        Repeater {
                            model: [
                                { key: "wallpaper", label: "WALLPAPER" },
                                { key: "theme", label: "PALETTE" }
                            ]

                            Rectangle {
                                id: sectionChip
                                property bool selected: studio.activeSection === modelData.key

                                width: 138
                                height: 32
                                color: sectionChip.selected ? panelAccent : (sectionMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.075) : "transparent")
                                border.color: sectionChip.selected ? panelAccent : Qt.rgba(1, 1, 1, 0.055)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.label
                                        color: sectionChip.selected ? panelBg : panelFg
                                        font.pixelSize: 9
                                        font.letterSpacing: 2
                                        font.bold: true
                                    }

                                }

                                MouseArea {
                                    id: sectionMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: setSection(modelData.key)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: headerRule
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: header.bottom
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.topMargin: 12
                    height: 1
                    color: mutedFg
                    opacity: 0.35
                }

                Row {
                    id: body
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: headerRule.bottom
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.topMargin: 12
                    anchors.bottomMargin: 16
                    spacing: 16

                    readonly property real trackWidth: width - spacing
                    readonly property real stageWidth: trackWidth * 0.67
                    readonly property real archiveWidth: trackWidth * 0.33

                    Column {
                        width: body.stageWidth
                        height: body.height
                        spacing: 12

                        ScenePreview {
                            width: parent.width
                            height: parent.height - 144
                            theme: studio.theme
                            selectedTheme: studio.selectedTheme
                            selectedWallpaper: studio.selectedWallpaper
                            imageSource: studio.imageSource
                            activeSection: studio.activeSection
                            previewBg: studio.previewBg
                            previewFg: studio.previewFg
                            previewAccent: studio.previewAccent
                            previewSurface: studio.previewSurface
                            previewMuted: studio.previewMuted
                            panelAccent: studio.panelAccent
                            sceneApplied: studio.sceneApplied
                        }

                        WallpaperFilmstrip {
                            id: wallpaperFilmstrip
                            width: parent.width
                            height: 132
                            theme: studio.theme
                            wallpaperItems: studio.wallpaperItems
                            selectedWallpaperIndex: studio.selectedWallpaperIndex
                            activeSection: studio.activeSection
                            imageSource: studio.imageSource
                            panelBg: studio.panelBg
                            panelFg: studio.panelFg
                            panelAccent: studio.panelAccent
                            panelSurface: studio.panelSurface
                            mutedFg: studio.mutedFg
                            onWallpaperSelected: (index) => {
                                studio.selectedWallpaperIndex = index
                                studio.setSection("wallpaper")
                            }
                        }
                    }

                    ThemeArchive {
                        id: themeArchive
                        width: body.archiveWidth
                        height: body.height
                        theme: studio.theme
                        selectedTheme: studio.selectedTheme
                        selectedWallpaper: studio.selectedWallpaper
                        themeItems: studio.themeItems
                        selectedThemeIndex: studio.selectedThemeIndex
                        activeSection: studio.activeSection
                        applying: studio.applying
                        previewBg: studio.previewBg
                        previewAccent: studio.previewAccent
                        panelBg: studio.panelBg
                        panelFg: studio.panelFg
                        panelAccent: studio.panelAccent
                        panelSurface: studio.panelSurface
                        mutedFg: studio.mutedFg
                        onThemeSelected: (index) => {
                            studio.selectedThemeIndex = index
                            studio.setSection("theme")
                        }
                        onDynamicRequested: studio.selectDynamicTheme()
                        onApplyRequested: studio.applyScene()
                    }
                }
            }
        }
    }
}

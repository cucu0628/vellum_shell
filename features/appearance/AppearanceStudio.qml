pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../../ui" as SharedUi
import "."

// Teljes kepernyos valaszto ket kulon nezettel: hatterkep es tema. Mindketto
// ugyanaz a ferde carousel, de sajat controllerrel es sajat elkotelezessel --
// a hatterkep valtasa nem nyul a temahoz, a temavaltas nem a hatterkephez.
//
// A bar alatt kezdodik, igy a temavalaszto elo elonezete (az ujraszinezett
// bar) a valasztas kozben is latszik.
PanelWindow {
    id: studio

    property var backend: null
    property var theme: null
    property var wallpaperController: null
    property bool opened: false
    // Melyik nezettel nyilt (`style wallpaper` / `style theme`). A nezetvaltast
    // csak kerjuk (`modeRequested`), a LazyPopup a forrasa.
    property string mode: "wallpaper"
    property int barHeight: 26
    property bool searchVisible: false

    readonly property bool themeMode: mode === "theme"
    readonly property var picker: themeMode ? themePicker : wallpaperPicker
    readonly property bool hasItems: picker.visibleItems.length > 0

    readonly property color bg: theme ? theme.background : "#11130f"
    readonly property color fg: theme ? theme.foreground : "#e8ddc7"
    readonly property color accent: theme ? theme.accent : "#b7372f"
    readonly property color surfaceColor: theme && theme.surface ? theme.surface : "#191b16"
    readonly property color mutedFg: theme && theme.muted ? theme.muted : "#958b7a"

    readonly property int cardHeight: Math.round(Math.max(240, Math.min(460, height * 0.44)))
    readonly property int cardWidth: Math.round(cardHeight * (themeMode ? 0.6 : 0.7))

    // A LazyPopup ezt nezi: amig igaz, nem bontja le a feluletet, tehat az
    // alkalmazas callbackje meg letezo controllert talal.
    readonly property bool busy: wallpaperPicker.applying || themePicker.applying

    signal modeRequested(string mode)

    function releaseResources() {
        wallpaperPicker.release()
        themePicker.release()
    }

    function close() {
        opened = false
    }

    function switchMode() {
        if (picker.confirmingIndex >= 0) return
        searchVisible = false
        modeRequested(themeMode ? "wallpaper" : "theme")
    }

    function openSearch() {
        if (themeMode) return
        searchVisible = true
        searchField.forceInputFocus()
    }

    function closeSearch() {
        searchField.text = ""
        wallpaperPicker.setQuery("")
        searchVisible = false
        keyScope.forceActiveFocus()
    }

    function handleKey(event) {
        var ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        if (event.key === Qt.Key_Escape) {
            if (searchVisible) closeSearch()
            else close()
        } else if (event.key === Qt.Key_Left || (event.key === Qt.Key_H && !searchVisible)) {
            picker.step(-1)
        } else if (event.key === Qt.Key_Right || (event.key === Qt.Key_L && !searchVisible)) {
            picker.step(1)
        } else if (event.key === Qt.Key_Home && !searchVisible) {
            picker.select(0)
        } else if (event.key === Qt.Key_End && !searchVisible) {
            picker.select(picker.visibleItems.length - 1)
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            picker.pick()
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            switchMode()
        } else if ((event.key === Qt.Key_F && ctrl) || (event.key === Qt.Key_Slash && !searchVisible)) {
            openSearch()
        } else {
            return
        }
        event.accepted = true
    }

    visible: opened || stage.opacity > 0
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    margins.top: barHeight
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "quickshell.appearance-studio"
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Elhalvanyulas kozben mar atengedi a kattintast az asztalnak.
    mask: Region { item: studio.opened ? stage : null }

    onOpenedChanged: {
        if (opened) {
            searchVisible = false
            searchField.text = ""
            focusTimer.restart()
        }
    }

    onModeChanged: if (opened) focusTimer.restart()

    WallpaperPickerController {
        id: wallpaperPicker
        backend: studio.backend
        theme: studio.theme
        wallpaperController: studio.wallpaperController
        active: studio.opened && !studio.themeMode
        onCloseRequested: studio.close()
    }

    ThemePickerController {
        id: themePicker
        backend: studio.backend
        theme: studio.theme
        wallpaperController: studio.wallpaperController
        active: studio.opened && studio.themeMode
        onCloseRequested: studio.close()
    }

    Timer { id: focusTimer; interval: 60; onTriggered: keyScope.forceActiveFocus() }

    Item {
        id: stage

        anchors.fill: parent
        opacity: studio.opened ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        // A tema hattere, nem fekete: a temavalaszto alatt ez is elo szinez.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(studio.bg.r, studio.bg.g, studio.bg.b, 0.9)
            Behavior on color { ColorAnimation { duration: 190; easing.type: Easing.OutCubic } }
        }

        // Temanezetben a kijelolt kartya mogott a tema akcentusa dereng, es
        // lapozaskor atuszik a kovetkezo szinbe: a hatter is a valasztast koveti.
        Shape {
            id: glow

            readonly property var shown: themePicker.displayEntry(themePicker.currentEntry)
            property color tint: shown ? shown.accent : studio.accent

            anchors.fill: parent
            opacity: studio.themeMode && studio.hasItems ? 1 : 0
            visible: opacity > 0
            preferredRendererType: Shape.CurveRenderer
            Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Behavior on tint { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }

            ShapePath {
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: glow.width / 2
                    centerY: glow.height / 2 - 24
                    centerRadius: Math.max(glow.width, glow.height) * 0.42
                    focalX: centerX
                    focalY: centerY
                    GradientStop { position: 0; color: Qt.rgba(glow.tint.r, glow.tint.g, glow.tint.b, 0.2) }
                    GradientStop { position: 0.55; color: Qt.rgba(glow.tint.r, glow.tint.g, glow.tint.b, 0.06) }
                    GradientStop { position: 1; color: Qt.rgba(glow.tint.r, glow.tint.g, glow.tint.b, 0) }
                }
                PathRectangle { x: 0; y: 0; width: glow.width; height: glow.height }
            }
        }

        // Ures teruletre kattintva bezar, ahogy egy popup a kulso kattintasra.
        MouseArea {
            anchors.fill: parent
            enabled: studio.opened && studio.picker.confirmingIndex < 0
            onClicked: studio.close()
        }

        FocusScope {
            id: keyScope

            anchors.fill: parent
            focus: true
            Keys.onPressed: (event) => studio.handleKey(event)

            Row {
                id: tabs

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 40
                spacing: 8

                Repeater {
                    model: [
                        { mode: "wallpaper", label: qsTr("Wallpaper") },
                        { mode: "theme", label: qsTr("Theme") }
                    ]

                    delegate: Item {
                        id: tab

                        required property var modelData
                        readonly property bool selected: studio.mode === modelData.mode

                        width: tabLabel.implicitWidth + 32
                        height: 32

                        Text {
                            id: tabLabel
                            anchors.centerIn: parent
                            text: tab.modelData.label
                            color: tab.selected ? studio.fg : studio.mutedFg
                            font.pixelSize: 13
                            font.weight: tab.selected ? Font.DemiBold : Font.Medium
                            Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: tab.selected ? tabLabel.implicitWidth : 0
                            height: 2
                            radius: 1
                            color: studio.accent
                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }

                        SharedUi.Pressable {
                            anchors.fill: parent
                            theme: studio.theme
                            accessibleName: tab.modelData.label
                            onClicked: if (!tab.selected) studio.switchMode()
                        }
                    }
                }
            }

            SharedUi.SearchField {
                id: searchField

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: tabs.bottom
                anchors.topMargin: 16
                width: 360
                visible: studio.searchVisible
                opened: studio.searchVisible
                foreground: studio.fg
                accent: studio.accent
                muted: studio.mutedFg
                surface: studio.surfaceColor
                placeholder: qsTr("Search wallpapers…")
                onTextEdited: (text) => wallpaperPicker.setQuery(text)
                onKeyPressed: (event) => studio.handleKey(event)
            }

            SkewCarousel {
                id: carousel

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -24
                height: studio.cardHeight * 1.6
                visible: studio.hasItems

                theme: studio.theme
                // Amig a compositor meg nem adta meg az ablak meretet, a kartyak
                // meretenek sincs ertelme: addig nincs mit betolteni.
                model: studio.width > 0 && studio.height > 0 ? studio.picker.visibleItems : []
                currentIndex: studio.picker.currentIndex
                confirmingIndex: studio.picker.confirmingIndex
                cardWidth: studio.cardWidth
                cardHeight: studio.cardHeight
                card: studio.themeMode ? themeCard : wallpaperCard

                onCurrentRequested: (index) => studio.picker.select(index)
                onActivated: studio.picker.pick()
                onStepRequested: (delta) => studio.picker.step(delta)
            }

            Component {
                id: wallpaperCard
                WallpaperCard {
                    imageSource: function (path) {
                        return studio.wallpaperController ? studio.wallpaperController.source(path) : path
                    }
                }
            }

            Component {
                id: themeCard
                ThemeCard {
                    dynamicSummary: themePicker.dynamicSummary
                    wallpaperSource: studio.wallpaperController
                        ? studio.wallpaperController.source(studio.wallpaperController.currentWallpaper)
                        : ""
                }
            }

            // Egy cim es egy metaadat-sor: a kijelolt elem neve, alatta hanyadik
            // es hogy ez-e az aktiv.
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: carousel.bottom
                anchors.topMargin: 8
                width: Math.min(640, parent.width - 48)
                spacing: 4
                visible: studio.hasItems

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: studio.picker.currentEntry ? studio.picker.currentEntry.name : ""
                    textFormat: Text.PlainText
                    elide: Text.ElideMiddle
                    color: studio.fg
                    font.family: "serif"
                    font.pixelSize: 24
                    font.weight: Font.Medium
                    Behavior on color { ColorAnimation { duration: 190; easing.type: Easing.OutCubic } }
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: studio.metadataLine()
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: studio.mutedFg
                    font.pixelSize: 11
                }
            }

            Text {
                anchors.centerIn: parent
                width: Math.min(520, parent.width - 48)
                visible: studio.picker.loaded && !studio.hasItems
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: studio.themeMode
                    ? qsTr("No themes found in the themes folder.")
                    : (wallpaperPicker.query !== ""
                        ? qsTr("No wallpaper matches “%1”.").arg(wallpaperPicker.query)
                        : qsTr("Add images to ~/Pictures/wallpapers to choose a wallpaper."))
                textFormat: Text.PlainText
                color: studio.mutedFg
                font.pixelSize: 13
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 32
                spacing: 24

                Repeater {
                    model: studio.themeMode
                        ? [["← →", qsTr("browse")], ["Enter", qsTr("apply")], ["Tab", qsTr("wallpapers")], ["Esc", qsTr("cancel")]]
                        : [["← →", qsTr("browse")], ["Enter", qsTr("apply")], ["Ctrl F", qsTr("search")], ["Tab", qsTr("themes")], ["Esc", qsTr("close")]]

                    delegate: Row {
                        id: hint

                        required property var modelData

                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: hint.modelData[0]
                            color: studio.fg
                            font.family: "monospace"
                            font.pixelSize: 10
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: hint.modelData[1]
                            color: studio.mutedFg
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }
    }

    function metadataLine() {
        var entry = picker.currentEntry
        if (!entry) return ""
        var parts = [qsTr("%1 of %2").arg(picker.currentIndex + 1).arg(picker.visibleItems.length)]
        if (themeMode && entry.kind === "dynamic") parts.push(qsTr("derived from the wallpaper"))
        if (picker.isCurrent(entry)) parts.push(qsTr("active"))
        return parts.join("  ·  ")
    }
}

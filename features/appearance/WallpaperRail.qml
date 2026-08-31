pragma ComponentBehavior: Bound

import QtQuick

// Coverflow: a kijelolt kartya kozepen all es nagyobb, a szomszedok keskeny
// szeletek. A gorgetest a ListView vegzi (StrictlyEnforceRange), nem kezzel
// szamolt contentX -- igy a kartyameret valtozasa nem tori el a pozicionalast.
Item {
    id: rail

    property var theme: null
    property var wallpaperItems: []
    property int selectedIndex: 0
    property var imageSource: function (path) { return path }
    property bool imagesEnabled: false
    // A sav alatti alap szine: az elhalvanyulo szelek ebbe olvadnak bele.
    property color wellColor: "#11130f"

    readonly property string bg: theme ? theme.background : "#11130f"
    readonly property string fg: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#958b7a"

    readonly property int idleCardWidth: 148
    readonly property int activeCardWidth: 224

    signal wallpaperSelected(int index)
    signal stepRequested(int delta)

    onWallpaperItemsChanged: {
        if (wallpaperItems.length === 0) imagesEnabled = false
        else thumbnailEnableTimer.restart()
    }

    // A sav elobb rajzolodjon ki, csak utana induljon a kepek dekodolasa.
    Timer {
        id: thumbnailEnableTimer
        interval: 0
        onTriggered: rail.imagesEnabled = true
    }

    // A ListView sajat maga is ir a currentIndex-be (peldaul modellcserekor), ami
    // szetlone egy deklarativ bindinget -- ezert kezzel tartjuk szinkronban.
    function syncCurrent() {
        if (list.count > 0) list.currentIndex = Math.max(0, Math.min(rail.selectedIndex, list.count - 1))
    }

    onSelectedIndexChanged: syncCurrent()

    ListView {
        id: list

        // Ha a kartyak kiferenek, a nezet rajuk szukul es kozepre all. Kulonben
        // a StrictlyEnforceRange a kijelolt kartyat huzna kozepre, es a sav eleje
        // uresen maradna -- a delegate szelessegek allandoak, igy nincs hurok.
        readonly property bool overflows: contentWidth > rail.width

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: overflows ? rail.width : Math.min(rail.width, contentWidth)
        orientation: ListView.Horizontal
        model: rail.wallpaperItems
        highlightRangeMode: overflows ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
        preferredHighlightBegin: Math.max(0, (width - rail.activeCardWidth) / 2)
        preferredHighlightEnd: Math.max(rail.activeCardWidth, (width + rail.activeCardWidth) / 2)
        highlightMoveDuration: 170
        highlightMoveVelocity: -1
        spacing: 10
        reuseItems: true
        cacheBuffer: 400
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        onCountChanged: rail.syncCurrent()
        Component.onCompleted: rail.syncCurrent()

        delegate: Item {
            id: frame

            required property var modelData
            required property int index

            readonly property bool current: index === rail.selectedIndex

            width: frame.current ? rail.activeCardWidth : rail.idleCardWidth
            height: list.height
            Behavior on width { NumberAnimation { duration: 170; easing.type: Easing.OutQuart } }

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: frame.current ? 0 : 10
                anchors.bottomMargin: frame.current ? 0 : 10
                color: rail.bg
                Behavior on color { ColorAnimation { duration: 190; easing.type: Easing.OutCubic } }
                border.color: frame.current
                    ? rail.accent
                    : (wallpaperMouse.containsMouse ? rail.mutedFg : Qt.rgba(1, 1, 1, 0.06))
                border.width: 1
                opacity: frame.current ? 1 : (wallpaperMouse.containsMouse ? 0.85 : 0.55)
                clip: true

                Behavior on anchors.topMargin { NumberAnimation { duration: 170; easing.type: Easing.OutQuart } }
                Behavior on anchors.bottomMargin { NumberAnimation { duration: 170; easing.type: Easing.OutQuart } }
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on border.color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }

                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: rail.imagesEnabled ? rail.imageSource(frame.modelData.path) : ""
                    sourceSize: Qt.size(360, 224)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    // A sourceSize korlatozza a memoriat, a cache viszont
                    // megsporolja az ujradekodolast oda-vissza gorgetesnel.
                    cache: true
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 1
                    height: 20
                    color: rail.bg
                    opacity: 0.9
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 7
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 5
                    text: frame.modelData.name
                    color: frame.current ? rail.accent : rail.fg
                    font.pixelSize: 9
                    font.bold: true
                    elide: Text.ElideRight
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 2
                    color: rail.accent
                    visible: frame.current
                }
            }

            MouseArea {
                id: wallpaperMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: rail.wallpaperSelected(frame.index)
            }
        }
    }

    // Elhalvanyulo szelek: jelzik, hogy a sav folytatodik a lathato reszen tul.
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 28
        visible: !list.atXBeginning
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: rail.wellColor }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 28
        visible: !list.atXEnd
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: rail.wellColor }
        }
    }

    // Egy kattanas egy kep. Nyers contentX-tolas helyett index-leptetes, hogy a
    // touchpad ne repitsen at tiz kepen.
    WheelHandler {
        id: wheel
        property real accumulated: 0

        target: null
        onWheel: (event) => {
            var delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y
            if (delta === 0) delta = event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x
            wheel.accumulated += delta

            while (wheel.accumulated <= -120) {
                wheel.accumulated += 120
                rail.stepRequested(1)
            }
            while (wheel.accumulated >= 120) {
                wheel.accumulated -= 120
                rail.stepRequested(-1)
            }
            event.accepted = true
        }
    }
}

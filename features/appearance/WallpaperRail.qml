pragma ComponentBehavior: Bound

import QtQuick

// Kepkozpontu coverflow: a kijelolt jelenet nagyobb es teljes fenyeron marad,
// a tobbi csak keretezi. A fajlnev nem ismetlodik allandoan a kartyakon.
Item {
    id: rail

    property var theme: null
    property var wallpaperItems: []
    property int selectedIndex: 0
    property var imageSource: function (path) { return path }
    property bool imagesEnabled: false
    property color wellColor: "#11130f"

    readonly property color fg: theme ? theme.foreground : "#e8ddc7"
    readonly property color accent: theme ? theme.accent : "#b7372f"
    readonly property color mutedFg: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property color hairline: Qt.rgba(fg.r, fg.g, fg.b, 0.12)
    readonly property int idleCardWidth: 174
    readonly property int activeCardWidth: 254

    signal wallpaperSelected(int index)
    signal stepRequested(int delta)

    onWallpaperItemsChanged: {
        if (wallpaperItems.length === 0) imagesEnabled = false
        else thumbnailEnableTimer.restart()
    }

    Timer {
        id: thumbnailEnableTimer
        interval: 0
        onTriggered: rail.imagesEnabled = true
    }

    function syncCurrent() {
        if (list.count > 0) list.currentIndex = Math.max(0, Math.min(rail.selectedIndex, list.count - 1))
    }

    onSelectedIndexChanged: syncCurrent()

    ListView {
        id: list
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
        highlightMoveDuration: 180
        highlightMoveVelocity: -1
        spacing: 10
        reuseItems: true
        cacheBuffer: 500
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
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutQuart } }

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: frame.current ? 0 : 10
                anchors.bottomMargin: frame.current ? 0 : 10
                color: rail.wellColor
                border.color: frame.current
                    ? rail.accent
                    : (wallpaperMouse.containsMouse ? rail.mutedFg : rail.hairline)
                border.width: frame.current ? 2 : 1
                opacity: frame.current ? 1 : (wallpaperMouse.containsMouse ? 0.94 : 0.70)
                clip: true

                Behavior on anchors.topMargin { NumberAnimation { duration: 180; easing.type: Easing.OutQuart } }
                Behavior on anchors.bottomMargin { NumberAnimation { duration: 180; easing.type: Easing.OutQuart } }
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on border.color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Image {
                    anchors.fill: parent
                    anchors.margins: frame.current ? 2 : 1
                    source: rail.imagesEnabled ? rail.imageSource(frame.modelData.path) : ""
                    sourceSize: Qt.size(420, 240)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    cache: true
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: frame.current ? 2 : 1
                    height: 34
                    visible: wallpaperMouse.containsMouse && !frame.current
                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.82) }
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 9
                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 7
                    visible: wallpaperMouse.containsMouse && !frame.current
                    text: frame.modelData.name
                    color: "#ffffff"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: 8
                    anchors.topMargin: 8
                    width: 22
                    height: 3
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

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 34
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
        width: 34
        visible: !list.atXEnd
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: rail.wellColor }
        }
    }

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

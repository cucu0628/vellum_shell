pragma ComponentBehavior: Bound

import QtQuick

// A palettak vizszintes chip-sorban, ugyanazzal a kozepen-tarto mintaval, mint
// a hatterkep sav. A dinamikus paletta all elol -- a backend `theme list` mar
// igy rendez.
Item {
    id: rail

    property var theme: null
    property var themeItems: []
    property int selectedIndex: 0
    property color wellColor: "#11130f"

    readonly property string bg: theme ? theme.background : "#11130f"
    readonly property string fg: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string surfaceColor: theme && theme.surface ? theme.surface : "#191b16"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#958b7a"

    readonly property int chipWidth: 184

    signal paletteSelected(int index)
    signal stepRequested(int delta)

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
        model: rail.themeItems
        highlightRangeMode: overflows ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
        preferredHighlightBegin: Math.max(0, (width - rail.chipWidth) / 2)
        preferredHighlightEnd: Math.max(rail.chipWidth, (width + rail.chipWidth) / 2)
        highlightMoveDuration: 260
        highlightMoveVelocity: -1
        spacing: 8
        reuseItems: true
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        onCountChanged: rail.syncCurrent()
        Component.onCompleted: rail.syncCurrent()

        delegate: Rectangle {
            id: chip

            required property var modelData
            required property int index

            readonly property bool current: index === rail.selectedIndex
            readonly property bool dynamic: modelData.kind === "dynamic"

            width: rail.chipWidth
            height: list.height
            color: chip.current ? rail.surfaceColor : (chipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.075) : "transparent")
            border.color: chip.current ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
            Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }
            Behavior on border.color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: 14
                color: chip.modelData.accent
                opacity: chip.current ? 1 : 0.55
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 17
                anchors.right: parent.right
                anchors.rightMargin: 11
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Text {
                    width: parent.width
                    text: chip.modelData.name
                    color: chip.current ? rail.accent : rail.fg
                    font.family: "serif"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Row {
                    spacing: 3

                    Repeater {
                        model: [chip.modelData.background, chip.modelData.surface, chip.modelData.accent, chip.modelData.foreground, chip.modelData.muted]

                        Rectangle {
                            required property string modelData
                            width: 24
                            height: 6
                            color: modelData
                            border.color: Qt.rgba(1, 1, 1, 0.16)
                            border.width: 1
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: chip.dynamic ? "FROM THIS IMAGE  ·  D" : (chip.modelData.current ? "CURRENT" : "STATIC PALETTE")
                    color: chip.dynamic ? chip.modelData.accent : rail.mutedFg
                    font.pixelSize: 8
                    font.bold: chip.dynamic
                    font.letterSpacing: 1
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: chipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: rail.paletteSelected(chip.index)
            }
        }
    }

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

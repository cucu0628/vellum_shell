pragma ComponentBehavior: Bound

import QtQuick

// A palettak tenyleges szinmintak. Az allapotot keret es jeloles mutatja, igy
// nincs szukseg minden kartyan magyarazo mikroszovegre.
Item {
    id: rail

    property var theme: null
    property var themeItems: []
    property int selectedIndex: 0
    property color wellColor: "#11130f"

    readonly property color fg: theme ? theme.foreground : "#e8ddc7"
    readonly property color accent: theme ? theme.accent : "#b7372f"
    readonly property color mutedFg: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property color hairline: Qt.rgba(fg.r, fg.g, fg.b, 0.12)
    readonly property int chipWidth: 166

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
        highlightMoveDuration: 210
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
            color: rail.wellColor
            border.color: chip.current
                ? chip.modelData.accent
                : (chipMouse.containsMouse ? rail.mutedFg : rail.hairline)
            border.width: chip.current ? 2 : 1
            opacity: chip.current ? 1 : (chipMouse.containsMouse ? 0.94 : 0.74)
            clip: true
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on border.color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 7
                anchors.rightMargin: 7
                anchors.topMargin: 7
                height: 24
                spacing: 2

                Rectangle { width: 25; height: parent.height; color: chip.modelData.background }
                Rectangle { width: 25; height: parent.height; color: chip.modelData.surface }
                Rectangle { width: 40; height: parent.height; color: chip.modelData.accent }
                Rectangle { width: 25; height: parent.height; color: chip.modelData.foreground }
                Rectangle { width: 25; height: parent.height; color: chip.modelData.muted }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 9
                anchors.right: stateMark.left
                anchors.rightMargin: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 7
                text: chip.modelData.name
                color: chip.current ? chip.modelData.accent : rail.fg
                font.family: "serif"
                font.pixelSize: 13
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Rectangle {
                id: stateMark
                anchors.right: parent.right
                anchors.rightMargin: 9
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 9
                width: chip.dynamic ? 12 : 7
                height: 7
                color: chip.dynamic ? chip.modelData.accent : "transparent"
                border.color: chip.modelData.current ? chip.modelData.accent : "transparent"
                border.width: 1
                visible: chip.dynamic || chip.modelData.current
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
        width: 32
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
        width: 32
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

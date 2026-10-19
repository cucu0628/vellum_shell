import QtQuick

// Hangero-csuszka: lekerekitett sav, gomb a vegen. Kattintasra es huzasra
// allit, gorgetes a sor sajat MouseAreajan at erkezik.
Item {
    id: bar

    property var controller: null
    property var node: null

    readonly property real ratio: controller ? controller.volumeRatio(node) : 0
    readonly property bool muted: node && node.audio && node.audio.muted
    readonly property bool active: dragArea.containsMouse || dragArea.pressed
    readonly property color fillColor: muted
        ? (controller ? controller.mutedFg : "#9f8f7c")
        : (controller ? controller.panelAccent : "#d7472f")

    height: 20

    Rectangle {
        id: track

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: bar.active ? 6 : 4
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.1)

        Behavior on height { NumberAnimation { duration: 100 } }

        Rectangle {
            width: Math.max(track.height, parent.width * bar.ratio)
            height: parent.height
            radius: parent.radius
            color: bar.fillColor
            opacity: bar.muted ? 0.5 : 1
        }
    }

    Rectangle {
        x: Math.max(0, Math.min(bar.width - width, bar.width * bar.ratio - width / 2))
        anchors.verticalCenter: parent.verticalCenter
        width: bar.active ? 14 : 10
        height: width
        radius: width / 2
        color: controller ? controller.panelFg : "#f1e7d0"
        opacity: bar.muted ? 0.6 : 1

        Behavior on width { NumberAnimation { duration: 100 } }
    }

    MouseArea {
        id: dragArea

        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: (mouse) => {
            if (bar.controller) bar.controller.setVolumeFromX(bar.node, mouse.x, width)
        }
        onPositionChanged: (mouse) => {
            if (pressed && bar.controller) bar.controller.setVolumeFromX(bar.node, mouse.x, width)
        }
    }
}

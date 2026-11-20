import QtQuick
import "../../ui" as SharedUi

// Vekony hangero-csuszka a masodlagos sorokhoz (mikrofon, alkalmazasok):
// lekerekitett sav, gomb a vegen. Kattintasra es huzasra allit, a nyilakkal
// 5%-ot lep; a gorgetes a sor sajat MouseAreajan at erkezik.
Item {
    id: bar

    property var controller: null
    property var node: null
    property string accessibleName: qsTr("Volume")

    readonly property real ratio: controller ? controller.volumeRatio(node) : 0
    readonly property bool muted: node && node.audio && node.audio.muted
    readonly property bool active: dragArea.containsMouse || dragArea.pressed || activeFocus
    readonly property color fillColor: muted
        ? (controller ? controller.mutedFg : "#958b7a")
        : (controller ? controller.panelAccent : "#b7372f")

    function step(delta) {
        if (controller && node && node.audio) controller.setVolume(node, (node.audio.volume || 0) + delta)
    }

    height: 20
    activeFocusOnTab: visible

    Accessible.role: Accessible.Slider
    Accessible.name: accessibleName
    Accessible.description: muted ? qsTr("Muted") : qsTr("%1 percent").arg(controller ? controller.percent(node) : 0)

    Keys.onLeftPressed: (event) => { step(-0.05); event.accepted = true }
    Keys.onDownPressed: (event) => { step(-0.05); event.accepted = true }
    Keys.onRightPressed: (event) => { step(0.05); event.accepted = true }
    Keys.onUpPressed: (event) => { step(0.05); event.accepted = true }

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
        color: controller ? controller.panelFg : "#e8ddc7"
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

    SharedUi.FocusRing {
        theme: bar.controller ? bar.controller.theme : null
        active: bar.activeFocus
        cornerRadius: 4
        anchors.margins: -2
    }
}

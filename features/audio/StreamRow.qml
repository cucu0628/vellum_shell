import "." as AudioUi
import QtQuick
import "../../ui" as SharedUi

// Egy alkalmazas hangja, ugyanabban a sorformaban, mint a tobbi panel listai:
// csempe (kattintasra nemit), nev es mit jatszik, jobbra a sajat csuszka.
// Felvetelnel csak azt mutatja, ki hasznalja a mikrofont.
Rectangle {
    id: streamRow

    property var controller: null
    property var node: null
    property bool input: false

    readonly property bool muted: node && node.audio && node.audio.muted
    readonly property var theme: controller ? controller.theme : null
    readonly property string fg: controller ? controller.panelFg : "#f1e7d0"
    readonly property string mutedColor: controller ? controller.mutedFg : "#9f8f7c"
    readonly property string accent: controller ? controller.panelAccent : "#d7472f"
    readonly property string title: controller ? controller.nodeTitle(node) : ""
    readonly property string detail: input
        ? qsTr("Recording")
        : (controller ? controller.nodeSubtitle(node) : "")

    height: 52
    radius: 8
    color: streamHover.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
    Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }

    MouseArea {
        id: streamHover

        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        onWheel: (wheel) => {
            if (streamRow.controller && !streamRow.input) streamRow.controller.wheelVolume(streamRow.node, wheel)
        }
    }

    Rectangle {
        id: tile

        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: 32
        radius: 8
        color: iconMouse.containsMouse ? Qt.lighter(controller ? controller.inkBg : "#1b1613", 1.25) : (controller ? controller.inkBg : "#1b1613")
        Behavior on color { ColorAnimation { duration: 110 } }

        Text {
            anchors.centerIn: parent
            text: streamRow.input
                ? (streamRow.muted ? "󰍭" : "󰍬")
                : (streamRow.muted ? "󰖁" : "󰕾")
            color: streamRow.muted ? streamRow.mutedColor : streamRow.fg
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 16
        }

        SharedUi.Pressable {
            id: iconMouse

            anchors.fill: parent
            theme: streamRow.theme
            focusRadius: tile.radius
            accessibleName: (streamRow.muted ? qsTr("Unmute %1") : qsTr("Mute %1")).arg(streamRow.title)
            onClicked: if (streamRow.controller) streamRow.controller.toggleMute(streamRow.node)
        }
    }

    Column {
        id: label

        anchors.left: tile.right
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: streamRow.input ? parent.width - x - 12 : Math.min(150, (parent.width - x) * 0.4)
        spacing: 2

        Text {
            width: parent.width
            text: streamRow.title
            textFormat: Text.PlainText
            color: streamRow.fg
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: streamRow.detail
            textFormat: Text.PlainText
            color: streamRow.input ? streamRow.accent : streamRow.mutedColor
            font.pixelSize: 10
            elide: Text.ElideRight
            visible: text !== "" && text !== streamRow.title
        }
    }

    AudioUi.VolumeBar {
        anchors.left: label.right
        anchors.leftMargin: 16
        anchors.right: percentText.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        visible: !streamRow.input
        controller: streamRow.controller
        node: streamRow.node
    }

    Text {
        id: percentText

        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        horizontalAlignment: Text.AlignRight
        visible: !streamRow.input
        text: (streamRow.controller ? streamRow.controller.percent(streamRow.node) : 0) + "%"
        color: streamRow.mutedColor
        font.pixelSize: 11
        font.features: { "tnum": 1 }
    }
}

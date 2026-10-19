import "." as AudioUi
import QtQuick
import "../../ui" as SharedUi

// Egy alkalmazas hangja. Lejatszasnal sajat csuszkaval; felvetelnel csak azt
// mutatja, ki hasznalja a mikrofont.
Rectangle {
    id: streamRow

    property var controller: null
    property var node: null
    property bool input: false

    readonly property bool muted: node && node.audio && node.audio.muted
    readonly property string fg: controller ? controller.panelFg : "#f1e7d0"
    readonly property string mutedColor: controller ? controller.mutedFg : "#9f8f7c"
    readonly property string accent: controller ? controller.panelAccent : "#d7472f"

    height: 44
    radius: 8
    color: streamHover.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"

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
        id: icon

        x: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        radius: 6
        color: iconMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

        Text {
            anchors.centerIn: parent
            text: streamRow.input
                ? (streamRow.muted ? "󰍭" : "󰍬")
                : (streamRow.muted ? "󰖁" : "󰕾")
            color: streamRow.muted ? streamRow.mutedColor : streamRow.fg
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 14
        }

        SharedUi.Pressable {
            id: iconMouse
            anchors.fill: parent
            accessibleName: streamRow.muted ? qsTr("Unmute") : qsTr("Mute")
            onClicked: if (streamRow.controller) streamRow.controller.toggleMute(streamRow.node)
        }
    }

    Column {
        id: label

        anchors.left: icon.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: streamRow.input ? parent.width - x - 100 : Math.min(170, (parent.width - x) * 0.4)
        spacing: 1

        Text {
            width: parent.width
            text: streamRow.controller ? streamRow.controller.nodeTitle(streamRow.node) : ""
            textFormat: Text.PlainText
            color: streamRow.fg
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: streamRow.input
                ? qsTr("Recording")
                : (streamRow.controller ? streamRow.controller.nodeSubtitle(streamRow.node) : "")
            textFormat: Text.PlainText
            color: streamRow.input ? streamRow.accent : streamRow.mutedColor
            font.pixelSize: 10
            elide: Text.ElideRight
            visible: text !== "" && text !== (streamRow.controller ? streamRow.controller.nodeTitle(streamRow.node) : "")
        }
    }

    AudioUi.VolumeBar {
        anchors.left: label.right
        anchors.leftMargin: 14
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
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        horizontalAlignment: Text.AlignRight
        visible: !streamRow.input
        text: (streamRow.controller ? streamRow.controller.percent(streamRow.node) : 0) + "%"
        color: streamRow.mutedColor
        font.pixelSize: 11
        font.features: { "tnum": 1 }
    }
}

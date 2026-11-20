import "." as AudioUi
import QtQuick
import Quickshell.Widgets
import "../../ui" as SharedUi

// Egy lejatszo alkalmazas hangja: balra az alkalmazas sajat ikonja (kattintasra
// nemit, mint a panel minden csempeje), mellette a neve es hogy mit jatszik,
// jobbra a sajat csuszka. Ikon nelkul a nev kezdobetuje all a csempen.
Item {
    id: streamRow

    property var controller: null
    property var node: null

    readonly property var theme: controller ? controller.theme : null
    readonly property bool muted: node && node.audio && node.audio.muted
    readonly property color fg: controller ? controller.panelFg : "#e8ddc7"
    readonly property color mutedColor: controller ? controller.mutedFg : "#958b7a"
    readonly property string title: controller ? controller.nodeTitle(node) : ""
    readonly property string detail: controller ? controller.nodeSubtitle(node) : ""
    readonly property string iconSource: controller ? controller.streamIcon(node) : ""

    implicitHeight: 44

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            if (streamRow.controller) streamRow.controller.wheelVolume(streamRow.node, wheel)
        }
    }

    Rectangle {
        id: tile

        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: 32
        radius: 8
        color: iconMouse.containsMouse
            ? Qt.lighter(controller ? controller.inkBg : "#191b16", 1.25)
            : (streamRow.iconSource !== "" ? "transparent" : (controller ? controller.inkBg : "#191b16"))
        Behavior on color { ColorAnimation { duration: 110 } }

        IconImage {
            anchors.centerIn: parent
            implicitSize: 24
            visible: streamRow.iconSource !== ""
            source: streamRow.iconSource
            asynchronous: true
            opacity: streamRow.muted ? 0.35 : 1
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }

        Text {
            anchors.centerIn: parent
            visible: streamRow.iconSource === ""
            text: streamRow.title !== "" ? streamRow.title.charAt(0).toUpperCase() : "?"
            color: streamRow.muted ? streamRow.mutedColor : streamRow.fg
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        // Nemitott alkalmazasnal az ikon sarkan egy kis athuzott hangszoro.
        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: -2
            width: 16
            height: 16
            radius: 8
            visible: streamRow.muted
            color: controller ? controller.panelBg : "#11130f"

            Text {
                anchors.centerIn: parent
                text: "󰖁"
                color: streamRow.mutedColor
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 11
            }
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
        anchors.right: slider.left
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: streamRow.title
            textFormat: Text.PlainText
            color: streamRow.muted ? streamRow.mutedColor : streamRow.fg
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: streamRow.detail
            textFormat: Text.PlainText
            color: streamRow.mutedColor
            font.pixelSize: 10
            elide: Text.ElideRight
            visible: text !== "" && text.toLowerCase() !== streamRow.title.toLowerCase()
        }
    }

    AudioUi.VolumeBar {
        id: slider

        anchors.right: percentText.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 88
        controller: streamRow.controller
        node: streamRow.node
        accessibleName: qsTr("%1 volume").arg(streamRow.title)
    }

    Text {
        id: percentText

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        horizontalAlignment: Text.AlignRight
        text: streamRow.muted ? qsTr("Off") : (streamRow.controller ? streamRow.controller.percent(streamRow.node) : 0) + "%"
        color: streamRow.mutedColor
        font.pixelSize: 11
        font.features: { "tnum": 1 }
    }
}

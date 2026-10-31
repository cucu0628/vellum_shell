import "." as AudioUi
import QtQuick
import Quickshell
import "../../ui" as SharedUi

// Az alapertelmezett kimenet vagy bemenet, ugyanabban a kartyaformaban, mint a
// tobbi panel allapotkartyaja: balra a csempe (kattintasra nemit), mellette a
// nev es a szazalek, alatta a csuszka. A valto (a szakaszcim "Change" gombja)
// a kartyan belul nyitja le a tobbi eszkozt.
Rectangle {
    id: deviceCard

    property var controller: null
    property var node: null
    property bool input: false
    property var others: []
    property bool expanded: false

    readonly property bool muted: node && node.audio && node.audio.muted
    readonly property var theme: controller ? controller.theme : null
    readonly property string fg: controller ? controller.panelFg : "#f1e7d0"
    readonly property string mutedColor: controller ? controller.mutedFg : "#9f8f7c"
    readonly property color accent: controller ? controller.panelAccent : "#d7472f"
    readonly property bool showOthers: expanded && others.length > 0

    height: 72 + (showOthers ? otherList.height + 8 : 0)
    radius: 10
    color: controller ? controller.inkBg : "#1b1613"
    clip: true

    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }

    // Gorgetes a kartya barmely pontjan a hangerot allitja.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            if (deviceCard.controller) deviceCard.controller.wheelVolume(deviceCard.node, wheel)
        }
    }

    Rectangle {
        id: tile

        x: 14
        y: 14
        width: 44
        height: 44
        radius: 10
        color: deviceCard.muted
            ? (muteMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
            : Qt.rgba(deviceCard.accent.r, deviceCard.accent.g, deviceCard.accent.b, muteMouse.containsMouse ? 0.24 : 0.16)
        Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            text: deviceCard.input
                ? (deviceCard.muted ? "󰍭" : (deviceCard.controller ? deviceCard.controller.deviceGlyph(deviceCard.node, true) : "󰍬"))
                : (deviceCard.muted ? "󰖁" : (deviceCard.controller ? deviceCard.controller.deviceGlyph(deviceCard.node, false) : "󰕾"))
            color: deviceCard.muted ? deviceCard.mutedColor : deviceCard.accent
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 20
        }

        SharedUi.Pressable {
            id: muteMouse

            anchors.fill: parent
            theme: deviceCard.theme
            focusRadius: tile.radius
            accessibleName: deviceCard.muted ? qsTr("Unmute") : qsTr("Mute")
            onClicked: if (deviceCard.controller) deviceCard.controller.toggleMute(deviceCard.node)
        }
    }

    Text {
        anchors.left: tile.right
        anchors.leftMargin: 12
        anchors.right: percentText.left
        anchors.rightMargin: 12
        y: 16
        text: deviceCard.controller ? deviceCard.controller.nodeTitle(deviceCard.node) : ""
        textFormat: Text.PlainText
        color: deviceCard.fg
        font.pixelSize: 13
        font.weight: Font.Medium
        elide: Text.ElideRight
    }

    Text {
        id: percentText

        anchors.right: parent.right
        anchors.rightMargin: 16
        y: 16
        text: deviceCard.muted ? qsTr("Muted") : (deviceCard.controller ? deviceCard.controller.percent(deviceCard.node) : 0) + "%"
        color: deviceCard.muted ? deviceCard.mutedColor : deviceCard.fg
        font.pixelSize: 13
        font.features: { "tnum": 1 }
    }

    AudioUi.VolumeBar {
        anchors.left: tile.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 16
        y: 38
        controller: deviceCard.controller
        node: deviceCard.node
    }

    // A tobbi eszkoz: kattintasra az lesz az alapertelmezett.
    Column {
        id: otherList

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        y: 72
        spacing: 2
        opacity: deviceCard.showOthers ? 1 : 0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 160 } }

        Rectangle {
            x: 10
            width: parent.width - 20
            height: 1
            color: Qt.rgba(1, 1, 1, 0.06)
        }

        Repeater {
            model: ScriptModel { values: deviceCard.others }

            SharedUi.ListRow {
                required property var modelData

                width: otherList.width
                height: 44
                theme: deviceCard.theme
                glyph: deviceCard.controller ? deviceCard.controller.deviceGlyph(modelData, deviceCard.input) : ""
                title: deviceCard.controller ? deviceCard.controller.nodeTitle(modelData) : ""
                trailing: qsTr("Use")
                accessibleName: qsTr("Use %1").arg(title)
                onClicked: {
                    if (!deviceCard.controller) return
                    if (deviceCard.input) deviceCard.controller.setDefaultInput(modelData)
                    else deviceCard.controller.setDefaultOutput(modelData)
                }
            }
        }
    }
}

import "." as AudioUi
import QtQuick
import "../../ui" as SharedUi

// Egy alapertelmezett eszkoz sora (kimenet vagy bemenet). Balra a csempe: mint
// a panel minden soraban, kattintasra nemit. Mellette az eszkoz neve egy lefele
// nyillal -- erre kattintva nyilik a valaszto. A bemenetnel jobbra a sajat
// csuszka ul; a kimenet csuszkaja kulon, teljes szelessegben van alatta.
Item {
    id: deviceRow

    property var controller: null
    property var node: null
    property bool input: false
    property bool pickerOpen: false
    property bool canPick: false
    property string subtitle: ""
    property color subtitleColor: mutedColor
    property bool showSlider: false

    readonly property var theme: controller ? controller.theme : null
    readonly property bool muted: node && node.audio ? node.audio.muted : false
    readonly property color fg: controller ? controller.panelFg : "#e8ddc7"
    readonly property color mutedColor: controller ? controller.mutedFg : "#958b7a"
    readonly property color accent: controller ? controller.panelAccent : "#b7372f"
    readonly property string title: controller ? controller.nodeTitle(node) : ""

    signal pickerToggled()

    implicitHeight: 44

    // Gorgetes a sor barmely pontjan a hangerot allitja.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            if (deviceRow.controller) deviceRow.controller.wheelVolume(deviceRow.node, wheel)
        }
    }

    Rectangle {
        id: tile

        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: 32
        radius: 8
        color: deviceRow.muted
            ? (tileMouse.containsMouse ? Qt.lighter(controller ? controller.inkBg : "#191b16", 1.25) : (controller ? controller.inkBg : "#191b16"))
            : Qt.rgba(deviceRow.accent.r, deviceRow.accent.g, deviceRow.accent.b, tileMouse.containsMouse ? 0.24 : 0.16)
        Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            text: deviceRow.input
                ? (deviceRow.muted ? "󰍭" : (deviceRow.controller ? deviceRow.controller.deviceGlyph(deviceRow.node, true) : "󰍬"))
                : (deviceRow.muted ? "󰖁" : (deviceRow.controller ? deviceRow.controller.deviceGlyph(deviceRow.node, false) : "󰕾"))
            color: deviceRow.muted ? deviceRow.mutedColor : deviceRow.accent
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 16
        }

        SharedUi.Pressable {
            id: tileMouse

            anchors.fill: parent
            theme: deviceRow.theme
            focusRadius: tile.radius
            accessibleName: (deviceRow.muted ? qsTr("Unmute %1") : qsTr("Mute %1")).arg(deviceRow.title)
            onClicked: if (deviceRow.controller) deviceRow.controller.toggleMute(deviceRow.node)
        }
    }

    Column {
        id: label

        anchors.left: tile.right
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: (deviceRow.showSlider ? slider.x - 16 : deviceRow.width) - x
        spacing: 2

        // A nev es a nyil egy gomb: a valasztot nyitja, ha van mire valtani.
        Item {
            id: nameButton

            width: Math.min(parent.width, nameText.implicitWidth + (deviceRow.canPick ? chevron.width + 6 : 0))
            height: nameText.implicitHeight

            Text {
                id: nameText

                width: Math.min(implicitWidth, nameButton.width - (deviceRow.canPick ? chevron.width + 6 : 0))
                text: deviceRow.title
                textFormat: Text.PlainText
                color: nameMouse.containsMouse || deviceRow.pickerOpen ? deviceRow.accent : deviceRow.fg
                font.pixelSize: 13
                font.weight: Font.Medium
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: 110 } }
            }

            Text {
                id: chevron

                anchors.left: nameText.right
                anchors.leftMargin: 6
                anchors.verticalCenter: nameText.verticalCenter
                visible: deviceRow.canPick
                text: "󰅀"
                color: nameText.color
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 12
                rotation: deviceRow.pickerOpen ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }

            // A latszo felirat kicsi; a kattinthato terulet a teljes sormagassag.
            SharedUi.Pressable {
                id: nameMouse

                anchors.fill: parent
                anchors.topMargin: -8
                anchors.bottomMargin: deviceRow.subtitle !== "" ? -2 : -8
                anchors.leftMargin: -4
                anchors.rightMargin: -4
                enabled: deviceRow.canPick
                theme: deviceRow.theme
                focusRadius: 4
                accessibleName: deviceRow.input ? qsTr("Choose input device") : qsTr("Choose output device")
                accessibleDescription: deviceRow.title
                onClicked: deviceRow.pickerToggled()
            }
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: deviceRow.subtitle
            textFormat: Text.PlainText
            color: deviceRow.subtitleColor
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }

    AudioUi.VolumeBar {
        id: slider

        anchors.right: percentText.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 88
        visible: deviceRow.showSlider
        controller: deviceRow.controller
        node: deviceRow.node
        accessibleName: deviceRow.input ? qsTr("Input volume") : qsTr("Volume")
    }

    Text {
        id: percentText

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: deviceRow.showSlider ? 32 : 0
        horizontalAlignment: Text.AlignRight
        visible: deviceRow.showSlider
        text: deviceRow.muted ? qsTr("Off") : (deviceRow.controller ? deviceRow.controller.percent(deviceRow.node) : 0) + "%"
        color: deviceRow.mutedColor
        font.pixelSize: 11
        font.features: { "tnum": 1 }
    }
}

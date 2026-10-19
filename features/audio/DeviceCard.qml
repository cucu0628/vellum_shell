import "." as AudioUi
import QtQuick
import "../../ui" as SharedUi

// Az alapertelmezett kimenet vagy bemenet. Felul: nemitas, nev, szazalek es
// (ha van masik eszkoz) valto gomb; alatta a csuszka. A valto a kartyan belul
// nyitja le a tobbi eszkozt, kulon sor nelkul.
Rectangle {
    id: deviceCard

    property var controller: null
    property var node: null
    property bool input: false
    property bool active: false
    property var others: []
    property bool expanded: false

    readonly property bool muted: node && node.audio && node.audio.muted
    readonly property string fg: controller ? controller.panelFg : "#f1e7d0"
    readonly property string muted_: controller ? controller.mutedFg : "#9f8f7c"
    readonly property string accent: controller ? controller.panelAccent : "#d7472f"

    signal toggleExpanded()

    height: 74 + (expanded && others.length > 0 ? otherList.height + 6 : 0)
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
        id: muteButton

        x: 12
        y: 12
        width: 32
        height: 32
        radius: 8
        color: muteMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

        Text {
            anchors.centerIn: parent
            text: deviceCard.input
                ? (deviceCard.muted ? "󰍭" : "󰍬")
                : (deviceCard.muted ? "󰖁" : "󰕾")
            color: deviceCard.muted ? deviceCard.muted_ : deviceCard.accent
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 16
        }

        SharedUi.Pressable {
            id: muteMouse
            anchors.fill: parent
            accessibleName: deviceCard.muted ? qsTr("Unmute") : qsTr("Mute")
            onClicked: if (deviceCard.controller) deviceCard.controller.toggleMute(deviceCard.node)
        }
    }

    Column {
        anchors.left: muteButton.right
        anchors.leftMargin: 10
        anchors.right: percentText.left
        anchors.rightMargin: 10
        anchors.verticalCenter: muteButton.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: deviceCard.controller ? deviceCard.controller.nodeTitle(deviceCard.node) : ""
            textFormat: Text.PlainText
            color: deviceCard.fg
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: deviceCard.muted ? qsTr("Muted") : (deviceCard.input ? qsTr("Default input") : qsTr("Default output"))
            color: deviceCard.muted_
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }

    Text {
        id: percentText

        anchors.right: switchButton.visible ? switchButton.left : parent.right
        anchors.rightMargin: switchButton.visible ? 4 : 14
        anchors.verticalCenter: muteButton.verticalCenter
        text: (deviceCard.controller ? deviceCard.controller.percent(deviceCard.node) : 0) + "%"
        color: deviceCard.fg
        font.pixelSize: 12
        font.features: { "tnum": 1 }
    }

    // Masik eszkozre valtas: a lista a kartyan belul nyilik le.
    Rectangle {
        id: switchButton

        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: muteButton.verticalCenter
        width: switchRow.implicitWidth + 16
        height: 28
        radius: 6
        visible: deviceCard.others.length > 0
        color: switchMouse.containsMouse || deviceCard.expanded ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

        Row {
            id: switchRow

            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: deviceCard.others.length
                color: deviceCard.muted_
                font.pixelSize: 10
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰅀"
                color: deviceCard.expanded ? deviceCard.fg : deviceCard.muted_
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 13
                rotation: deviceCard.expanded ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 160 } }
            }
        }

        SharedUi.Pressable {
            id: switchMouse
            anchors.fill: parent
            accessibleName: deviceCard.input ? qsTr("Choose input device") : qsTr("Choose output device")
            onClicked: deviceCard.toggleExpanded()
        }
    }

    AudioUi.VolumeBar {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 54
        anchors.rightMargin: 16
        y: 50
        controller: deviceCard.controller
        node: deviceCard.node
    }

    // A tobbi eszkoz: kattintasra az lesz az alapertelmezett.
    Column {
        id: otherList

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        y: 74
        spacing: 2
        opacity: deviceCard.expanded ? 1 : 0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 160 } }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(1, 1, 1, 0.06)
        }

        Repeater {
            model: deviceCard.others

            Rectangle {
                id: option

                required property var modelData

                width: otherList.width
                height: 36
                radius: 6
                color: optionMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: useText.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: deviceCard.controller ? deviceCard.controller.nodeTitle(option.modelData) : ""
                    textFormat: Text.PlainText
                    color: deviceCard.fg
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Text {
                    id: useText

                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Use")
                    color: optionMouse.containsMouse ? deviceCard.accent : deviceCard.muted_
                    font.pixelSize: 11
                }

                MouseArea {
                    id: optionMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!deviceCard.controller) return
                        if (deviceCard.input) deviceCard.controller.setDefaultInput(option.modelData)
                        else deviceCard.controller.setDefaultOutput(option.modelData)
                    }
                }
            }
        }
    }
}

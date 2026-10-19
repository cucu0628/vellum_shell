import QtQuick
import Quickshell.Widgets

// Egy vagolap-bejegyzes: elonezet (kep vagy szoveg-ikon), a tartalom eleje,
// alatta tipus / meret / mikor. A rogzitett elem jobb oldalt tut kap.
Rectangle {
    id: resultRow

    property var entry: null
    property var controller: null
    property int resultIndex: 0
    property bool selected: false
    property color panelBg: "#15110f"
    property color panelFg: "#f1e7d0"
    property color panelAccent: "#d7472f"
    property color mutedFg: "#9f8f7c"
    property color inkBg: "#1b1613"

    readonly property bool isImage: entry !== null && entry.isImage === true
    readonly property bool pinned: entry !== null && entry.pinned === true

    signal hovered(int index)
    signal activated(int index)

    height: 48
    radius: 8
    color: selected || resultMouse.containsMouse ? inkBg : "transparent"

    Behavior on color { ColorAnimation { duration: 110 } }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 12
        spacing: 12

        ClippingRectangle {
            width: resultRow.isImage ? 44 : 32
            height: resultRow.isImage ? 34 : 32
            radius: 6
            color: Qt.rgba(resultRow.mutedFg.r, resultRow.mutedFg.g, resultRow.mutedFg.b, 0.1)
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: thumb

                anchors.fill: parent
                source: resultRow.controller ? resultRow.controller.previewSource(resultRow.entry) : ""
                sourceSize: Qt.size(88, 68)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: source !== "" && status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: !thumb.visible
                text: resultRow.isImage ? "󰋩" : "󰅍"
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 15
                color: resultRow.mutedFg
            }
        }

        Column {
            width: parent.width - x - trailing.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: resultRow.entry ? resultRow.entry.title : ""
                textFormat: Text.PlainText
                color: resultRow.panelFg
                font.pixelSize: 13
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                width: parent.width
                text: resultRow.controller ? resultRow.controller.describe(resultRow.entry) : ""
                textFormat: Text.PlainText
                color: resultRow.mutedFg
                font.pixelSize: 10
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        Item {
            id: trailing

            width: 64
            height: parent.height

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: resultRow.selected
                text: qsTr("Paste ↵")
                color: resultRow.panelAccent
                font.pixelSize: 11
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !resultRow.selected && resultRow.pinned
                text: "󰐃"
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 13
                color: resultRow.mutedFg
            }
        }
    }

    MouseArea {
        id: resultMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: resultRow.hovered(resultRow.resultIndex)
        onClicked: resultRow.activated(resultRow.resultIndex)
    }
}

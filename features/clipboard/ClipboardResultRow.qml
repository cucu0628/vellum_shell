import QtQuick

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

    signal hovered(int index)
    signal activated(int index)

    function requestPreview() {
        if (controller && entry && entry.isImage) controller.ensurePreview(entry)
    }

    height: 58
    radius: 0
    color: selected || resultMouse.containsMouse ? inkBg : "transparent"
    border.color: "transparent"
    border.width: 0
    onEntryChanged: requestPreview()
    Component.onCompleted: requestPreview()

    Rectangle {
        width: 2
        height: parent.height
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        radius: 0
        color: resultRow.panelAccent
        opacity: resultRow.selected ? 1 : 0
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        Rectangle {
            width: resultRow.entry && resultRow.entry.isImage ? 52 : 28
            height: resultRow.entry && resultRow.entry.isImage ? 44 : 28
            radius: 0
            color: resultRow.panelBg
            border.color: resultRow.entry && resultRow.entry.isImage ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
            border.width: resultRow.entry && resultRow.entry.isImage ? 1 : 0
            anchors.verticalCenter: parent.verticalCenter
            clip: true

            Image {
                id: entryThumbImage

                anchors.fill: parent
                anchors.margins: 2
                source: resultRow.controller ? resultRow.controller.previewSource(resultRow.entry) : ""
                sourceSize: Qt.size(136, 112)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                cache: false
                visible: source !== "" && status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                text: resultRow.entry && resultRow.entry.isImage ? "" : ""
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 17
                color: resultRow.panelAccent
                visible: !resultRow.entry || !resultRow.entry.isImage || entryThumbImage.status !== Image.Ready
            }

        }

        Column {
            width: parent.width - 100 - (resultRow.entry && resultRow.entry.isImage ? 52 : 28)
            spacing: 3
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: resultRow.entry ? (resultRow.entry.isImage ? resultRow.entry.subtitle : resultRow.entry.title) : ""
                color: resultRow.selected ? resultRow.panelAccent : resultRow.panelFg
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: resultRow.entry && resultRow.entry.isImage ? 1 : 2
                width: parent.width
                wrapMode: Text.WordWrap
            }

            Text {
                text: resultRow.entry && resultRow.controller
                    ? resultRow.controller.entryTypeLabel(resultRow.entry) + "  ·  CLIPBOARD HISTORY"
                    : ""
                color: resultRow.mutedFg
                font.family: "monospace"
                font.pixelSize: 8
                font.letterSpacing: 1
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
                width: parent.width
            }

        }

        Text {
            width: 72
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: resultRow.selected
                ? "PASTE  ↵"
                : (resultRow.entry && resultRow.controller ? resultRow.controller.entryTypeLabel(resultRow.entry) : "")
            color: resultRow.selected ? resultRow.panelAccent : resultRow.mutedFg
            font.family: "monospace"
            font.pixelSize: 8
            font.letterSpacing: resultRow.selected ? 0 : 1.1
            opacity: resultRow.selected ? 1 : 0.65
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

    Behavior on color {
        ColorAnimation {
            duration: 110
        }

    }

}

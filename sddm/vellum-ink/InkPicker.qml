import QtQuick

// Valaszto mezo (felhasznalo / munkamenet) a kartyan belul. A legordulo listat
// az InkCard rajzolja fololtetkent, hogy az egerkattintas ne akadjon el a
// szuloi hataron.
Item {
    id: picker

    required property var greeter
    property string pickerId: ""
    property string label: ""
    property var entries: []
    property int currentIndex: 0

    readonly property bool open: greeter.openPicker === pickerId
    readonly property bool selectable: entries.length > 1
    readonly property string currentLabel: (currentIndex >= 0 && currentIndex < entries.length)
        ? entries[currentIndex].label
        : "—"
    readonly property color edgeColor: picker.open ? greeter.accent : greeter.outline

    implicitHeight: 42

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.22)
        border.color: picker.edgeColor
        border.width: picker.open ? 2 : 1

        Behavior on border.color { ColorAnimation { duration: 140 } }
        Behavior on border.width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        color: picker.greeter.accent
        opacity: picker.open ? 0.1 : (mouse.containsMouse && picker.selectable ? 0.06 : 0)

        Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    Rectangle {
        width: 2
        height: parent.height
        anchors.left: parent.left
        color: picker.edgeColor
        opacity: picker.open ? 1 : 0.5

        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 13
        anchors.right: chevron.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            text: picker.label
            color: picker.greeter.muted
            font.pixelSize: 8
            font.letterSpacing: 1.6
        }

        Text {
            width: parent.width
            text: picker.currentLabel
            color: picker.greeter.foreground
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    Text {
        id: chevron

        text: "▾"
        visible: picker.selectable
        color: picker.open ? picker.greeter.accent : picker.greeter.muted
        font.pixelSize: 9
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        rotation: picker.open ? 180 : 0

        Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        enabled: picker.selectable
        cursorShape: Qt.PointingHandCursor
        onClicked: picker.greeter.openPicker = picker.open ? "" : picker.pickerId
    }
}

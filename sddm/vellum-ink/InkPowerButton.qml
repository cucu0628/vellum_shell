import QtQuick

// Rendszermuvelet-gomb a kartya alatti savon. A shell `ui/ActionButton`-jenek
// nyelve: eles keret, akcentes kiemeles egerrel.
Item {
    id: button

    required property var greeter
    property string glyph: ""
    property string label: ""
    property bool danger: false

    signal activated()

    readonly property color markColor: danger ? greeter.alertColor : greeter.accent
    readonly property bool lit: mouse.containsMouse && button.enabled

    implicitWidth: Math.max(46, labelText.implicitWidth + 22)
    implicitHeight: 44
    opacity: enabled ? 1 : 0.3

    Rectangle {
        anchors.fill: parent
        color: button.lit ? Qt.rgba(button.markColor.r, button.markColor.g, button.markColor.b, 0.1) : "transparent"
        border.color: button.lit ? button.markColor : Qt.rgba(1, 1, 1, 0.1)
        border.width: 1

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    Column {
        anchors.centerIn: parent
        spacing: 3

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: button.glyph
            visible: button.glyph !== ""
            color: button.lit ? button.markColor : button.greeter.foreground
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 13

            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
            id: labelText

            anchors.horizontalCenter: parent.horizontalCenter
            text: button.label
            color: button.lit ? button.markColor : button.greeter.muted
            font.pixelSize: 8
            font.letterSpacing: 1.6

            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        enabled: button.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: button.activated()
    }
}

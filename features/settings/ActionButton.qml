import QtQuick

// Egy gomb, amit a beallitasoldalak hasznalnak (kulso eszkoz inditasa,
// visszaallitas). A shell nem hasznal QtQuick.Controls-t, ezert sajat.
Rectangle {
    id: button

    property var theme: null
    property string label: ""
    property bool primary: false

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string background: theme ? theme.background : "#11130f"

    signal clicked()

    implicitWidth: Math.max(96, labelText.implicitWidth + 28)
    implicitHeight: 30
    color: button.primary ? button.accent : (buttonMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
    border.color: button.primary ? button.accent : button.muted
    border.width: 1

    Text {
        id: labelText

        anchors.centerIn: parent
        text: button.label
        color: button.primary ? button.background : button.foreground
        font.pixelSize: 12
        font.bold: button.primary
    }

    MouseArea {
        id: buttonMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }

    Behavior on color {
        ColorAnimation {
            duration: 110
        }

    }

}

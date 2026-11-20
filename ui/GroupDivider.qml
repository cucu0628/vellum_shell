import QtQuick

// Hajszalvonal a lenyilo panelek csoportjai kozott, 12 px levegovel mindket
// oldalan. Kartyak es szakaszcimkek helyett ez valasztja el a reszeket.
Item {
    id: divider

    property var theme: null

    readonly property color foreground: theme ? theme.foreground : "#e8ddc7"

    implicitHeight: 25

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 1
        color: Qt.rgba(divider.foreground.r, divider.foreground.g, divider.foreground.b, 0.08)
    }
}

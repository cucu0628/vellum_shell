import QtQuick

// A zarolokepernyo oraja nyomdai szedesben: felul a het napja kurzivan,
// akcentessel, alatta nagy serif ora, majd a teljes datum. Balra zart blokk,
// a nezetek a bal also sarokba teszik.
Column {
    id: clock

    required property var lockRoot
    property int timeSize: 160

    spacing: 0

    Text {
        text: Qt.formatDate(clock.lockRoot.currentTime, "dddd")
        color: clock.lockRoot.accent
        font.family: "serif"
        font.italic: true
        font.pixelSize: 26
        leftPadding: 4
    }

    Text {
        text: clock.lockRoot.timeText
        color: clock.lockRoot.foreground
        font.family: "serif"
        font.pixelSize: clock.timeSize
        lineHeight: 0.92
    }

    Text {
        text: Qt.formatDate(clock.lockRoot.currentTime, "MMMM d, yyyy")
        color: clock.lockRoot.muted
        font.pixelSize: 15
        leftPadding: 6
    }
}

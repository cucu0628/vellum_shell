import QtQuick

// Szakaszcim egy beallitasoldalon belul.
Item {
    id: section

    property var theme: null
    property string title: ""

    readonly property string accent: theme ? theme.accent : "#b7372f"

    height: 44

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        text: section.title.toUpperCase()
        color: section.accent
        font.pixelSize: 9
        font.bold: true
        font.letterSpacing: 2
    }

}

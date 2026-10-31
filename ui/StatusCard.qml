import QtQuick

// Allapotkartya a lenyilo panelek tetejen: mi van most (halozat, VPN,
// Bluetooth-eszkoz). Csempe a jellel, cim, egy metaadat-sor; jobbra
// opcionalis elo ertek (pl. atviteli sebesseg). Ugyanaz a kerekitett,
// keret nelkuli felulet, mint a dashboard kartyain.
Rectangle {
    id: card

    property var theme: null
    property string glyph: ""
    property string title: ""
    property string subtitle: ""
    // Az akcentes csempe jelzi, hogy van elo kapcsolat.
    property bool active: false
    property int trailingWidth: 0
    default property alias trailing: trailingSlot.data

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string surface: theme && theme.surface ? theme.surface : "#191b16"
    readonly property color accentColor: accent

    implicitHeight: 72
    radius: 10
    color: card.surface

    Rectangle {
        id: tile

        x: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        height: 44
        radius: 10
        color: card.active ? Qt.rgba(card.accentColor.r, card.accentColor.g, card.accentColor.b, 0.16) : Qt.rgba(1, 1, 1, 0.04)
        Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            text: card.glyph
            color: card.active ? card.accent : card.muted
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 20
        }
    }

    Column {
        anchors.left: tile.right
        anchors.leftMargin: 12
        anchors.right: trailingSlot.left
        anchors.rightMargin: card.trailingWidth > 0 ? 12 : 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Text {
            width: parent.width
            text: card.title
            textFormat: Text.PlainText
            color: card.foreground
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: card.subtitle
            textFormat: Text.PlainText
            color: card.muted
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    Item {
        id: trailingSlot

        anchors.right: parent.right
        anchors.rightMargin: card.trailingWidth > 0 ? 16 : 0
        anchors.verticalCenter: parent.verticalCenter
        width: card.trailingWidth
        height: parent.height - 24
    }
}

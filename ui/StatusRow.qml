import QtQuick

// A lenyilo panelek allapotsora: mi van most (halozat, VPN). Kartya nelkul,
// kozvetlenul a panel hatteren: csempe a jellel (akcentes, ha van elo
// kapcsolat), cim, egy metaadat-sor, jobbra opcionalis tartalom. Ugyanaz a
// forma, mint a hangpanel eszkozsora, igy a panelek egy nyelvet beszelnek.
Item {
    id: row

    property var theme: null
    property string glyph: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property int trailingWidth: 0
    default property alias trailing: trailingSlot.data

    readonly property color foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property color accent: theme ? theme.accent : "#b7372f"
    readonly property color muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property color surface: theme && theme.surface ? theme.surface : "#191b16"

    implicitHeight: 44

    Rectangle {
        id: tile

        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: 32
        radius: 8
        color: row.active ? Qt.rgba(row.accent.r, row.accent.g, row.accent.b, 0.16) : row.surface
        Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            text: row.glyph
            color: row.active ? row.accent : row.muted
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 16
        }
    }

    Column {
        anchors.left: tile.right
        anchors.leftMargin: 12
        anchors.right: trailingSlot.left
        anchors.rightMargin: row.trailingWidth > 0 ? 12 : 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: row.title
            textFormat: Text.PlainText
            color: row.foreground
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: row.subtitle
            textFormat: Text.PlainText
            color: row.muted
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }

    Item {
        id: trailingSlot

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: row.trailingWidth
        height: parent.height
    }
}

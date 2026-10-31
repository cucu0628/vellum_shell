import QtQuick

// Egy sor a lenyilo panelek listaiban (Wi-Fi halozat, Bluetooth eszkoz, VPN
// orszag, cserelheto meghajto): jel egy kis csempen, cim, alatta egy
// metaadat-sor, jobbra a muvelet. Az aktiv elem halvany akcentes alapot es
// akcentes csempet kap -- oldalcsik es keret nelkul.
Rectangle {
    id: row

    property var theme: null
    property string glyph: ""
    // A jel betukeszlete; orszagkodhoz pl. monospace.
    property string glyphFamily: "Symbols Nerd Font Mono"
    property int glyphSize: 16
    property string title: ""
    property string subtitle: ""
    property int subtitleElide: Text.ElideRight
    // Jobb oldali csendes muvelet felirata (Connect, Disconnect). Hoverre,
    // fokuszra vagy aktiv/kivalasztott sornal latszik.
    property string trailing: ""
    // Csatlakozott / hasznalatban levo elem.
    property bool active: false
    // Kivalasztott, de meg nem aktiv elem (pl. jelszora var).
    property bool selected: false
    // false: a sor maga nem kattinthato, csak a sajat gombjai.
    property bool interactive: true
    property int acceptedButtons: Qt.LeftButton
    property string accessibleName: title
    // Sajat gombok a sor jobb szelen (pl. Mount / Eject).
    default property alias actions: actionRow.data

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string surface: theme && theme.surface ? theme.surface : "#191b16"
    readonly property color accentColor: accent
    readonly property bool hovered: row.interactive && pressable.containsMouse
    readonly property bool emphasized: row.hovered || row.active || row.selected || pressable.activeFocus

    signal clicked(var event)

    implicitHeight: 52
    radius: 8
    color: row.active
        ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, row.hovered ? 0.14 : 0.09)
        : (row.hovered || row.selected ? Qt.rgba(1, 1, 1, row.hovered && row.selected ? 0.08 : 0.05) : "transparent")
    Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }

    // A sor alatt: a jobb szeli sajat gombok elsobbseget kapnak.
    Pressable {
        id: pressable

        anchors.fill: parent
        enabled: row.interactive
        theme: row.theme
        focusRadius: row.radius
        acceptedButtons: row.acceptedButtons
        accessibleName: row.accessibleName
        onClicked: (event) => row.clicked(event)
    }

    Rectangle {
        id: tile

        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: 32
        radius: 8
        color: row.active ? Qt.rgba(row.accentColor.r, row.accentColor.g, row.accentColor.b, 0.16) : row.surface
        Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            text: row.glyph
            color: row.active ? row.accent : row.foreground
            font.family: row.glyphFamily
            font.pixelSize: row.glyphSize
            font.weight: row.glyphFamily === "Symbols Nerd Font Mono" ? Font.Normal : Font.DemiBold
        }
    }

    Column {
        anchors.left: tile.right
        anchors.leftMargin: 12
        anchors.right: actionRow.left
        anchors.rightMargin: actionRow.width > 0 ? 12 : 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: row.title
            textFormat: Text.PlainText
            color: row.foreground
            font.pixelSize: 13
            font.weight: row.active ? Font.Medium : Font.Normal
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: row.subtitle
            textFormat: Text.PlainText
            color: row.muted
            font.pixelSize: 10
            elide: row.subtitleElide
        }
    }

    Row {
        id: actionRow

        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.trailing !== ""
            text: row.trailing
            color: row.hovered ? row.accent : (row.active ? row.foreground : row.muted)
            opacity: row.emphasized ? 1 : 0
            font.pixelSize: 11
            Behavior on opacity { NumberAnimation { duration: 110 } }
            Behavior on color { ColorAnimation { duration: 110 } }
        }
    }
}

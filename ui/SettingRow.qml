import QtQuick

// Egy beallitas sora: balra nev es magyarazat, jobbra a vezerlo. A vezerlot a
// hivo teszi be alapertelmezett gyerekkent, ezert a `control` a default
// property -- igy a hivo oldalon nincs plusz beagyazas.
Rectangle {
    id: row

    default property alias control: controlSlot.data
    property var theme: null
    property string label: ""
    property string description: ""
    property int controlWidth: 260

    // A sajat QML dropdown kilog a sorbol. Az egesz sort kell a testverei fole
    // emelni, kulonben a kesobbi sorok csuszkai es szovegei rarajzolodnak.
    readonly property bool controlRaised: controlSlot.children.length > 0
        && controlSlot.children[0].expanded === true

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"

    width: parent ? parent.width : 0
    height: Math.max(52, textColumn.implicitHeight + 22)
    z: controlRaised ? 1000 : 0
    color: "transparent"
    // Az `enabled` a QQuickItem-e: a gyerekekre magatol oroklodik, itt csak
    // lathatova tesszuk.
    opacity: enabled ? 1 : 0.4

    Column {
        id: textColumn

        anchors.left: parent.left
        anchors.right: controlSlot.left
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            width: parent.width
            text: row.label
            color: row.foreground
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: row.description !== ""
            text: row.description
            color: row.muted
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }

    }

    Item {
        id: controlSlot

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: row.controlWidth
        height: parent.height
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: row.muted
        opacity: 0.12
    }

}

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

    // A sor cimkeje a vezerlo neve is: enelkul a kepernyoolvaso csak annyit
    // mondana, hogy "kapcsolo", azt viszont nem, hogy mit kapcsol. A vezerlo
    // sajat `accessibleName`-je erosebb, ha a hivo kifejezetten megadta.
    function publishAccessibleName() {
        var item = controlSlot.children.length > 0 ? controlSlot.children[0] : null
        if (!item || item.accessibleName === undefined) return
        if (item.accessibleName === "" || item.accessibleName === row._publishedName) {
            item.accessibleName = row.label
            row._publishedName = row.label
        }
        if (item.accessibleDescription !== undefined
            && (item.accessibleDescription === "" || item.accessibleDescription === row._publishedDescription)) {
            item.accessibleDescription = row.description
            row._publishedDescription = row.description
        }
    }

    property string _publishedName: ""
    property string _publishedDescription: ""

    onLabelChanged: publishAccessibleName()
    onDescriptionChanged: publishAccessibleName()
    Component.onCompleted: publishAccessibleName()

    width: parent ? parent.width : 0
    height: Math.max(58, textColumn.implicitHeight + 24)
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
        spacing: 4

        Text {
            width: parent.width
            text: row.label
            color: row.foreground
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: row.description !== ""
            text: row.description
            color: row.muted
            font.pixelSize: 10
            lineHeight: 1.15
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
        opacity: 0.14
    }

}

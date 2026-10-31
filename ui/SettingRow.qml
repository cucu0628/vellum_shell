import QtQuick

// Egy beallitas sora: balra nev es egy rovid magyarazat, jobbra a vezerlo. A
// sor sajat hatteret nem rajzol: a beallitasoldalak egy kerek kartyaba
// (SettingsSection) gyujtik a sorokat, ezek kozott csak egy hajszalvonal fut.
// A magyarazat alapbol latszik; a hivo `showDescription: false`-szal csak a
// kepernyoolvasonak hagyhatja meg.
Rectangle {
    id: row

    default property alias control: controlSlot.data
    property var theme: null
    property string label: ""
    property string description: ""
    property bool showDescription: true
    property int controlWidth: 260
    // Tenyeket felsorolo, leiras nelkuli soroknal (diagnosztika) lehet kisebb,
    // de 44 px ala nem megy.
    property int minimumHeight: hasVisibleDescription ? 60 : 52
    readonly property bool hasVisibleDescription: showDescription && description !== ""

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

    // A ki/be kapcsolo sorban az egesz sor kattinthato, nem csak a kis sin.
    readonly property var primaryControl: controlSlot.children.length > 0 ? controlSlot.children[0] : null
    readonly property bool togglesOnClick: primaryControl !== null
        && primaryControl.checked !== undefined
        && typeof primaryControl.activate === "function"

    width: parent ? parent.width : 0
    height: Math.max(Math.max(44, row.minimumHeight), textColumn.implicitHeight + 24)
    z: controlRaised ? 1000 : 0
    color: "transparent"
    // Az `enabled` a QQuickItem-e: a gyerekekre magatol oroklodik, itt csak
    // lathatova tesszuk.
    opacity: enabled ? 1 : 0.45

    // Elvalaszto a kartyan beluli elozo sor felett. A kartya elso lathato
    // eleme a Column tetejen all (y = 0), az nem kap vonalat.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        visible: row.y > 0
        color: row.muted
        opacity: 0.12
    }

    MouseArea {
        anchors.fill: parent
        enabled: row.togglesOnClick
        cursorShape: row.togglesOnClick ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: row.primaryControl.activate()
    }

    Column {
        id: textColumn

        anchors.left: parent.left
        anchors.right: controlSlot.left
        anchors.rightMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: row.label
            textFormat: Text.PlainText
            color: row.foreground
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: row.hasVisibleDescription
            text: row.description
            textFormat: Text.PlainText
            color: row.muted
            font.pixelSize: 11
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

}

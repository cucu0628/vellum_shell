import QtQuick

// Egy beallitasoldal szakasza: cim, egy rovid magyarazo sor, jobbra opcionalis
// muveletek (`actions`), alatta egy kerek kartya, amibe a szakasz sorai
// kerulnek. A sorok kozti hajszalvonalat a SettingRow maga rajzolja.
//
//     SettingsSection {
//         title: "Keyboard"
//         description: "Layout and held-key response"
//         actions: [ SharedUi.ActionButton { ... } ]
//
//         SharedUi.SettingRow { ... }
//     }
//
// Gyerek nelkul csak a fejlec latszik; `flat: true` eseten a tartalom kartya
// nelkul, a szakasz teljes szelessegeben all (pl. sajat elrendezesu lista).
Item {
    id: section

    property var theme: null
    property string title: ""
    property string description: ""
    // Kompatibilitas: a leiras mostantol alapbol latszik.
    property bool showDescription: true
    property bool flat: false
    default property alias content: body.data
    property alias actions: actionRow.data

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string surface: theme && theme.surface ? theme.surface : "#191b16"
    readonly property bool hasHeader: title !== "" || actionRow.children.length > 0
    readonly property bool hasBody: body.height > 0

    width: parent ? parent.width : 0
    height: header.height + (hasBody ? (hasHeader ? 8 : 0) + card.height : 0)

    Item {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 4
        height: section.hasHeader ? Math.max(32, headerText.implicitHeight) : 0
        visible: section.hasHeader

        Column {
            id: headerText

            anchors.left: parent.left
            anchors.right: actionRow.left
            anchors.rightMargin: actionRow.width > 0 ? 16 : 0
            anchors.bottom: parent.bottom
            spacing: 2

            Text {
                width: parent.width
                text: section.title
                textFormat: Text.PlainText
                color: section.foreground
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: section.showDescription && section.description !== ""
                text: section.description
                textFormat: Text.PlainText
                color: section.muted
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }

        Row {
            id: actionRow

            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 8
        }
    }

    Rectangle {
        id: card

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: body.height + (section.flat ? 0 : 8)
        visible: section.hasBody
        radius: 12
        color: section.flat ? "transparent" : section.surface

        Column {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: section.flat ? 0 : 16
            anchors.rightMargin: section.flat ? 0 : 16
            anchors.top: parent.top
            anchors.topMargin: section.flat ? 0 : 4
            spacing: 0
        }
    }
}

import QtQuick
import "../../ui" as SharedUi

// Egy vagolap-bejegyzes a lenyilo panelek kozos soraban: kepnel kivagott
// elonezet a csempen, szovegnel jel; a tartalom eleje, alatta tipus / meret /
// mikor. A kijelolt sor jobb szelen "Paste ↵", a rogzitett elemen egy tu.
SharedUi.ListRow {
    id: resultRow

    property var entry: null
    property var controller: null
    property int resultIndex: 0
    property bool hoverSelectionEnabled: true

    readonly property bool isImage: entry !== null && entry.isImage === true
    readonly property bool pinned: entry !== null && entry.pinned === true

    signal hoverRequested(int index)
    signal activationRequested(int index)

    implicitHeight: 48
    title: entry ? entry.title : ""
    subtitle: controller ? controller.describe(entry) : ""
    glyph: isImage ? "󰋩" : "󰅍"
    iconSource: controller ? controller.previewSource(entry) : ""

    onHoveredChanged: {
        if (hovered && hoverSelectionEnabled)
            hoverRequested(resultIndex);
    }
    onClicked: activationRequested(resultIndex)

    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: resultRow.selected
        text: qsTr("Paste ↵")
        color: resultRow.muted
        font.pixelSize: 11
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: !resultRow.selected && resultRow.pinned
        text: "󰐃"
        color: resultRow.muted
        font.family: "Symbols Nerd Font Mono"
        font.pixelSize: 13
    }
}

import QtQuick
import "../../ui" as SharedUi

// Egy launcher-talalat a lenyilo panelek kozos soraban: alkalmazasnal a sajat
// ikonja, kulonben a jel egy csempen; cim es alcim. Tipuscimke nincs -- a jel
// es az alcim mar elmondja, mi ez. A kijelolt sor jobb szelen az all, mit tesz
// az Enter (Open, Run, Copy); a megerositesre varo muveletnel akcentes
// "Again", es a csempeje is akcentes lesz.
SharedUi.ListRow {
    id: resultRow

    property var result: null
    property int resultIndex: -1
    // Igaz, amig ez a sor a masodik Enterre var (kikapcsolas, ujrainditas).
    property bool pendingConfirm: false
    property bool hoverSelectionEnabled: true
    readonly property bool isApp: result !== null && result.type === "app"
    readonly property bool isEmoji: result !== null && result.type === "emoji"
    readonly property string verb: {
        if (!result) return ""
        if (result.type === "action") return qsTr("Run")
        if (result.type === "calc" || result.type === "emoji") return qsTr("Copy")
        return qsTr("Open")
    }

    signal hoverRequested(int index)
    signal activationRequested(int index)

    implicitHeight: 48
    active: pendingConfirm
    iconBare: isApp
    // Az alkalmazas tartalek-betuje es az emoji nem a Nerd Fontbol jon.
    glyphFamily: isApp || isEmoji ? "sans-serif" : "Symbols Nerd Font Mono"
    glyphSize: isEmoji ? 19 : (isApp ? 15 : 16)

    onHoveredChanged: {
        if (hovered && hoverSelectionEnabled)
            hoverRequested(resultIndex);
    }
    onClicked: activationRequested(resultIndex)

    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: resultRow.selected || resultRow.pendingConfirm
        text: resultRow.pendingConfirm ? qsTr("Again ↵") : resultRow.verb + " ↵"
        color: resultRow.pendingConfirm ? resultRow.accent : resultRow.muted
        font.pixelSize: 11
        font.weight: resultRow.pendingConfirm ? Font.DemiBold : Font.Normal
    }
}

import QtQuick

// Visszafogott keresomezo: lekerekitett, vekony keret, ami fokuszban sem
// vastagodik, csak akcentes lesz. A jel es a betumeret a torzsszoveg
// skalajan marad, igy a mezo nem nyomja el az alatta levo listat.
Rectangle {
    id: field

    property alias text: input.text
    // Jelszomezokent: TextInput.Password.
    property alias echoMode: input.echoMode
    property bool opened: false
    property string indicator: "⌕"
    property string placeholder: "Search..."
    property color foreground: "#f1e7d0"
    property color accent: "#d7472f"
    property color muted: "#9f8f7c"
    property color surface: "#1b1613"
    // true: egy lenyilo kereso fejlece (launcher, vagolap). Doboz es keret
    // nelkul ul a panel hatteren, a beirt szoveg serif cimkent jelenik meg, a
    // jel pedig egy 32 px-es csempen all -- pontosan a talalatok csempei
    // folott, igy a kereso es a lista egy oszlopot alkot. Ilyenkor az
    // `indicator` Nerd Font jel.
    property bool prominent: false
    property int inputLeftMargin: prominent ? 54 : 34
    property int inputVerticalPadding: 10
    signal textEdited(string text)
    signal keyPressed(var event)

    function forceInputFocus() {
        input.forceActiveFocus()
    }

    function forceActiveFocus() {
        input.forceActiveFocus()
    }

    function selectAll() {
        input.selectAll()
    }

    height: 40
    radius: 8
    color: prominent ? "transparent" : surface
    border.width: prominent ? 0 : 1
    border.color: input.activeFocus
        ? Qt.rgba(accent.r, accent.g, accent.b, 0.55)
        : Qt.rgba(muted.r, muted.g, muted.b, 0.22)
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Rectangle {
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        visible: field.prominent
        width: 32
        height: 32
        radius: 8
        color: input.activeFocus ? Qt.rgba(field.accent.r, field.accent.g, field.accent.b, 0.16) : field.surface
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: field.indicator
            color: input.activeFocus ? field.accent : field.muted
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 16
        }
    }

    Text {
        visible: !field.prominent
        width: field.inputLeftMargin - 12
        text: field.indicator
        color: input.activeFocus ? field.accent : field.muted
        font.pixelSize: 15
        horizontalAlignment: Text.AlignHCenter
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    TextInput {
        id: input
        anchors.left: parent.left
        anchors.leftMargin: field.inputLeftMargin
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height - field.inputVerticalPadding
        verticalAlignment: TextInput.AlignVCenter
        color: field.foreground
        selectionColor: Qt.rgba(field.accent.r, field.accent.g, field.accent.b, 0.35)
        selectedTextColor: field.foreground
        font.family: field.prominent ? "serif" : Qt.application.font.family
        font.pixelSize: field.prominent ? 18 : 13
        clip: true
        focus: field.opened
        onTextChanged: field.textEdited(text)
        Keys.onPressed: (event) => field.keyPressed(event)

        Text {
            text: field.placeholder
            color: field.muted
            visible: parent.text === ""
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            font.family: field.prominent ? "serif" : Qt.application.font.family
            font.pixelSize: field.prominent ? 18 : 13
            elide: Text.ElideRight
        }
    }
}

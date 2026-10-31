import QtQuick

// Szoveges beallitas mezo. Enterre vagy fokuszvesztesre ment, nem minden
// leutesre -- kulonben minden karakter egy fajlirast valtana ki.
Rectangle {
    id: field

    property var theme: null
    property string value: ""
    property string placeholder: ""

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string surface: theme && theme.surface ? theme.surface : "#1b1613"

    signal committed(string value)

    // Mentes utan uritheto (pl. egy "hozzaadas" mezonel).
    function clear() {
        input.text = "";
    }

    function commit() {
        if (input.text !== field.value)
            field.committed(input.text);

    }

    readonly property color accentColor: accent
    readonly property color mutedColor: muted

    implicitWidth: 240
    implicitHeight: 32
    radius: 8
    color: surface
    // Ugyanaz a vekony keret, mint a legordulon: fokuszban akcentes lesz.
    border.width: 1
    border.color: input.activeFocus
        ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.55)
        : Qt.rgba(mutedColor.r, mutedColor.g, mutedColor.b, 0.22)

    Behavior on border.color { ColorAnimation { duration: 120 } }

    // Amig a mezoben van a fokusz, a kivulrol erkezo ertek nem irja felul azt,
    // amit epp gepel a felhasznalo.
    onValueChanged: {
        if (!input.activeFocus)
            input.text = field.value;

    }

    TextInput {
        id: input

        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        verticalAlignment: TextInput.AlignVCenter
        // A hosszu ertek (pl. egy OAuth client ID) a mezon belul gorgetodik,
        // nem log ki a keretbol.
        clip: true
        color: field.foreground
        selectionColor: Qt.rgba(field.accentColor.r, field.accentColor.g, field.accentColor.b, 0.35)
        selectedTextColor: field.foreground
        font.pixelSize: 12
        text: field.value
        onEditingFinished: field.commit()
        onActiveFocusChanged: {
            if (!activeFocus)
                field.commit();

        }

        Text {
            anchors.fill: parent
            visible: input.text === ""
            verticalAlignment: Text.AlignVCenter
            text: field.placeholder
            color: field.muted
            font.pixelSize: 12
            elide: Text.ElideRight
        }

    }

}

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

    function commit() {
        if (input.text !== field.value)
            field.committed(input.text);

    }

    implicitWidth: 240
    implicitHeight: 30
    color: surface
    border.color: input.activeFocus ? accent : muted
    border.width: 1

    // Amig a mezoben van a fokusz, a kivulrol erkezo ertek nem irja felul azt,
    // amit epp gepel a felhasznalo.
    onValueChanged: {
        if (!input.activeFocus)
            input.text = field.value;

    }

    TextInput {
        id: input

        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        color: field.foreground
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
        }

    }

}

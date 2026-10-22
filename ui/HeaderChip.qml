import QtQuick

// Csendes vezerlo a popupfejlec jobb oldalara (Advanced, DND, Wi-Fi ki/be).
// Nincs kerete: bekapcsolva akcentes szoveg halvany akcentes alappal,
// kikapcsolva visszafogott szoveg, ami csak hoverre kap hatteret.
Rectangle {
    id: chip

    property var theme: null
    property string label: ""
    // Kapcsolokent: be van-e kapcsolva. Sima gombnal maradjon false.
    property bool checked: false
    property bool checkable: false
    property string accessibleName: label

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property color accentColor: accent
    readonly property color accentTint: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.14)

    signal clicked()

    implicitWidth: chipLabel.implicitWidth + 24
    implicitHeight: 28
    radius: 6
    color: chip.checked ? chip.accentTint : (pressable.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
    opacity: chip.enabled ? 1 : 0.45
    Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }

    Text {
        id: chipLabel

        anchors.centerIn: parent
        text: chip.label
        // A felirat lehet ertesitesi muvelet szovege is: sosem ertelmezzuk
        // markupkent.
        textFormat: Text.PlainText
        color: chip.checked ? chip.accent : (pressable.containsMouse ? chip.foreground : chip.muted)
        font.pixelSize: 11
        font.weight: chip.checked ? Font.Medium : Font.Normal
    }

    Pressable {
        id: pressable

        anchors.fill: parent
        theme: chip.theme
        accessibleName: chip.accessibleName
        accessibleRole: chip.checkable ? Accessible.CheckBox : Accessible.Button
        onClicked: chip.clicked()
    }
}

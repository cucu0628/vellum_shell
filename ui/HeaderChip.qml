import QtQuick

// Csendes vezerlo a popupfejlec jobb oldalara (Advanced, DND, Wi-Fi ki/be) es
// a lenyilo panelek muveleteihez. Nincs kerete: bekapcsolva akcentes szoveg
// halvany akcentes alappal, kikapcsolva visszafogott szoveg, ami csak hoverre
// kap hatteret.
Rectangle {
    id: chip

    property var theme: null
    property string label: ""
    // Kapcsolokent: be van-e kapcsolva. Sima gombnal maradjon false.
    property bool checked: false
    property bool checkable: false
    // A panel fo muvelete (Connect, Mount): allando halvany akcentes alap,
    // ugyanugy, mint a bekapcsolt allapot -- telt akcentes gomb nincs.
    property bool emphasized: false
    // Masodlagos, telt gomb a kartyak feluletszinevel (Disconnect, Cancel).
    property bool filled: false
    property string accessibleName: label

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string surface: theme && theme.surface ? theme.surface : "#191b16"
    readonly property color accentColor: accent
    readonly property color accentTint: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.14)
    readonly property color accentHover: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.22)
    readonly property bool hovered: pressable.containsMouse
    readonly property bool accented: chip.checked || chip.emphasized

    signal clicked()

    implicitWidth: chipLabel.implicitWidth + 24
    implicitHeight: 28
    radius: 6
    color: chip.accented
        ? (chip.hovered ? chip.accentHover : chip.accentTint)
        : (chip.filled
            ? (chip.hovered ? Qt.lighter(chip.surface, 1.18) : chip.surface)
            : (chip.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent"))
    opacity: chip.enabled ? 1 : 0.45
    Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }

    Text {
        id: chipLabel

        anchors.centerIn: parent
        width: Math.min(implicitWidth, chip.width - 16)
        text: chip.label
        // A felirat lehet ertesitesi muvelet szovege is: sosem ertelmezzuk
        // markupkent.
        textFormat: Text.PlainText
        color: chip.accented ? chip.accent : (chip.hovered || chip.filled ? chip.foreground : chip.muted)
        font.pixelSize: 11
        font.weight: chip.accented ? Font.Medium : Font.Normal
        elide: Text.ElideRight
    }

    Pressable {
        id: pressable

        anchors.fill: parent
        theme: chip.theme
        focusRadius: chip.radius
        accessibleName: chip.accessibleName
        accessibleRole: chip.checkable ? Accessible.CheckBox : Accessible.Button
        onClicked: chip.clicked()
    }
}

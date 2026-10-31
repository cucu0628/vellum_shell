import QtQuick

// Egy gomb, amit a beallitasoldalak es a panelek hasznalnak (kulso eszkoz
// inditasa, visszaallitas, megerosites). A shell nem hasznal
// QtQuick.Controls-t, ezert sajat -- de az akadalymentesitest es a
// billentyuzetet ugyanugy tudnia kell, mint egy rendes gombnak.
//
// A lenyilo panelek HeaderChip-jevel egy csaladban: kerek, keret nelkuli. A
// sima gomb halvany feher alapot kap, a `primary` akcentes arnyalatot es
// akcentes feliratot -- telt akcentes gomb nincs. A `destructive` a tema
// figyelmezteto szinet hasznalja (pl. visszaallitas).
Rectangle {
    id: button

    property var theme: null
    property string label: ""
    property bool primary: false
    property bool destructive: false
    // Amit a kepernyoolvaso mond. Alapertelmezesben maga a felirat.
    property string accessibleName: ""
    property string accessibleDescription: ""

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string warning: theme && theme.warning ? theme.warning : "#c9693f"
    readonly property color toneColor: destructive ? warning : accent
    readonly property bool toned: primary || destructive
    readonly property bool hovered: buttonMouse.containsMouse

    signal clicked()

    function activate() {
        if (button.enabled) button.clicked()
    }

    implicitWidth: Math.max(80, labelText.implicitWidth + 28)
    implicitHeight: 32
    radius: 8
    color: button.toned
        ? Qt.rgba(button.toneColor.r, button.toneColor.g, button.toneColor.b, button.hovered ? 0.24 : 0.15)
        : Qt.rgba(1, 1, 1, button.hovered ? 0.1 : 0.06)
    opacity: button.enabled ? 1 : 0.45
    // Nyomasra kicsit osszehuzodik, elengedve rugosan all vissza.
    scale: buttonMouse.pressed ? 0.96 : 1

    activeFocusOnTab: enabled
    Keys.onSpacePressed: (event) => { button.activate(); event.accepted = true }
    Keys.onReturnPressed: (event) => { button.activate(); event.accepted = true }
    Keys.onEnterPressed: (event) => { button.activate(); event.accepted = true }

    Accessible.role: Accessible.Button
    Accessible.name: button.accessibleName !== "" ? button.accessibleName : button.label
    Accessible.description: button.accessibleDescription
    Accessible.onPressAction: button.activate()

    Text {
        id: labelText

        anchors.centerIn: parent
        width: Math.min(implicitWidth, button.width - 16)
        text: button.label
        textFormat: Text.PlainText
        color: button.toned ? button.toneColor : button.foreground
        font.pixelSize: 12
        font.weight: button.toned ? Font.Medium : Font.Normal
        elide: Text.ElideRight
    }

    FocusRing {
        theme: button.theme
        active: button.activeFocus
        cornerRadius: button.radius
    }

    MouseArea {
        id: buttonMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.activate()
    }

    Behavior on color {
        ColorAnimation {
            duration: 120
            easing.type: Easing.OutCubic
        }

    }

    Behavior on scale {
        SpringAnimation {
            spring: 9
            damping: 0.55
            epsilon: 0.0005
        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: 140
        }

    }

}

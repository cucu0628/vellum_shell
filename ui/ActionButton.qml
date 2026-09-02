import QtQuick

// Egy gomb, amit a beallitasoldalak es a panelek hasznalnak (kulso eszkoz
// inditasa, visszaallitas, megerosites). A shell nem hasznal
// QtQuick.Controls-t, ezert sajat -- de az akadalymentesitest es a
// billentyuzetet ugyanugy tudnia kell, mint egy rendes gombnak.
Rectangle {
    id: button

    property var theme: null
    property string label: ""
    property bool primary: false
    // Amit a kepernyoolvaso mond. Alapertelmezesben maga a felirat.
    property string accessibleName: ""
    property string accessibleDescription: ""

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string background: theme ? theme.background : "#11130f"

    signal clicked()

    function activate() {
        if (button.enabled) button.clicked()
    }

    implicitWidth: Math.max(96, labelText.implicitWidth + 28)
    implicitHeight: 30
    color: button.primary ? button.accent : (buttonMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
    border.color: button.primary ? button.accent : button.muted
    border.width: 1

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
        text: button.label
        color: button.primary ? button.background : button.foreground
        font.pixelSize: 12
        font.bold: button.primary
    }

    FocusRing {
        theme: button.theme
        active: button.activeFocus
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
            duration: 110
        }

    }

}

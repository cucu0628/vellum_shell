import QtQuick
import "../../ui" as SharedUi

// A greeter rendszermuveletei (altatas, ujrainditas, leallitas) es a
// billentyuzetkiosztas valtoja. Halvany jel, ami hoverre akcentes lesz; a
// `danger` gomb hoverre a figyelmezteto szint kapja.
Item {
    id: button

    required property var lockRoot
    property string glyph: ""
    // Rovid, fix szelessegu felirat a jel mellett (pl. "HU"). Ures, ha csak jel kell.
    property string label: ""
    property string accessibleName: label
    property bool danger: false

    readonly property bool lit: pressable.containsMouse || pressable.activeFocus
    readonly property color litColor: danger ? lockRoot.alertColor : lockRoot.accent
    readonly property color foregroundColor: lockRoot.foreground

    signal activated()

    implicitWidth: label === "" ? 32 : content.implicitWidth + 20
    implicitHeight: 32
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: button.lit
            ? Qt.rgba(button.foregroundColor.r, button.foregroundColor.g, button.foregroundColor.b, 0.07)
            : "transparent"

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: button.glyph
            color: button.lit ? button.litColor : button.lockRoot.muted
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 15

            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: button.label !== ""
            text: button.label
            color: button.lit ? button.litColor : button.lockRoot.muted
            font.family: "monospace"
            font.pixelSize: 11

            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    SharedUi.Pressable {
        id: pressable

        anchors.fill: parent
        theme: button.lockRoot.theme
        enabled: button.enabled
        accessibleName: button.accessibleName
        onClicked: button.activated()
    }
}

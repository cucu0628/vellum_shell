import QtQuick
import "../../ui" as SharedUi

Item {
    id: root
    required property var theme
    property bool available: false
    // Nem `enabled`: az elfedne a QQuickItem sajat propertyjet, amitol a
    // gyerek MouseArea viselkedese a Bluetooth allapotatol fuggne.
    property bool adapterEnabled: false
    property bool connected: false
    property bool popupOpen: false
    signal clicked()

    width: 22
    height: parent.height

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: !root.available || !root.adapterEnabled ? "󰂲" : (root.connected ? "󰂱" : "󰂯")
        color: root.popupOpen ? root.theme.accent : root.theme.foreground
        opacity: root.available && root.adapterEnabled ? 1 : 0.55
        font.family: "Symbols Nerd Font Mono"
        font.pixelSize: 14
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    SharedUi.BarPill {
        theme: root.theme
        hovered: mouse.containsMouse
        active: root.popupOpen
        z: -1
    }

    SharedUi.Pressable {
        id: mouse
        anchors.fill: parent
        theme: root.theme
        accessibleName: !root.available ? qsTr("Bluetooth unavailable")
            : (root.adapterEnabled ? qsTr("Open Bluetooth settings") : qsTr("Bluetooth is off"))
        onClicked: root.clicked()
    }
}

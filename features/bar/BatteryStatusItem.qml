import QtQuick

Item {
    id: root

    required property var theme
    property bool available: false
    property int percentage: 0
    property bool charging: false

    function batteryIcon() {
        if (charging) return "󰂄"
        if (percentage >= 95) return "󰁹"
        if (percentage >= 85) return "󰂂"
        if (percentage >= 75) return "󰂁"
        if (percentage >= 65) return "󰂀"
        if (percentage >= 55) return "󰁿"
        if (percentage >= 45) return "󰁾"
        if (percentage >= 35) return "󰁽"
        if (percentage >= 25) return "󰁼"
        if (percentage >= 15) return "󰁻"
        return "󰁺"
    }

    visible: available
    width: batteryRow.implicitWidth
    height: parent.height

    Row {
        id: batteryRow

        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -1
            text: root.batteryIcon()
            color: root.charging || root.percentage <= 15 ? root.theme.accent : root.theme.foreground
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 14
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.percentage + "%"
            color: root.percentage <= 15 ? root.theme.accent : root.theme.foreground
            font.family: "monospace"
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }
    }
}

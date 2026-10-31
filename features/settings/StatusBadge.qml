import QtQuick

// Rovid allapotcimke egy sor jobb szelen (healthy, running, stopped). Kerek,
// keret nelkuli; aktiv allapotban halvany akcentes alap es akcentes szoveg.
Rectangle {
    id: badge

    property var theme: null
    property string text: ""
    property bool active: false

    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property color accentColor: accent

    implicitWidth: label.implicitWidth + 20
    implicitHeight: 22
    radius: height / 2
    color: badge.active
        ? Qt.rgba(badge.accentColor.r, badge.accentColor.g, badge.accentColor.b, 0.15)
        : Qt.rgba(1, 1, 1, 0.06)

    Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }

    Text {
        id: label

        anchors.centerIn: parent
        text: badge.text
        textFormat: Text.PlainText
        color: badge.active ? badge.accent : badge.muted
        font.pixelSize: 10
        font.weight: Font.Medium
    }
}

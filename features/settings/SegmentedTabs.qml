pragma ComponentBehavior: Bound

import QtQuick
import "../../ui" as SharedUi

// Ket-harom allasu valto egy oldal nezetei kozott (pl. Login apps / User
// services). Egy kerek sinen ul; a kivalasztott szelet halvany akcentes alapot
// es akcentes feliratot kap, ugyanugy, mint a bekapcsolt HeaderChip.
Rectangle {
    id: tabs

    property var theme: null
    // [{ "label": "...", "value": "..." }]
    property var model: []
    property string value: ""

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property color accentColor: accent

    signal activated(string value)

    implicitWidth: segments.implicitWidth + 8
    implicitHeight: 36
    radius: 10
    color: Qt.rgba(1, 1, 1, 0.05)

    Row {
        id: segments

        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: tabs.model

            Rectangle {
                id: segment

                required property var modelData
                readonly property bool current: modelData.value === tabs.value

                width: segmentLabel.implicitWidth + 28
                height: tabs.height - 8
                radius: 7
                color: segment.current
                    ? Qt.rgba(tabs.accentColor.r, tabs.accentColor.g, tabs.accentColor.b, 0.16)
                    : (segmentPress.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")

                Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Text {
                    id: segmentLabel

                    anchors.centerIn: parent
                    text: segment.modelData.label
                    color: segment.current ? tabs.accent : (segmentPress.containsMouse ? tabs.foreground : tabs.muted)
                    font.pixelSize: 12
                    font.weight: segment.current ? Font.Medium : Font.Normal
                }

                SharedUi.Pressable {
                    id: segmentPress

                    anchors.fill: parent
                    theme: tabs.theme
                    focusRadius: segment.radius
                    accessibleRole: Accessible.PageTab
                    accessibleName: segment.modelData.label
                    onClicked: if (!segment.current) tabs.activated(segment.modelData.value)
                }
            }
        }
    }
}

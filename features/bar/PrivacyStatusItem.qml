import QtQuick

// Privacy indicator: exists only while something is actually capturing. The mic
// icon means an app is linked to a capture device, the camera icon means an app
// holds the camera. Both breathe slowly so the bar shows it without shouting,
// and clicking opens the panel that names the apps behind them.
Item {
    id: root

    required property var theme
    required property int barHeight
    property bool micActive: false
    property bool cameraActive: false
    property bool popupOpen: false

    readonly property int iconWidth: 20
    readonly property int gap: 2
    readonly property bool highlighted: mouse.containsMouse || root.popupOpen
    readonly property int activeCount: (root.micActive ? 1 : 0) + (root.cameraActive ? 1 : 0)

    signal clicked()

    width: activeCount === 0 ? 0 : activeCount * iconWidth + (activeCount - 1) * gap
    height: parent.height
    visible: width > 0
    clip: true
    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 2
        color: root.theme.accent
        opacity: root.activeCount > 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.gap

        Item {
            width: root.iconWidth
            height: root.barHeight
            visible: root.micActive

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                text: "󰍬"
                color: root.theme.accent
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 14
                opacity: root.highlighted ? 1 : pulse.value
            }
        }

        Item {
            width: root.iconWidth
            height: root.barHeight
            visible: root.cameraActive

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                text: "󰄀"
                color: root.theme.accent
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 14
                opacity: root.highlighted ? 1 : pulse.value
            }
        }
    }

    // One shared breath so the two icons never drift apart, stilled while the
    // panel is open or hovered, and never running while nothing is captured.
    QtObject {
        id: pulse
        property real value: 1
    }

    SequentialAnimation {
        running: root.activeCount > 0
        loops: Animation.Infinite
        alwaysRunToEnd: true

        NumberAnimation { target: pulse; property: "value"; to: 0.45; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { target: pulse; property: "value"; to: 1; duration: 900; easing.type: Easing.InOutSine }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

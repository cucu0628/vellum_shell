import QtQuick

// Privacy indicator: exists only while something is actually capturing. The mic
// icon means an app is linked to a capture device, the camera icon means an app
// holds the camera. Clicking opens the panel that names the apps behind them.
//
// The signal here is the icon's *presence*, not its motion: the item has zero
// width while nothing captures, so it appearing at all is the event worth
// noticing. It fades in once when that happens and then holds still -- a
// looping pulse in peripheral vision keeps pulling the eye back long after the
// message has landed. The accent colour stays, because something recording you
// is not the same class of information as a bluetooth icon.
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
    // Egyetlen halk megjelenes: a szelesseg es az atlatszatlansag egyutt fut fel.
    opacity: activeCount > 0 ? 1 : 0

    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    // Ugyanaz a szabaly, mint a bar tobbi elemenel: az akcentus-csik a
    // kijelolest jelenti, nem az allapotot. Allandoan bekapcsolva egy szines
    // blokk ult a sav aljan, ami semmi ujat nem mondott az ikonhoz kepest.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 2
        color: root.theme.accent
        opacity: root.highlighted ? 1 : 0
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
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

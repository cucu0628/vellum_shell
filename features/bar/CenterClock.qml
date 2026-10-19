import QtQuick
import Quickshell.Services.Mpris
import "../../ui" as SharedUi

Item {
    id: root

    required property var theme
    property var activePlayer: null
    property bool hasMediaSource: false
    property var cavaValues: [0, 0, 0, 0, 0, 0]
    property bool popupOpen: false
    readonly property bool isPlaying: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing

    signal clicked()

    width: centerContent.implicitWidth + 22
    height: parent.height
    clip: true

    SharedUi.BarPill {
        theme: root.theme
        hovered: centerMouse.containsMouse
        active: root.popupOpen
        z: -1
    }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 3
        anchors.bottomMargin: 3
        color: "transparent"
        border.color: "transparent"
        border.width: 0
        radius: 0
    }

    Row {
        id: centerContent
        anchors.centerIn: parent
        height: parent.height
        spacing: 7

        Item {
            width: 21
            height: parent.height

            Text {
                anchors.fill: parent
                visible: !root.hasMediaSource
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                text: "󰝚"
                color: root.popupOpen ? root.theme.accent : root.theme.foreground
                font.pixelSize: 13
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            // A savok kozeprol nonek szet, nem az aljukrol: a sor ezert az elem
            // fuggoleges kozepere all, ugyanoda, ahol media nelkul a hangjegy.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                height: 16
                spacing: 1
                visible: root.hasMediaSource

                Repeater {
                    model: 6

                    Rectangle {
                        required property int index
                        readonly property real rawLevel: root.cavaValues && root.cavaValues.length > index ? root.cavaValues[index] : 0
                        // A cava 0..100 kozott ad (automatikus erzekenyseggel). Linearisan
                        // es szukebb skalan, hogy a jelzo ne jarjon folyton csucson.
                        readonly property real normalizedLevel: Math.max(0, Math.min(1, rawLevel / 100))
                        readonly property real displayLevel: root.isPlaying ? normalizedLevel : 0

                        width: 2
                        height: 3 + displayLevel * 9
                        anchors.verticalCenter: parent.verticalCenter
                        radius: width / 2
                        color: root.popupOpen ? root.theme.accent : root.theme.foreground

                        Behavior on height { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }
            }
        }

        Rectangle {
            width: 1
            height: 11
            anchors.verticalCenter: parent.verticalCenter
            color: root.theme.foreground
            opacity: 0.25
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }

        Text {
            id: clockDisplay
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            color: root.popupOpen ? root.theme.accent : root.theme.foreground
            font.pixelSize: 12
            font.letterSpacing: 1
            Behavior on color { ColorAnimation { duration: 120 } }

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: {
                    var d = new Date()
                    clockDisplay.text = Qt.formatDate(d, "dddd") + " " + Qt.formatTime(d, "HH:mm")
                }
                Component.onCompleted: triggered()
            }
        }
    }

    SharedUi.Pressable {
        id: centerMouse
        anchors.fill: parent
        theme: root.theme
        accessibleName: qsTr("Open media and calendar")
        onClicked: root.clicked()
    }
}

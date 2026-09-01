import QtQuick
import "../../ui" as SharedUi

SharedUi.DashPanel {
    id: card

    property int cpuUsage: 0
    property int ramUsage: 0
    property int diskUsage: 0

    readonly property color lineBg: Qt.rgba(1, 1, 1, 0.055)

    title: "SYSTEM"
    kanji: ""
    trailing: "LIVE"
    editorial: true

    Row {
        anchors.fill: parent
        spacing: 10

        Repeater {
            model: 3

            Item {
                id: stat

                readonly property string label: ["CPU", "RAM", "DISK"][index]
                readonly property real targetValue: [card.cpuUsage, card.ramUsage, card.diskUsage][index]
                property real displayedValue: 0

                function animateToTarget() {
                    valueAnimation.stop()
                    valueAnimation.to = targetValue
                    valueAnimation.restart()
                }

                width: (parent.width - 20) / 3
                height: parent.height
                onTargetValueChanged: animateToTarget()
                Component.onCompleted: Qt.callLater(animateToTarget)

                NumberAnimation {
                    id: valueAnimation

                    target: stat
                    property: "displayedValue"
                    duration: 560
                    easing.type: Easing.OutQuart
                }

                Text {
                    id: valueText
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Math.round(stat.displayedValue) + "%"
                    color: card.foreground
                    font.pixelSize: 18
                    font.weight: Font.Light
                }

                Text {
                    id: labelText
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: stat.label
                    color: card.muted
                    font.pixelSize: 9
                    font.letterSpacing: 2
                }

                Rectangle {
                    id: meterTrack
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: valueText.bottom
                    anchors.bottom: labelText.top
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    color: card.background
                    border.color: card.lineBg
                    border.width: 1
                    clip: true

                    Repeater {
                        model: 3

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            y: meterTrack.height * (index + 1) / 4
                            height: 1
                            color: card.lineBg
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 1
                        height: Math.max(0, (meterTrack.height - 2) * Math.max(0, Math.min(100, stat.displayedValue)) / 100)
                        color: card.accent
                    }
                }
            }
        }
    }
}

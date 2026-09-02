import QtQuick

// A zarolokepernyo oraja. A shell tipografiaja: monospace szamjegyek (igy a
// blokk nem ugral percenkent), ritkitott verzalis datum, es egy hajszalvekony
// napi haladasjelzo -- ugyanaz a nyelv, mint a panelek fejlecein.
Column {
    id: clock

    required property var lockRoot
    property int timeSize: 96
    property bool centered: false
    property real barWidth: 260

    spacing: Math.round(timeSize * 0.13)

    Row {
        spacing: Math.round(clock.timeSize * 0.11)
        anchors.horizontalCenter: clock.centered ? parent.horizontalCenter : undefined

        Text {
            id: bigTime

            text: clock.lockRoot.timeText
            color: clock.lockRoot.foreground
            font.family: "monospace"
            font.pixelSize: clock.timeSize
            font.weight: Font.Light
            font.letterSpacing: -clock.timeSize * 0.03
        }

        Text {
            text: clock.lockRoot.secondsText
            color: clock.lockRoot.accent
            font.family: "monospace"
            font.pixelSize: Math.round(clock.timeSize * 0.2)
            font.weight: Font.DemiBold
            font.letterSpacing: 1
            anchors.baseline: bigTime.baseline
        }
    }

    Item {
        width: clock.barWidth
        height: 2
        anchors.horizontalCenter: clock.centered ? parent.horizontalCenter : undefined

        Rectangle {
            anchors.fill: parent
            color: clock.lockRoot.foreground
            opacity: 0.14
        }

        Rectangle {
            width: parent.width * clock.lockRoot.dayProgress
            height: parent.height
            color: clock.lockRoot.accent

            Behavior on width { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
        }
    }

    Row {
        spacing: 9
        anchors.horizontalCenter: clock.centered ? parent.horizontalCenter : undefined

        Text {
            text: clock.lockRoot.weekdayText
            color: clock.lockRoot.accent
            font.pixelSize: 10
            font.letterSpacing: 3
            font.bold: true
        }

        Text {
            text: "·"
            color: clock.lockRoot.muted
            font.pixelSize: 10
            opacity: 0.6
        }

        Text {
            text: clock.lockRoot.dateText
            color: clock.lockRoot.muted
            font.pixelSize: 10
            font.letterSpacing: 2
        }
    }
}

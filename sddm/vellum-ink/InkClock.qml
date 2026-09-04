import QtQuick

// A greeter oraja. Ugyanaz a tipografia, mint a zarolokepernyon: monospace
// szamjegyek (a blokk nem ugral percenkent), hajszalvekony napi haladasjelzo
// es ritkitott verzalis datum.
Column {
    id: clock

    required property var greeter
    property int timeSize: 96
    property bool centered: false
    property real barWidth: 260

    spacing: Math.round(timeSize * 0.13)

    Row {
        spacing: Math.round(clock.timeSize * 0.11)
        anchors.horizontalCenter: clock.centered ? parent.horizontalCenter : undefined

        Text {
            id: bigTime

            text: clock.greeter.timeText
            color: clock.greeter.foreground
            font.family: "monospace"
            font.pixelSize: clock.timeSize
            font.weight: Font.Light
            font.letterSpacing: -clock.timeSize * 0.03
        }

        Text {
            text: clock.greeter.secondsText
            color: clock.greeter.accent
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
            color: clock.greeter.foreground
            opacity: 0.14
        }

        Rectangle {
            width: parent.width * clock.greeter.dayProgress
            height: parent.height
            color: clock.greeter.accent

            Behavior on width { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
        }
    }

    Row {
        spacing: 9
        anchors.horizontalCenter: clock.centered ? parent.horizontalCenter : undefined

        Text {
            text: clock.greeter.weekdayText
            color: clock.greeter.accent
            font.pixelSize: 10
            font.letterSpacing: 3
            font.bold: true
        }

        Text {
            text: "·"
            color: clock.greeter.muted
            font.pixelSize: 10
            opacity: 0.6
        }

        Text {
            text: clock.greeter.dateText
            color: clock.greeter.muted
            font.pixelSize: 10
            font.letterSpacing: 2
        }
    }
}

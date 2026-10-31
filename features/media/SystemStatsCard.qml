import QtQuick
import "../../ui" as SharedUi

// Rendszerterheles: CPU az utolso percre visszamenoleg, RAM es lemez
// "hasznalt / osszes" alakban, alul az uptime. Csak a 80% feletti ertek kap
// figyelmezteto szint; minden mas csendes marad.
//
// A sorok fix elemek, nem egy tombmodellu Repeater delegatjai: egy tombmodell
// minden frissiteskor ujraepult volna, es a csikok nullarol animaltak volna fel.
SharedUi.DashPanel {
    id: card

    property int cpuUsage: 0
    property int ramUsage: 0
    property int diskUsage: 0
    property real ramUsedGib: -1
    property real ramTotalGib: -1
    property real diskUsedGib: -1
    property real diskTotalGib: -1
    property int uptimeSeconds: 0
    property var cpuHistory: []

    readonly property string warning: theme && theme.warning ? theme.warning : "#fab387"
    readonly property int warnAt: 80

    function amount(used, total, percent) {
        if (used < 0 || total <= 0) return percent + "%"
        var digits = total >= 100 ? 0 : 1
        return used.toFixed(digits) + " / " + total.toFixed(digits) + " GiB"
    }

    function uptimeText(seconds) {
        if (seconds <= 0) return ""
        var days = Math.floor(seconds / 86400)
        var hours = Math.floor(seconds % 86400 / 3600)
        var minutes = Math.floor(seconds % 3600 / 60)
        if (days > 0) return qsTr("Up %1d %2h").arg(days).arg(hours)
        if (hours > 0) return qsTr("Up %1h %2m").arg(hours).arg(minutes)
        return qsTr("Up %1m").arg(minutes)
    }

    // Egy sor: felirat balra, ertek jobbra, alatta csik.
    component Meter: Column {
        id: meter

        property string label: ""
        property string valueText: ""
        property real percent: 0
        property real displayed: 0
        readonly property bool high: percent >= card.warnAt

        spacing: 6
        Behavior on displayed { NumberAnimation { duration: 560; easing.type: Easing.OutQuart } }
        Component.onCompleted: displayed = Qt.binding(() => meter.percent)

        Item {
            width: parent.width
            height: 14

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: meter.label
                color: card.muted
                font.pixelSize: 10
                font.letterSpacing: 1
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: meter.valueText
                color: meter.high ? card.warning : card.foreground
                font.pixelSize: 11
                font.features: { "tnum": 1 }
            }
        }

        Rectangle {
            width: parent.width
            height: 4
            radius: 2
            color: Qt.rgba(1, 1, 1, 0.07)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, meter.displayed)) / 100
                height: parent.height
                radius: 2
                color: meter.high ? card.warning : card.accent
            }
        }
    }

    title: "SYSTEM"
    trailing: uptimeText(uptimeSeconds)

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 14

        Column {
            width: parent.width
            spacing: 6

            Item {
                width: parent.width
                height: 14

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CPU"
                    color: card.muted
                    font.pixelSize: 10
                    font.letterSpacing: 1
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.cpuUsage + "%"
                    color: card.cpuUsage >= card.warnAt ? card.warning : card.foreground
                    font.pixelSize: 11
                    font.features: { "tnum": 1 }
                }
            }

            // Az utolso perc. A skala legalabb 25%-ig er, kulonben egy ures
            // gepen a zaj is csucsnak latszana; a felso ertek a sarokban all.
            Item {
                id: chart

                readonly property int ceiling: {
                    var peak = 0
                    for (var i = 0; i < card.cpuHistory.length; i++) peak = Math.max(peak, card.cpuHistory[i])
                    return Math.min(100, Math.max(25, Math.ceil(peak / 25) * 25))
                }

                width: parent.width
                // A grafikon tolti ki, ami a ket csik utan marad: igy nincs ures
                // resz a kartya aljan. (14 + 6: CPU-sor, 2 x 14: terkoz, 2 x 24: csikok.)
                height: Math.max(48, card.bodyHeight - 20 - 28 - 48)

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.07)
                }

                Text {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    text: chart.ceiling + "%"
                    color: card.muted
                    font.pixelSize: 9
                    opacity: 0.8
                }

                Canvas {
                    id: sparkline

                    readonly property var samples: card.cpuHistory
                    readonly property color lineColor: card.accent

                    anchors.fill: parent
                    onSamplesChanged: requestPaint()
                    onLineColorChanged: requestPaint()
                    onWidthChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        var data = samples || []
                        if (data.length < 2) return

                        // Jobbra igazitva: a legujabb minta mindig a jobb szelen.
                        var slots = 60
                        var step = width / (slots - 1)
                        var start = (slots - data.length) * step
                        var bottom = height - 1
                        var y = function (value) {
                            return bottom - (bottom - 2) * Math.min(1, value / chart.ceiling)
                        }

                        ctx.beginPath()
                        ctx.moveTo(start, y(data[0]))
                        for (var i = 1; i < data.length; i++)
                            ctx.lineTo(start + i * step, y(data[i]))

                        ctx.lineWidth = 1.5
                        ctx.lineJoin = "round"
                        ctx.strokeStyle = lineColor
                        ctx.stroke()

                        ctx.lineTo(start + (data.length - 1) * step, bottom)
                        ctx.lineTo(start, bottom)
                        ctx.closePath()
                        var fill = ctx.createLinearGradient(0, 0, 0, height)
                        fill.addColorStop(0, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.28))
                        fill.addColorStop(1, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0))
                        ctx.fillStyle = fill
                        ctx.fill()
                    }
                }
            }
        }

        Meter {
            width: parent.width
            label: "RAM"
            percent: card.ramUsage
            valueText: card.amount(card.ramUsedGib, card.ramTotalGib, card.ramUsage)
        }

        Meter {
            width: parent.width
            label: "DISK"
            percent: card.diskUsage
            valueText: card.amount(card.diskUsedGib, card.diskTotalGib, card.diskUsage)
        }
    }
}

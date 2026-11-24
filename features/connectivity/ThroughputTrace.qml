import QtQuick

// A kapcsolat forgalma, ugyanabban a vastag savban, mint a hangpanel fo
// csuszkaja: a letoltes halvany akcentes "tus" terulet, a feltoltes vekony
// vonal folotte. A legujabb minta a jobb szelen, a sebesseg mellette all --
// a leolvasas ott van, ahol a gorbe vegzodik. A sav a panel nyitasatol
// telik meg, masodpercenkent egy mintaval.
Item {
    id: trace

    property var theme: null
    property var throughput: null

    readonly property color accent: theme ? theme.accent : "#b7372f"
    readonly property color muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property color foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property color surface: theme && theme.surface ? theme.surface : "#191b16"
    readonly property var downHistory: throughput ? throughput.downHistory : []
    readonly property var upHistory: throughput ? throughput.upHistory : []
    readonly property int historyLength: throughput ? throughput.historyLength : 48

    implicitHeight: 40

    Accessible.role: Accessible.StaticText
    Accessible.name: throughput
        ? qsTr("Download %1, upload %2").arg(throughput.format(throughput.downRate)).arg(throughput.format(throughput.upRate))
        : ""

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: trace.surface
    }

    Canvas {
        id: chart

        x: 0
        y: 0
        width: readout.x - 12
        height: parent.height

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        Connections {
            target: trace
            function onDownHistoryChanged() { chart.requestPaint() }
            function onAccentChanged() { chart.requestPaint() }
            function onMutedChanged() { chart.requestPaint() }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var down = trace.downHistory || []
            var up = trace.upHistory || []
            if (down.length < 2) return

            // A skala a lathato csucshoz igazodik, de legalabb 16 kB/s: uresjaratban
            // a gorbe a sav aljan marad, nem nagyitja fel a zajt.
            var peak = 16 * 1024
            for (var i = 0; i < down.length; i++) peak = Math.max(peak, down[i], up[i] || 0)
            peak *= 1.15

            var top = 6
            var bottom = height - 6
            var span = bottom - top
            var step = width / Math.max(1, trace.historyLength - 1)
            var startX = width - (down.length - 1) * step
            var yOf = (value) => bottom - span * Math.max(0, Math.min(1, value / peak))

            // A sav lekerekitett bal szele: a terulet nem log ki belole.
            ctx.save()
            ctx.beginPath()
            ctx.moveTo(8, 0)
            ctx.lineTo(width, 0)
            ctx.lineTo(width, height)
            ctx.lineTo(8, height)
            ctx.arcTo(0, height, 0, height - 8, 8)
            ctx.lineTo(0, 8)
            ctx.arcTo(0, 0, 8, 0, 8)
            ctx.closePath()
            ctx.clip()

            ctx.beginPath()
            ctx.moveTo(startX, height)
            for (var d = 0; d < down.length; d++) ctx.lineTo(startX + d * step, yOf(down[d]))
            ctx.lineTo(width, height)
            ctx.closePath()
            ctx.fillStyle = Qt.rgba(trace.accent.r, trace.accent.g, trace.accent.b, 0.22)
            ctx.fill()

            ctx.beginPath()
            for (var e = 0; e < down.length; e++) {
                if (e === 0) ctx.moveTo(startX, yOf(down[e]))
                else ctx.lineTo(startX + e * step, yOf(down[e]))
            }
            ctx.strokeStyle = Qt.rgba(trace.accent.r, trace.accent.g, trace.accent.b, 0.85)
            ctx.lineWidth = 1.5
            ctx.stroke()

            if (up.length > 1) {
                var upStart = width - (up.length - 1) * step
                ctx.beginPath()
                for (var u = 0; u < up.length; u++) {
                    if (u === 0) ctx.moveTo(upStart, yOf(up[u]))
                    else ctx.lineTo(upStart + u * step, yOf(up[u]))
                }
                ctx.strokeStyle = Qt.rgba(trace.muted.r, trace.muted.g, trace.muted.b, 0.7)
                ctx.lineWidth = 1
                ctx.stroke()
            }
            ctx.restore()
        }
    }

    // A legujabb minta jelzoje: tomor el a gorbe vegen, mint a csuszka mutatoja.
    Rectangle {
        x: chart.width - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: parent.height - 12
        radius: 1.5
        color: trace.accent
        opacity: trace.downHistory.length > 1 ? 1 : 0.35
    }

    Column {
        id: readout

        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 84
        spacing: 1

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignRight
            text: "↓ " + (trace.throughput ? trace.throughput.format(trace.throughput.downRate) : "")
            color: trace.foreground
            font.pixelSize: 11
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignRight
            text: "↑ " + (trace.throughput ? trace.throughput.format(trace.throughput.upRate) : "")
            color: trace.muted
            font.pixelSize: 10
            font.features: { "tnum": 1 }
        }
    }
}

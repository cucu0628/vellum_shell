import QtQuick
import Quickshell.Io

// Down/up rate of the active interface, sampled from /proc/net/dev once a
// second while the network tab is open. Reading the kernel counters is far
// cheaper than any nmcli or process based meter, and the first sample only
// establishes the baseline: rates appear from the second tick on.
Item {
    id: throughput

    property bool active: false
    property string device: ""
    property real downRate: 0
    property real upRate: 0
    property bool sampled: false
    property double lastRx: -1
    property double lastTx: -1
    property double lastTime: 0

    width: 0
    height: 0
    visible: false

    function reset() {
        lastRx = -1
        lastTx = -1
        lastTime = 0
        downRate = 0
        upRate = 0
        sampled = false
    }

    function format(rate) {
        if (device === "") return "---"
        if (!sampled) return "..."
        if (rate < 1024) return Math.round(rate) + " B/s"

        var kb = rate / 1024
        if (kb < 1024) return (kb < 10 ? kb.toFixed(1) : Math.round(kb)) + " kB/s"

        var mb = kb / 1024
        return (mb < 10 ? mb.toFixed(1) : Math.round(mb)) + " MB/s"
    }

    function parse(text) {
        if (!active || device === "") return

        var lines = (text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var separator = lines[i].indexOf(":")
            if (separator === -1 || lines[i].slice(0, separator).trim() !== device) continue

            var fields = lines[i].slice(separator + 1).trim().split(/\s+/)
            if (fields.length < 9) return

            var rx = Number(fields[0])
            var tx = Number(fields[8])
            var now = Date.now()
            // Counters restart with the interface, so a negative delta is a
            // reset rather than a rate.
            if (lastRx >= 0 && now > lastTime) {
                var seconds = (now - lastTime) / 1000
                downRate = Math.max(0, (rx - lastRx) / seconds)
                upRate = Math.max(0, (tx - lastTx) / seconds)
                sampled = true
            }
            lastRx = rx
            lastTx = tx
            lastTime = now
            return
        }
        // The interface went away while the panel stayed open.
        reset()
    }

    onActiveChanged: {
        reset()
        if (active) counters.reload()
    }

    onDeviceChanged: {
        reset()
        if (active) counters.reload()
    }

    FileView {
        id: counters

        path: "/proc/net/dev"
        printErrors: false
        onLoaded: throughput.parse(counters.text())
    }

    Timer {
        interval: 1000
        running: throughput.active
        repeat: true
        onTriggered: counters.reload()
    }
}

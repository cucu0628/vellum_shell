import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: store

    property var stats: ({})

    // A naplofajl minden inditasnal egy sorral no. Betolteskor, ha tul hosszu,
    // a legutobbi `keepLines` sort tartjuk meg: a pontszam 15 inditasnal mar
    // telitodik, igy ennyi bejegyzes boven eleg.
    readonly property int maxLines: 2000
    readonly property int keepLines: 1000
    readonly property string logDir: "${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
    readonly property string logFile: logDir + "/launcher-frecent.tsv"

    width: 0
    height: 0
    visible: false

    Component.onCompleted: load()

    function score(app) {
        var key = app.id || app.name
        var stat = stats[key]
        if (!stat) return 0
        return Math.min(60, (stat.count || 0) * 4) + Math.max(0, 30 - Math.floor((Date.now() / 1000 - (stat.last || 0)) / 86400))
    }

    function load() {
        statsLoader.command = ["sh", "-c", "dir=\"" + logDir + "\"; file=\"" + logFile + "\"; mkdir -p \"$dir\"; "
            + "if [ -f \"$file\" ] && [ \"$(wc -l < \"$file\")\" -gt " + maxLines + " ]; then "
            + "tail -n " + keepLines + " \"$file\" > \"$file.tmp\" && mv \"$file.tmp\" \"$file\"; fi; "
            + "awk -F '\\t' '{ c[$1]++; l[$1]=$2 } END { for (id in c) printf \"%s\\t%d\\t%s\\n\", id, c[id], l[id] }' \"$file\" 2>/dev/null"]
        statsLoader.running = true
    }

    function parse(output) {
        var parsedStats = {}
        var lines = (output || "").trim().split("\n")
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].split("\t")
            if (parts.length >= 3 && parts[0] !== "") parsedStats[parts[0]] = { count: parseInt(parts[1]) || 0, last: parseInt(parts[2]) || 0 }
        }
        stats = parsedStats
    }

    function record(id) {
        if (!id || id === "") return
        var now = Math.floor(Date.now() / 1000)
        // Uj objektum, kulonben a `stats` valtozasarol senki nem kapna jelzest.
        var nextStats = {}
        for (var key in stats) nextStats[key] = stats[key]
        var current = nextStats[id] || { count: 0, last: 0 }
        nextStats[id] = { count: current.count + 1, last: now }
        stats = nextStats
        // Levalasztott hozzafuzes: ket gyors inditas sem irja felul egymast, mint
        // egy kozos, meg futo Process ujrainditasa.
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"" + logDir + "\"; printf '%s\\t%s\\n' \"$1\" \"$2\" >> \"" + logFile + "\"",
            "sh", id, now.toString()])
    }

    Process {
        id: statsLoader
        stdout: StdioCollector { onStreamFinished: store.parse(this.text || "") }
    }
}

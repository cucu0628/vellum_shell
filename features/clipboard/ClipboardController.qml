import QtQuick

// A vagolap-elozmeny a Rust backend `clipboard` topicjabol.
//
// Korabban ez a fajl cliphistet es ket `wl-paste --watch` folyamatot inditott,
// a kep-elonezeteket pedig ImageMagickkel allitotta elo. Most a backend maga
// figyeli a vagolapot (wlr-data-control), tarolja az elozmenyt es kesziti az
// elonezetet; itt csak megjelenitesre alakitjuk a bejegyzeseket.
//
// A kifele mutatott API (entries, filterEntries, activate, remove, ...)
// valtozatlan, a panel ezekre epul. Uj: togglePin es clear.
Item {
    id: controller

    required property var backend

    readonly property var topic: backend && backend.topics.clipboard ? backend.topics.clipboard : ({})
    // A backend nem fut, vagy nincs Wayland-kapcsolata.
    readonly property bool available: topic.available === true
    readonly property int maxPinned: topic.maxPinned || 25
    // Rogzitettek elol, azon belul a backend sorrendje (legujabb elol).
    readonly property var entries: {
        var source = topic.entries || []
        var pinned = []
        var rest = []
        for (var i = 0; i < source.length; i++) {
            var item = toEntry(source[i])
            if (item.pinned) pinned.push(item)
            else rest.push(item)
        }
        return pinned.concat(rest)
    }
    readonly property int pinnedCount: {
        var count = 0
        for (var i = 0; i < entries.length; i++) if (entries[i].pinned) count++
        return count
    }
    // A relativ idok frissitesehez; percenkent lep.
    property var now: new Date()

    width: 0
    height: 0
    visible: false

    // Mindig feliratkozunk: a lista igy a panel megnyitasakor mar kesz.
    Component.onCompleted: if (backend) backend.subscribe("clipboard")
    Component.onDestruction: if (backend) backend.unsubscribe("clipboard")

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: controller.now = new Date()
    }

    function toEntry(raw) {
        var isImage = raw.kind === "image"
        var meta = isImage
            ? (raw.width > 0 ? raw.width + " × " + raw.height : "Image")
            : (raw.size >= 1024 ? formatSize(raw.size) : "")
        return {
            identifier: raw.id,
            title: isImage ? "Image" : (raw.preview || ""),
            text: isImage ? "" : (raw.preview || ""),
            subtitle: isImage ? "Image" : "Text",
            meta: meta,
            time: raw.time || 0,
            preview: raw.thumb ? "file://" + raw.thumb : "",
            isImage: isImage,
            pinned: raw.pinned === true
        }
    }

    function formatSize(bytes) {
        if (bytes >= 1048576) return (bytes / 1048576).toFixed(1) + " MB"
        return Math.round(bytes / 1024) + " KB"
    }

    function relativeTime(seconds) {
        if (!seconds) return ""
        var diff = Math.max(0, Math.floor(now.getTime() / 1000) - seconds)
        if (diff < 60) return qsTr("just now")
        if (diff < 3600) return qsTr("%1 min ago").arg(Math.floor(diff / 60))
        if (diff < 86400) return qsTr("%1 h ago").arg(Math.floor(diff / 3600))
        return qsTr("%1 d ago").arg(Math.floor(diff / 86400))
    }

    // A sor masodik sora: tipus, meret, mikor.
    function describe(item) {
        if (!item) return ""
        var parts = [item.isImage ? qsTr("Image") : qsTr("Text")]
        if (item.meta !== "" && item.meta !== "Image") parts.push(item.meta)
        var when = relativeTime(item.time)
        if (when !== "") parts.push(when)
        return parts.join("  ·  ")
    }

    // A backend tolja az allapotot; a regi API kedveert megmarad.
    function refreshClipboard() {}

    function normalize(value) {
        return (value || "").toString().toLowerCase().replace(/[^a-z0-9]+/g, " ").trim()
    }

    function filterEntries(value) {
        var words = normalize(value).split(/\s+/).filter((word) => word !== "")
        if (words.length === 0) return entries

        var result = []
        for (var i = 0; i < entries.length; i++) {
            var haystack = normalize(entries[i].title + " " + entries[i].subtitle)
            var matched = true
            for (var j = 0; j < words.length; j++) {
                if (haystack.indexOf(words[j]) < 0) {
                    matched = false
                    break
                }
            }
            if (matched) result.push(entries[i])
        }
        return result
    }

    function entryTypeLabel(item) {
        if (!item) return ""
        if (item.pinned) return qsTr("Pinned")
        return item.isImage ? qsTr("Image") : qsTr("Text")
    }

    function previewSource(item) {
        return item && item.isImage ? item.preview : ""
    }

    // Az elonezetet a backend mar elkeszitette.
    function ensurePreview(item) {}

    function activate(item) {
        if (item && backend) backend.call("clipboard", "copy", { id: item.identifier }, null)
    }

    function remove(item) {
        if (item && backend) backend.call("clipboard", "delete", { id: item.identifier }, null)
    }

    function togglePin(item) {
        if (!item || !backend) return
        if (!item.pinned && pinnedCount >= maxPinned) return
        backend.call("clipboard", item.pinned ? "unpin" : "pin", { id: item.identifier }, null)
    }

    function clear() {
        if (backend) backend.call("clipboard", "clear", {}, null)
    }
}

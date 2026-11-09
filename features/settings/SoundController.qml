import QtQuick

// A Hang oldal backend-resze: hangkartya-profilok es stream-atiranyitas a
// backend `audio` modulja alapjan. A hangero, a nemitas es az alapertelmezett
// eszkoz kozvetlenul a Quickshell PipeWire szolgaltatasabol jon, azokhoz nem
// kell daemon.
Item {
    id: controller

    property var backend: null
    property var devices: []
    property bool loading: false
    property bool loaded: false
    property string error: ""
    readonly property bool available: backend !== null && backend.connected === true

    width: 0
    height: 0
    visible: false

    // Egy regebbi daemonban nincs `audio` modul: ezt erthetoen mondjuk, nem a
    // nyers "ismeretlen domain" hibaval.
    function describeError(err, fallback) {
        if (err && err.code === "not_found" && String(err.message).indexOf("audio") !== -1)
            return "The running Vellum daemon is older than this shell. Run scripts/backend-install to update it."
        return err && err.message ? err.message : fallback
    }

    function refresh() {
        if (!available) {
            devices = []
            loading = false
            return
        }
        loading = true
        backend.call("audio", "devices", {}, function(data, err) {
            controller.loading = false
            controller.loaded = true
            if (err) {
                controller.error = controller.describeError(err, "Sound cards could not be read.")
                return
            }
            controller.error = ""
            // Csak valodi valtozasnal cserelunk: az uj tomb minden kartyasort
            // ujraepitene, es a Hang oldal gorgetese visszaugrana.
            var next = data && data.devices ? data.devices : []
            if (JSON.stringify(next) !== JSON.stringify(controller.devices)) controller.devices = next
        })
    }

    // A PipeWire node-jai par szaz ms alatt allnak at egy profilvaltas utan;
    // a kesleltetes egy olvasasba vonja ossze a valtozasokat.
    function scheduleRefresh() {
        refreshTimer.restart()
    }

    function setProfile(device, index) {
        if (!available) return
        backend.call("audio", "setProfile", { "device": device, "index": index }, function(data, err) {
            controller.error = err ? controller.describeError(err, "The profile could not be changed.") : ""
            controller.scheduleRefresh()
        })
    }

    // `stream`: a stream PipeWire azonositoja (PwNode.id).
    function moveStream(stream, target, input) {
        if (!available) return
        backend.call("audio", "moveStream", { "stream": stream, "target": target, "input": input === true }, function(data, err) {
            controller.error = err ? controller.describeError(err, "The stream could not be moved.") : ""
        })
    }

    onAvailableChanged: refresh()
    Component.onCompleted: refresh()

    Timer {
        id: refreshTimer

        interval: 400
        onTriggered: controller.refresh()
    }
}

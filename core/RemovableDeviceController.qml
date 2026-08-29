import QtQuick

// Cserelheto adathordozok a Rust backend `removable` topicjabol.
//
// Korabban ez a fajl 2,5 masodpercenkent inditott egy `lsblk --json`-t, es
// `udisksctl` processzeket a muveletekhez. Most az udisks2 D-Bus a forras, es
// az ertesites is onnan jon.
//
// A publikus property-nevek es a deviceAdded jelzes valtozatlanok.
Item {
    id: controller

    required property var backend

    readonly property var devices: backend && backend.topics.removable && backend.topics.removable.devices
        ? backend.topics.removable.devices
        : []

    property string busyPath: ""
    property string errorMessage: ""
    property bool initialized: false

    readonly property int deviceCount: devices.length
    readonly property int mountedCount: devices.filter(device => device.mounted).length

    signal deviceAdded(string name)

    width: 0
    height: 0
    visible: false

    property var _knownPaths: ({})

    // Az uj eszkoz felismerese a QML oldalon marad: a popup megnyitasa
    // felhasznaloi felulet dolga, nem a backende.
    onDevicesChanged: {
        var next = {}
        var appeared = ""
        for (var i = 0; i < devices.length; i++) {
            var path = devices[i].path
            next[path] = true
            if (initialized && !_knownPaths[path] && appeared === "") appeared = devices[i].name
        }
        _knownPaths = next
        if (initialized && appeared !== "") deviceAdded(appeared)
        initialized = true
    }

    Component.onCompleted: if (backend) backend.subscribe("removable")

    function refresh() {}

    function runAction(method, path) {
        if (busyPath !== "") return
        errorMessage = ""
        busyPath = path
        backend.call("removable", method, { path: path }, (result, error) => {
            controller.busyPath = ""
            if (error) controller.errorMessage = error.message || "Device operation failed"
        })
    }

    function mount(path) { runAction("mount", path) }
    function unmount(path) { runAction("unmount", path) }
    function powerOff(diskPath) { runAction("powerOff", diskPath) }

    function open(device) {
        if (!device || !device.mountpoint) return
        Qt.openUrlExternally("file://" + device.mountpoint)
    }
}

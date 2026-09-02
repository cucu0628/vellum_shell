import QtQuick
import Quickshell.Bluetooth

// Thin view over the Bluez singleton so the bar and the popup read the same
// derived state instead of each filtering the device list themselves.
Item {
    id: controller

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    // Nem `enabled`: az elfedne a QQuickItem sajat propertyjet.
    readonly property bool adapterEnabled: adapter ? adapter.enabled : false
    readonly property bool discovering: adapter ? adapter.discovering : false

    readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
    readonly property var connectedDevices: devices.filter((device) => device && device.connected)
    readonly property var pairedDevices: devices.filter((device) => device && (device.paired || device.bonded))
    readonly property bool connected: connectedDevices.length > 0
    readonly property var primaryDevice: connectedDevices.length > 0 ? connectedDevices[0] : null
    readonly property string primaryName: primaryDevice
        ? (primaryDevice.name || primaryDevice.deviceName || primaryDevice.address || "")
        : ""

    function deviceLabel(device) {
        if (!device) return ""
        return device.name || device.deviceName || device.address || "Unknown device"
    }

    function setEnabled(value) {
        if (adapter) adapter.enabled = value
    }

    function setDiscovering(value) {
        if (adapter) adapter.discovering = value
    }

    width: 0
    height: 0
    visible: false
}

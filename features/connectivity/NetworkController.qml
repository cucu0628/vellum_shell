import QtQuick
import Quickshell.Io

// A Wi-Fi panel backend-kliense. Az nmcli futtatasa es parsolasa a Rust
// `network` modul dolga; itt csak a keresek eletciklusa es a UI-allapot marad.
Item {
    id: controller

    property var backend: null
    property var statusController: null
    property bool active: false
    property bool wifiEnabled: true
    property bool scanning: false
    property bool radioBusy: false
    property bool connecting: false
    property string busySsid: ""
    property string errorMessage: ""
    property var networks: []

    signal connectionSucceeded()
    signal advancedSettingsOpened()

    width: 0
    height: 0
    visible: false

    function errorText(error, fallback) {
        return error && error.message ? error.message : fallback;
    }

    function refresh() {
        if (scanning || !backend)
            return;
        scanning = true;
        backend.call("network", "scan", {}, (result, error) => {
            scanning = false;
            if (error) {
                networks = [];
                errorMessage = errorText(error, "Could not scan Wi-Fi networks");
                return;
            }
            wifiEnabled = result.wifiEnabled === true;
            networks = result.networks || [];
            errorMessage = "";
        });
    }

    function connectNetwork(ssid, secure, password) {
        if (ssid === "" || connecting || !backend)
            return;
        connecting = true;
        errorMessage = "";
        backend.call("network", "connect", {
            "ssid": ssid,
            "secure": secure,
            "password": secure ? password : ""
        }, (result, error) => {
            connecting = false;
            if (error) {
                errorMessage = errorText(error, "Connection failed");
                return;
            }
            connectionSucceeded();
            connectionRefreshTimer.restart();
        });
    }

    function disconnectNetwork(network) {
        if (busySsid !== "" || !backend)
            return;
        var device = network.device || (statusController ? statusController.device : "");
        if (device === "") {
            errorMessage = "Wi-Fi device not found";
            return;
        }
        busySsid = network.ssid;
        errorMessage = "";
        backend.call("network", "disconnect", { "device": device }, (result, error) => {
            busySsid = "";
            if (error)
                errorMessage = errorText(error, "Could not disconnect the network");
            connectionRefreshTimer.restart();
        });
    }

    function toggleWifi() {
        if (!backend || radioBusy)
            return;
        radioBusy = true;
        errorMessage = "";
        backend.call("network", "setWifiEnabled", { "enabled": !wifiEnabled }, (result, error) => {
            radioBusy = false;
            if (error) {
                errorMessage = errorText(error, "Could not change Wi-Fi state");
                return;
            }
            wifiEnabled = result.enabled === true;
            if (!wifiEnabled)
                networks = [];
            radioRefreshTimer.restart();
        });
    }

    function openAdvancedSettings() {
        advancedLauncher.command = ["kcmshell6", "kcm_networkmanagement"];
        advancedLauncher.running = true;
        advancedSettingsOpened();
    }

    onActiveChanged: if (active) refresh()

    Process { id: advancedLauncher }

    Timer {
        id: radioRefreshTimer
        interval: 500
        onTriggered: controller.refresh()
    }

    Timer {
        id: connectionRefreshTimer
        interval: 800
        onTriggered: controller.refresh()
    }
}

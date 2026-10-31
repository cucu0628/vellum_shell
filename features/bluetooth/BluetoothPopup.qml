import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Wayland
import "../../ui" as SharedUi

PanelWindow {
    id: bluetoothWindow

    property var theme: null
    property var statusController: null
    required property string shellDir
    property bool opened: false
    property int barHeight: 26
    property string errorMessage: ""
    property string pairingAddress: ""
    property string pairingLabel: ""
    property string pairingPasskey: ""
    property string pairingPrompt: ""
    property bool pairingWaiting: false
    property bool pairingBusy: false
    property string agentStatus: ""
    property string agentTail: ""
    property int agentConsumed: 0

    readonly property string panelFg: theme ? theme.foreground : "#e8ddc7"
    readonly property string panelAccent: theme ? theme.accent : "#b7372f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string inkBg: theme && theme.surface ? theme.surface : "#191b16"
    // Fejlec (34), allapotkartya (72), szakaszcim (28) es a kozok.
    readonly property int fixedHeight: 170 + (pairingBusy ? 84 : 0) + (errorMessage !== "" ? 26 : 0)

    readonly property var adapter: statusController ? statusController.adapter : null
    readonly property bool adapterAvailable: statusController ? statusController.available : false
    readonly property bool adapterEnabled: statusController ? statusController.adapterEnabled : false
    readonly property bool discovering: statusController ? statusController.discovering : false
    readonly property var primaryDevice: statusController ? statusController.primaryDevice : null

    // Paired devices first, then anything discovered nearby; connected on top.
    readonly property var deviceList: {
        if (!statusController) return []
        var all = statusController.devices.slice()
        all.sort((a, b) => {
            var rank = (device) => (device.connected ? 0 : (device.paired || device.bonded ? 1 : 2))
            return rank(a) - rank(b) || bluetoothWindow.deviceName(a).localeCompare(bluetoothWindow.deviceName(b))
        })
        return all
    }

    function deviceName(device) {
        if (!device) return ""
        return device.name || device.deviceName || device.address || "Unknown device"
    }

    function deviceIcon(device) {
        var icon = device && device.icon ? device.icon.toLowerCase() : ""
        if (icon.indexOf("headset") !== -1 || icon.indexOf("headphone") !== -1) return "󰋋"
        if (icon.indexOf("audio") !== -1 || icon.indexOf("speaker") !== -1) return "󰓃"
        if (icon.indexOf("phone") !== -1) return "󰄜"
        if (icon.indexOf("mouse") !== -1) return "󰍽"
        if (icon.indexOf("keyboard") !== -1) return "󰌌"
        if (icon.indexOf("computer") !== -1) return "󰍹"
        return "󰂯"
    }

    function deviceStatus(device) {
        if (!device) return ""
        if (device.pairing) return "Pairing..."
        if (device.connected) {
            if (device.batteryAvailable) return "Connected  ·  Battery " + Math.round(device.battery * 100) + "%"
            return "Connected"
        }
        if (device.paired || device.bonded) return "Paired"
        return "Not paired"
    }

    // BlueZ can only finish a pairing that needs confirmation when an agent is
    // registered on the bus. Nothing on this system provides one, so a
    // bluetoothctl session is kept alive alongside the panel to act as the
    // agent, and its passkey prompt is surfaced here.
    function stripControl(line) {
        return (line || "")
            .replace(/\u001b\[[0-9;?]*[A-Za-z]/g, "")
            .replace(/\r/g, "")
            .replace(/^\[[^\]]*\]# ?/, "")
            .replace(/^\[bluetoothctl\]> ?/, "")
            .trim()
    }

    // bluetoothctl writes its passkey question as a readline prompt with no
    // trailing newline, so the stream is consumed incrementally and the
    // unterminated tail is inspected too.
    function consumeAgentOutput(text) {
        var full = text || ""
        if (full.length < agentConsumed) agentConsumed = 0
        var fresh = full.slice(agentConsumed)
        agentConsumed = full.length
        if (fresh === "") return

        agentTail += fresh
        var parts = agentTail.split("\n")
        agentTail = parts.pop()
        for (var i = 0; i < parts.length; i++) handleAgentLine(parts[i])
        if (agentTail !== "") handleAgentLine(agentTail)
    }

    function agentSend(command) {
        if (!agentSession.running) return false
        agentSession.write(command + "\n")
        return true
    }

    function startPairing(device) {
        if (!device) return
        if (!agentSession.running) {
            errorMessage = "Pairing service is not running"
            return
        }
        errorMessage = ""
        pairingAddress = device.address
        pairingLabel = deviceName(device)
        pairingPasskey = ""
        pairingPrompt = ""
        pairingWaiting = false
        pairingBusy = true
        agentSend("pair " + device.address)
    }

    function confirmPairing(accept) {
        if (!pairingWaiting) return
        agentSend(accept ? "yes" : "no")
        pairingWaiting = false
        pairingPrompt = accept ? "Confirming..." : "Cancelled"
        if (!accept) pairingBusy = false
    }

    function cancelPairing() {
        if (pairingAddress !== "") agentSend("cancel-pairing " + pairingAddress)
        resetPairing()
    }

    function resetPairing() {
        agentStatus = ""
        pairingAddress = ""
        pairingLabel = ""
        pairingPasskey = ""
        pairingPrompt = ""
        pairingWaiting = false
        pairingBusy = false
    }

    function handleAgentLine(raw) {
        var line = stripControl(raw)
        if (line === "") return
        if (pairingBusy && !/^\[(NEW|CHG|DEL)\]/.test(line)) agentStatus = line

        var passkey = /Confirm passkey (\d+)/i.exec(line)
        if (passkey) {
            pairingPasskey = passkey[1]
            pairingPrompt = "Confirm this code on the device"
            pairingWaiting = true
            return
        }

        if (/Authorize service/i.test(line)) {
            agentSend("yes")
            return
        }

        if (/Request (PIN code|passkey)/i.test(line)) {
            pairingPrompt = "Enter the code shown on the device"
            return
        }

        if (/Pairing successful/i.test(line)) {
            pairingPrompt = "Paired successfully"
            pairingWaiting = false
            if (pairingAddress !== "") {
                agentSend("trust " + pairingAddress)
                agentSend("connect " + pairingAddress)
            }
            pairingDoneTimer.restart()
            return
        }

        var failure = /Failed to pair:?\s*(.*)$/i.exec(line)
        if (failure) {
            errorMessage = "Pairing failed: " + (failure[1] !== "" ? failure[1].replace("org.bluez.Error.", "") : "Unknown error")
            resetPairing()
            return
        }
    }

    function toggleAdapter() {
        errorMessage = ""
        if (!adapter) {
            errorMessage = "No Bluetooth adapter found"
            return
        }
        adapter.enabled = !adapter.enabled
    }

    function toggleScan() {
        errorMessage = ""
        if (!adapter || !adapter.enabled) return
        adapter.discovering = !adapter.discovering
    }

    function activate(device) {
        if (!device) return
        errorMessage = ""
        if (device.connected) device.disconnect()
        else if (device.paired || device.bonded) device.connect()
        else startPairing(device)
    }

    function forget(device) {
        if (!device) return
        errorMessage = ""
        device.forget()
    }

    function openAdvancedSettings() {
        advancedLauncher.command = [shellDir + "/scripts/launch-bluetooth"]
        advancedLauncher.running = true
        opened = false
    }

    onOpenedChanged: {
        errorMessage = ""
        resetPairing()
        // Discovery burns battery on both ends, so it only runs while the panel is up.
        if (!opened && adapter && adapter.discovering) adapter.discovering = false
    }

    visible: opened || sheet.reveal > 0
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "quickshell.bluetooth"
    WlrLayershell.exclusiveZone: -1

    Process { id: advancedLauncher }

    Process {
        id: agentSession
        command: ["bluetoothctl"]
        running: bluetoothWindow.opened && bluetoothWindow.adapterEnabled
        stdinEnabled: true

        onRunningChanged: {
            bluetoothWindow.agentConsumed = 0
            bluetoothWindow.agentTail = ""
        }

        stdout: StdioCollector {
            waitForEnd: false
            onDataChanged: bluetoothWindow.consumeAgentOutput(this.text || "")
        }
    }

    Timer {
        id: pairingDoneTimer
        interval: 1500
        onTriggered: bluetoothWindow.resetPairing()
    }

    // BlueZ gives no failure signal when the far end simply never answers, so
    // the attempt is abandoned rather than left spinning.
    Timer {
        id: pairingTimeout
        interval: 60000
        running: bluetoothWindow.pairingBusy
        onTriggered: {
            bluetoothWindow.errorMessage = "Pairing timed out"
            bluetoothWindow.cancelPairing()
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: bluetoothWindow.opened
        onClicked: bluetoothWindow.opened = false
    }

    Item {
        id: content

        anchors.right: parent.right
        anchors.rightMargin: 0
        enabled: bluetoothWindow.opened
        // A sav aljahoz tapad: a panel a savbol nyilik le, nem lebeg alatta.
        y: bluetoothWindow.barHeight
        width: Math.min(420, parent.width - 20)
        height: Math.min(parent.height - bluetoothWindow.barHeight - 12,
            32 + bluetoothWindow.fixedHeight + Math.max(112, Math.min(deviceList.length, 6) * 56))
        clip: true

        Behavior on height { NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }

        SharedUi.PopupFrame {
            id: sheet
            rightEar: false
            squareRight: true
            shown: bluetoothWindow.opened
            anchors.fill: parent
            theme: bluetoothWindow.theme

            MouseArea { anchors.fill: parent; onClicked: (mouse) => mouse.accepted = true }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                SharedUi.PopupHeader {
                    width: parent.width
                    theme: bluetoothWindow.theme
                    title: "Bluetooth"
                    trailingWidth: 64

                    SharedUi.HeaderChip {
                        anchors.fill: parent
                        anchors.bottomMargin: 6
                        enabled: bluetoothWindow.adapterAvailable
                        theme: bluetoothWindow.theme
                        label: "On"
                        checkable: true
                        checked: bluetoothWindow.adapterEnabled
                        accessibleName: bluetoothWindow.adapterEnabled ? qsTr("Turn Bluetooth off") : qsTr("Turn Bluetooth on")
                        onClicked: toggleAdapter()
                    }
                }

                SharedUi.StatusCard {
                    width: parent.width
                    theme: bluetoothWindow.theme
                    active: statusController && statusController.connected
                    glyph: !adapterEnabled ? "󰂲" : (primaryDevice ? deviceIcon(primaryDevice) : "󰂯")
                    title: !adapterAvailable
                        ? "No adapter detected"
                        : (!adapterEnabled ? "Bluetooth is off" : (primaryDevice ? deviceName(primaryDevice) : "No device connected"))
                    subtitle: primaryDevice
                        ? primaryDevice.address + (primaryDevice.batteryAvailable ? "  ·  Battery " + Math.round(primaryDevice.battery * 100) + "%" : "")
                        : (adapterEnabled ? "Ready to connect" : "")
                }

                SharedUi.SectionBar {
                    width: parent.width
                    theme: bluetoothWindow.theme
                    title: "DEVICES"
                    detail: adapterEnabled ? String(deviceList.length) : ""

                    SharedUi.HeaderChip {
                        theme: bluetoothWindow.theme
                        label: discovering ? "Stop scan" : "Scan"
                        checked: discovering
                        enabled: bluetoothWindow.adapterEnabled
                        accessibleName: discovering ? qsTr("Stop scanning for devices") : qsTr("Scan for devices")
                        onClicked: toggleScan()
                    }

                    SharedUi.HeaderChip {
                        theme: bluetoothWindow.theme
                        label: "Settings"
                        accessibleName: qsTr("Open Bluetooth settings")
                        onClicked: openAdvancedSettings()
                    }
                }

                Item {
                    width: parent.width
                    height: parent.height - bluetoothWindow.fixedHeight

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 32
                        visible: !adapterEnabled || deviceList.length === 0
                        text: !adapterAvailable
                            ? "No Bluetooth adapter found."
                            : (!adapterEnabled ? "Turn on Bluetooth to see devices." : "No devices found. Try scanning again.")
                        color: mutedFg
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    Flickable {
                        anchors.fill: parent
                        visible: adapterEnabled && deviceList.length > 0
                        contentHeight: deviceColumn.height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: deviceColumn
                            width: parent.width
                            spacing: 4

                            Repeater {
                                // ScriptModel: a lista frissulesekor (pl. kereses kozben) a
                                // meglevo sorok megmaradnak, csak az uj vagy eltunt eszkozok
                                // sora jon letre / szunik meg.
                                model: ScriptModel { values: bluetoothWindow.deviceList }

                                // Jobb gomb: az eszkoz elfelejtese.
                                SharedUi.ListRow {
                                    required property var modelData

                                    width: deviceColumn.width
                                    theme: bluetoothWindow.theme
                                    glyph: deviceIcon(modelData)
                                    title: deviceName(modelData)
                                    subtitle: deviceStatus(modelData)
                                    trailing: modelData.connected
                                        ? "Disconnect"
                                        : (modelData.pairing ? "Pairing…" : (modelData.paired || modelData.bonded ? "Connect" : "Pair"))
                                    active: modelData.connected
                                    selected: bluetoothWindow.pairingAddress !== "" && bluetoothWindow.pairingAddress === modelData.address
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    accessibleName: (modelData.connected ? qsTr("Disconnect %1") : qsTr("Connect %1")).arg(deviceName(modelData))
                                    onClicked: (event) => {
                                        if (event.button === Qt.RightButton) forget(modelData)
                                        else activate(modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                // Parositas: a kod nagyban, mellette a dontes. Ugyanaz a
                // kartyafelulet, mint felul, keret es oldalcsik nelkul.
                Rectangle {
                    width: parent.width
                    height: bluetoothWindow.pairingBusy ? 72 : 0
                    visible: height > 0
                    clip: true
                    radius: 10
                    color: inkBg

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 12
                        anchors.topMargin: 10
                        anchors.bottomMargin: 10
                        spacing: 12

                        Column {
                            width: parent.width - pairingActions.width - parent.spacing
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                width: parent.width
                                text: bluetoothWindow.pairingLabel
                                textFormat: Text.PlainText
                                color: panelFg
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: bluetoothWindow.pairingPasskey !== ""
                                    ? bluetoothWindow.pairingPasskey
                                    : (bluetoothWindow.pairingPrompt !== "" ? bluetoothWindow.pairingPrompt : "Pairing…")
                                color: bluetoothWindow.pairingPasskey !== "" ? panelAccent : mutedFg
                                font.family: bluetoothWindow.pairingPasskey !== "" ? "monospace" : "sans-serif"
                                font.pixelSize: bluetoothWindow.pairingPasskey !== "" ? 20 : 10
                                font.letterSpacing: bluetoothWindow.pairingPasskey !== "" ? 4 : 0
                                font.weight: bluetoothWindow.pairingPasskey !== "" ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                visible: bluetoothWindow.pairingPasskey !== "" || bluetoothWindow.agentStatus !== ""
                                text: bluetoothWindow.pairingPasskey !== ""
                                    ? bluetoothWindow.pairingPrompt
                                    : bluetoothWindow.agentStatus
                                textFormat: Text.PlainText
                                color: mutedFg
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }

                        Row {
                            id: pairingActions

                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            SharedUi.HeaderChip {
                                visible: !bluetoothWindow.pairingWaiting
                                height: 32
                                theme: bluetoothWindow.theme
                                label: "Cancel"
                                onClicked: cancelPairing()
                            }

                            SharedUi.HeaderChip {
                                visible: bluetoothWindow.pairingWaiting
                                height: 32
                                theme: bluetoothWindow.theme
                                label: "Reject"
                                onClicked: confirmPairing(false)
                            }

                            SharedUi.HeaderChip {
                                visible: bluetoothWindow.pairingWaiting
                                height: 32
                                theme: bluetoothWindow.theme
                                emphasized: true
                                label: "Confirm"
                                onClicked: confirmPairing(true)
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    height: 14
                    visible: bluetoothWindow.errorMessage !== ""
                    text: bluetoothWindow.errorMessage
                    textFormat: Text.PlainText
                    color: panelAccent
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }
    }
}

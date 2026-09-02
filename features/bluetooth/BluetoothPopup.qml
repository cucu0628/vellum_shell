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
    property bool opened: false
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

    readonly property string panelBg: theme ? theme.background : "#11130f"
    readonly property string panelFg: theme ? theme.foreground : "#e8ddc7"
    readonly property string panelAccent: theme ? theme.accent : "#b7372f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string inkBg: theme && theme.surface ? theme.surface : "#191b16"
    readonly property color hoverBg: Qt.rgba(1, 1, 1, 0.075)
    readonly property color lineBg: Qt.rgba(1, 1, 1, 0.055)

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
        advancedLauncher.command = ["sh", "-c", "exec \"$HOME/.config/quickshell/vellum_shell/scripts/launch-bluetooth\""]
        advancedLauncher.running = true
        opened = false
    }

    onOpenedChanged: {
        errorMessage = ""
        resetPairing()
        // Discovery burns battery on both ends, so it only runs while the panel is up.
        if (!opened && adapter && adapter.discovering) adapter.discovering = false
    }

    visible: opened || content.opacity > 0
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
        anchors.rightMargin: 10
        enabled: bluetoothWindow.opened
        y: 32
        width: Math.min(430, parent.width - 20)
        height: opened ? Math.min(570, parent.height - 46, Math.max(284, 220 + Math.min(deviceList.length, 6) * 56) + (pairingBusy ? 84 : 0)) : 0
        clip: true
        opacity: opened ? 1 : 0

        Behavior on height { NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        SharedUi.PopupFrame {
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
                    subtitle: !adapterAvailable
                        ? "No adapter detected"
                        : (statusController && statusController.connected
                            ? "Connected  ·  " + statusController.primaryName
                            : (adapterEnabled ? "Ready to connect" : "Bluetooth is off"))
                    trailingWidth: 67

                    Rectangle {
                        anchors.fill: parent
                        anchors.bottomMargin: 4
                        color: adapterEnabled ? panelAccent : inkBg
                        border.color: adapterEnabled ? panelAccent : mutedFg
                        border.width: 1
                        opacity: adapterAvailable ? 1 : 0.45
                        Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }

                        Text {
                            anchors.centerIn: parent
                            text: adapterEnabled ? "BT ON" : "BT OFF"
                            color: adapterEnabled ? panelBg : mutedFg
                            font.family: "monospace"
                            font.pixelSize: 8
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: bluetoothWindow.adapterAvailable
                            cursorShape: Qt.PointingHandCursor
                            onClicked: toggleAdapter()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 72
                    color: inkBg

                    Rectangle {
                        anchors.left: parent.left
                        width: 3
                        height: parent.height
                        color: statusController && statusController.connected ? panelAccent : mutedFg
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Text {
                            width: 34
                            anchors.verticalCenter: parent.verticalCenter
                            text: !adapterEnabled ? "󰂲" : (primaryDevice ? deviceIcon(primaryDevice) : "󰂯")
                            color: statusController && statusController.connected ? panelAccent : mutedFg
                            font.pixelSize: 25
                        }

                        Column {
                            width: parent.width - 46
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Text {
                                width: parent.width
                                text: primaryDevice ? deviceName(primaryDevice) : "No device connected"
                                color: panelFg
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: primaryDevice
                                    ? primaryDevice.address + (primaryDevice.batteryAvailable ? "    BATTERY  " + Math.round(primaryDevice.battery * 100) + "%" : "")
                                    : deviceList.length + (deviceList.length === 1 ? " DEVICE FOUND" : " DEVICES FOUND")
                                color: mutedFg
                                font.pixelSize: 12
                                font.letterSpacing: 0.5
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 28

                    Text {
                        width: parent.width - 190
                        height: parent.height
                        text: discovering ? "SCANNING..." : "DEVICES  ·  " + deviceList.length
                        color: panelAccent
                        font.family: "monospace"
                        font.pixelSize: 8
                        font.letterSpacing: 2
                        font.bold: true
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        width: 110
                        height: parent.height
                        text: "Settings"
                        color: advancedMouse.containsMouse ? panelAccent : mutedFg
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 10
                        font.family: "monospace"

                        MouseArea {
                            id: advancedMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: openAdvancedSettings()
                        }
                    }

                    Text {
                        width: 80
                        height: parent.height
                        text: discovering ? "Stop scan" : "Scan"
                        color: scanMouse.containsMouse ? panelAccent : mutedFg
                        opacity: adapterEnabled ? 1 : 0.45
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 11
                        font.family: "monospace"

                        MouseArea {
                            id: scanMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: bluetoothWindow.adapterEnabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: toggleScan()
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: parent.height - 200 - (bluetoothWindow.pairingBusy ? 84 : 0)

                    Text {
                        anchors.centerIn: parent
                        width: parent.width
                        visible: !adapterEnabled || deviceList.length === 0
                        text: !adapterAvailable
                            ? "No Bluetooth adapter found"
                            : (!adapterEnabled ? "Turn on Bluetooth to see devices" : "No devices found. Try scanning again.")
                        color: mutedFg
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
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
                                model: bluetoothWindow.deviceList

                                Rectangle {
                                    id: deviceRow
                                    required property var modelData

                                    width: deviceColumn.width
                                    height: 52
                                    color: deviceMouse.containsMouse || deviceRow.modelData.connected ? inkBg : "transparent"
                                    Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }

                                    Rectangle {
                                        anchors.left: parent.left
                                        width: 3
                                        height: parent.height
                                        color: panelAccent
                                        opacity: deviceRow.modelData.connected ? 1 : 0
                                    }

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 10

                                        Text {
                                            width: 25
                                            height: parent.height
                                            text: deviceIcon(deviceRow.modelData)
                                            color: deviceRow.modelData.connected ? panelAccent : panelFg
                                            font.pixelSize: 19
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        Column {
                                            width: parent.width - 158
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 2

                                            Text {
                                                width: parent.width
                                                text: deviceName(deviceRow.modelData)
                                                color: panelFg
                                                font.pixelSize: 13
                                                font.weight: deviceRow.modelData.connected ? Font.DemiBold : Font.Normal
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: deviceStatus(deviceRow.modelData)
                                                color: deviceRow.modelData.connected ? panelAccent : mutedFg
                                                font.family: "monospace"
                                                font.pixelSize: 9
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Text {
                                            width: 80
                                            height: parent.height
                                            text: deviceRow.modelData.connected
                                                ? "Disconnect"
                                                : (deviceRow.modelData.pairing ? "..." : (deviceRow.modelData.paired || deviceRow.modelData.bonded ? "Connect" : "Pair"))
                                            color: deviceRow.modelData.connected ? panelAccent : mutedFg
                                            font.pixelSize: 11
                                            verticalAlignment: Text.AlignVCenter
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }

                                    MouseArea {
                                        id: deviceMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: (mouse) => {
                                            if (mouse.button === Qt.RightButton) forget(deviceRow.modelData)
                                            else activate(deviceRow.modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: bluetoothWindow.pairingBusy ? 72 : 0
                    visible: height > 0
                    clip: true
                    color: inkBg
                    border.color: panelAccent
                    border.width: 1

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 3
                        color: panelAccent
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 10
                        anchors.topMargin: 10
                        anchors.bottomMargin: 10
                        spacing: 12

                        Column {
                            width: parent.width - (bluetoothWindow.pairingWaiting ? 168 : 92)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Text {
                                width: parent.width
                                text: bluetoothWindow.pairingLabel
                                color: panelFg
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: bluetoothWindow.pairingPasskey !== ""
                                    ? bluetoothWindow.pairingPasskey
                                    : (bluetoothWindow.pairingPrompt !== "" ? bluetoothWindow.pairingPrompt : "Pairing...")
                                color: bluetoothWindow.pairingPasskey !== "" ? panelAccent : mutedFg
                                font.pixelSize: bluetoothWindow.pairingPasskey !== "" ? 20 : 9
                                font.letterSpacing: bluetoothWindow.pairingPasskey !== "" ? 4 : 0
                                font.bold: bluetoothWindow.pairingPasskey !== ""
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                visible: bluetoothWindow.pairingPasskey !== "" || bluetoothWindow.agentStatus !== ""
                                text: bluetoothWindow.pairingPasskey !== ""
                                    ? bluetoothWindow.pairingPrompt
                                    : bluetoothWindow.agentStatus
                                color: mutedFg
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: bluetoothWindow.pairingBusy && !bluetoothWindow.pairingWaiting
                            width: 82
                            height: 34
                            color: cancelPairMouse.containsMouse ? hoverBg : "transparent"
                            border.color: lineBg
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "Cancel"
                                color: panelFg
                                font.pixelSize: 10
                            }

                            MouseArea {
                                id: cancelPairMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cancelPairing()
                            }
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: bluetoothWindow.pairingWaiting
                            spacing: 6

                            Rectangle {
                                width: 74
                                height: 34
                                color: rejectMouse.containsMouse ? hoverBg : "transparent"
                                border.color: lineBg
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "Reject"
                                    color: panelFg
                                    font.pixelSize: 11
                                }

                                MouseArea {
                                    id: rejectMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: confirmPairing(false)
                                }
                            }

                            Rectangle {
                                width: 82
                                height: 34
                                color: acceptMouse.containsMouse ? Qt.lighter(panelAccent, 1.15) : panelAccent

                                Text {
                                    anchors.centerIn: parent
                                    text: "Confirm"
                                    color: panelBg
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                MouseArea {
                                    id: acceptMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: confirmPairing(true)
                                }
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: bluetoothWindow.errorMessage !== ""
                    text: bluetoothWindow.errorMessage
                    color: panelAccent
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }
    }
}

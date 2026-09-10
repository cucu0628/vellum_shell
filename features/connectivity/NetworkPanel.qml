import QtQuick
import "../../ui" as SharedUi

// Wi-Fi half of the connectivity panel. It only asks the backend to scan while
// `active`, so the tab that is not on screen costs nothing.
Item {
    id: networkPanel

    property var theme: null
    property var backend: null
    property var statusController: null
    property bool active: false
    readonly property alias wifiEnabled: controller.wifiEnabled
    readonly property alias scanning: controller.scanning
    readonly property alias connecting: controller.connecting
    property bool selectedSecure: false
    readonly property alias busySsid: controller.busySsid
    property string selectedSsid: ""
    property alias errorMessage: controller.errorMessage
    readonly property alias networks: controller.networks
    readonly property int preferredHeight: Math.min(554, 264 + Math.min(networks.length, 5) * 56 + (selectedSsid !== "" ? 88 : 0))
    readonly property string panelBg: theme ? theme.background : "#15110f"
    readonly property string panelFg: theme ? theme.foreground : "#f1e7d0"
    readonly property string panelAccent: theme ? theme.accent : "#d7472f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#9f8f7c"
    readonly property string inkBg: theme && theme.surface ? theme.surface : "#1b1613"
    readonly property color hoverBg: Qt.rgba(1, 1, 1, 0.075)

    signal closeRequested()

    function signalIcon(signal) {
        if (signal >= 75)
            return "󰤨";

        if (signal >= 50)
            return "󰤥";

        if (signal >= 25)
            return "󰤢";

        return "󰤟";
    }

    function chooseNetwork(network) {
        errorMessage = "";
        passwordInput.text = "";
        if (selectedSsid === network.ssid) {
            selectedSsid = "";
            return ;
        }
        selectedSsid = network.ssid;
        selectedSecure = network.secure;
        if (network.secure)
            passwordInput.forceActiveFocus();

    }

    function connectSelected() {
        if (selectedSsid === "" || connecting)
            return ;
        controller.connectNetwork(selectedSsid, selectedSecure, passwordInput.text);
    }

    function disconnectNetwork(network) {
        controller.disconnectNetwork(network);
    }

    function openAdvancedSettings() {
        controller.openAdvancedSettings();
    }

    function toggleWifi() {
        controller.toggleWifi();
    }

    onActiveChanged: {
        if (active) {
            controller.refresh();
        } else {
            selectedSsid = "";
            passwordInput.text = "";
            errorMessage = "";
        }
    }

    Column {
        anchors.fill: parent
        spacing: 12

        SharedUi.PopupHeader {
            width: parent.width
            theme: networkPanel.theme
            title: "Network"
            subtitle: statusController && statusController.connected
                ? "Connected  ·  " + (statusController.connectionType === "ethernet" ? "Ethernet" : statusController.connectionName)
                : "Offline"
            trailingWidth: 67

            Rectangle {
                anchors.fill: parent
                anchors.bottomMargin: 4
                color: wifiEnabled ? panelAccent : inkBg
                border.color: wifiEnabled ? panelAccent : mutedFg

                Text {
                    anchors.centerIn: parent
                    text: wifiEnabled ? "WI-FI ON" : "WI-FI OFF"
                    color: wifiEnabled ? panelBg : mutedFg
                    font.family: "monospace"
                    font.pixelSize: 8
                    font.bold: true
                }

                SharedUi.Pressable {
                    anchors.fill: parent
                    enabled: !controller.radioBusy
                    theme: networkPanel.theme
                    accessibleName: networkPanel.wifiEnabled ? qsTr("Turn Wi-Fi off") : qsTr("Turn Wi-Fi on")
                    onClicked: toggleWifi()
                }

            }

        }

        Rectangle {
            width: parent.width
            height: 72
            color: inkBg
            border.color: "transparent"

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
                    text: statusController && statusController.connectionType === "ethernet" ? "󰈀" : (statusController && statusController.connected ? "󰤨" : "󰤭")
                    color: statusController && statusController.connected ? panelAccent : mutedFg
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 25
                }

                Column {
                    width: parent.width - 136
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        width: parent.width
                        text: statusController && statusController.connected
                            ? (statusController.connectionType === "ethernet" ? "Ethernet" : statusController.connectionName)
                            : "No connection"
                        color: panelFg
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: (statusController && statusController.device !== "" ? statusController.device + "  ·  " : "")
                            + "LAN IP  " + (statusController && statusController.lanIp !== "" ? statusController.lanIp : "---.---.---.---")
                        color: mutedFg
                        font.pixelSize: 12
                        font.letterSpacing: 0.5
                        elide: Text.ElideRight
                    }

                }

                // Live throughput of the interface the connection runs on.
                Column {
                    width: 78
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Row {
                        width: parent.width
                        spacing: 6

                        Text {
                            width: 10
                            text: "↓"
                            color: panelAccent
                            font.family: "monospace"
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Text {
                            width: parent.width - 16
                            text: throughput.format(throughput.downRate)
                            color: panelFg
                            font.family: "monospace"
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignRight
                        }

                    }

                    Row {
                        width: parent.width
                        spacing: 6

                        Text {
                            width: 10
                            text: "↑"
                            color: panelAccent
                            font.family: "monospace"
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Text {
                            width: parent.width - 16
                            text: throughput.format(throughput.upRate)
                            color: mutedFg
                            font.family: "monospace"
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignRight
                        }

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
                text: scanning ? "SCANNING..." : "AVAILABLE WI-FI  ·  " + networks.length
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

                SharedUi.Pressable {
                    id: advancedMouse

                    anchors.fill: parent
                    theme: networkPanel.theme
                    accessibleName: qsTr("Open network settings")
                    onClicked: openAdvancedSettings()
                }

            }

            Text {
                width: 80
                height: parent.height
                text: "Refresh"
                color: refreshMouse.containsMouse ? panelAccent : mutedFg
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 11
                font.family: "monospace"

                SharedUi.Pressable {
                    id: refreshMouse

                    anchors.fill: parent
                    theme: networkPanel.theme
                    accessibleName: qsTr("Refresh Wi-Fi networks")
                    onClicked: controller.refresh()
                }

            }

        }

        Item {
            width: parent.width
            height: parent.height - 200 - (selectedSsid !== "" ? 88 : 0)

            Text {
                anchors.centerIn: parent
                visible: !wifiEnabled || (!scanning && networks.length === 0)
                text: wifiEnabled ? "No networks found. Try refreshing." : "Turn on Wi-Fi to see networks"
                color: mutedFg
                font.pixelSize: 13
            }

            Flickable {
                anchors.fill: parent
                visible: wifiEnabled && networks.length > 0
                contentHeight: networkColumn.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: networkColumn

                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: networks

                        Rectangle {
                            id: networkRow

                            required property var modelData
                            width: networkColumn.width
                            height: 52
                            color: networkMouse.containsMouse || networkRow.modelData.active || networkPanel.selectedSsid === networkRow.modelData.ssid ? networkPanel.inkBg : "transparent"
                            border.color: "transparent"
                            border.width: 0

                            Rectangle {
                                anchors.left: parent.left
                                width: 3
                                height: parent.height
                                color: panelAccent
                                opacity: networkRow.modelData.active || networkPanel.selectedSsid === networkRow.modelData.ssid ? 1 : 0
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Text {
                                    width: 25
                                    height: parent.height
                                    text: networkPanel.signalIcon(networkRow.modelData.signal)
                                    color: networkRow.modelData.active ? networkPanel.panelAccent : networkPanel.panelFg
                                    font.family: "Symbols Nerd Font Mono"
                                    font.pixelSize: 19
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Column {
                                    width: parent.width - 158
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        width: parent.width
                                        text: networkRow.modelData.ssid
                                        color: networkPanel.panelFg
                                        font.pixelSize: 13
                                        font.weight: networkRow.modelData.active ? Font.DemiBold : Font.Normal
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: networkRow.modelData.active ? "Connected" : networkRow.modelData.signal + "%  ·  " + (networkRow.modelData.secure ? networkRow.modelData.security : "Open network")
                                        color: networkRow.modelData.active ? networkPanel.panelAccent : networkPanel.mutedFg
                                        font.family: "monospace"
                                        font.pixelSize: 9
                                    }

                                }

                                Text {
                                    width: 80
                                    height: parent.height
                                    text: networkRow.modelData.active ? (networkPanel.busySsid === networkRow.modelData.ssid ? "Wait..." : "Disconnect") : (networkRow.modelData.enterprise ? "802.1X" : (networkRow.modelData.secure ? "" : "Connect"))
                                    color: networkRow.modelData.active ? networkPanel.panelAccent : networkPanel.mutedFg
                                    font.family: networkRow.modelData.active || networkRow.modelData.enterprise ? "sans-serif" : "Symbols Nerd Font Mono"
                                    font.pixelSize: networkRow.modelData.enterprise ? 9 : 11
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignRight
                                }

                            }

                            SharedUi.Pressable {
                                id: networkMouse

                                anchors.fill: parent
                                theme: networkPanel.theme
                                accessibleName: networkRow.modelData.active
                                    ? qsTr("Disconnect from %1").arg(networkRow.modelData.ssid)
                                    : qsTr("Select %1").arg(networkRow.modelData.ssid)
                                onClicked: {
                                    if (networkRow.modelData.active)
                                        networkPanel.disconnectNetwork(networkRow.modelData);
                                    else if (networkRow.modelData.enterprise)
                                        networkPanel.openAdvancedSettings();
                                    else
                                        networkPanel.chooseNetwork(networkRow.modelData);
                                }
                            }

                        }

                    }

                }

            }

        }

        Rectangle {
            width: parent.width
            height: selectedSsid !== "" ? 76 : 0
            visible: height > 0
            clip: true
            color: inkBg
            border.color: panelAccent
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                Row {
                    width: parent.width
                    height: 34
                    spacing: 7

                    Rectangle {
                        width: parent.width - 92
                        height: parent.height
                        color: panelBg
                        border.color: !selectedSecure ? hoverBg : (passwordInput.activeFocus ? panelAccent : mutedFg)
                        opacity: selectedSecure ? 1 : 0.7

                        TextInput {
                            id: passwordInput

                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            color: panelFg
                            enabled: selectedSecure
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            font.pixelSize: 12
                            Keys.onReturnPressed: connectSelected()

                            Text {
                                anchors.fill: parent
                                visible: passwordInput.text === ""
                                text: selectedSecure ? "Wi-Fi password" : "No password required"
                                color: mutedFg
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 11
                            }

                        }

                    }

                    Rectangle {
                        width: 85
                        height: parent.height
                        color: panelAccent

                        Text {
                            anchors.centerIn: parent
                            text: connecting ? "Connecting..." : "Connect"
                            color: panelBg
                            font.pixelSize: 11
                            font.bold: true
                        }

                        SharedUi.Pressable {
                            anchors.fill: parent
                            enabled: !connecting
                            theme: networkPanel.theme
                            accessibleName: qsTr("Connect to %1").arg(networkPanel.selectedSsid)
                            onClicked: connectSelected()
                        }

                    }

                }

                Text {
                    width: parent.width
                    text: errorMessage !== "" ? errorMessage : "Connect to " + selectedSsid + "  ·  Select again to cancel"
                    color: errorMessage !== "" ? panelAccent : mutedFg
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

            }

        }

    }

    ThroughputController {
        id: throughput

        active: networkPanel.active
        device: statusController ? statusController.device : ""
    }

    NetworkController {
        id: controller
        backend: networkPanel.backend
        statusController: networkPanel.statusController
        active: networkPanel.active
        onConnectionSucceeded: {
            networkPanel.selectedSsid = "";
            passwordInput.text = "";
        }
        onAdvancedSettingsOpened: networkPanel.closeRequested()
    }

}

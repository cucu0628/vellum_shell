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
    readonly property alias radioBusy: controller.radioBusy
    readonly property alias scanning: controller.scanning
    readonly property alias connecting: controller.connecting
    property bool selectedSecure: false
    readonly property alias busySsid: controller.busySsid
    property string selectedSsid: ""
    property alias errorMessage: controller.errorMessage
    readonly property alias networks: controller.networks
    // Allapotkartya (72) + szakaszcim (28) + ket koz; alatta legfeljebb ot sor,
    // a kivalasztott halozatnal pedig a jelszolap.
    readonly property int preferredHeight: 124 + Math.max(112, Math.min(networks.length, 5) * 56) + (selectedSsid !== "" ? 88 : 0)
    readonly property string panelBg: theme ? theme.background : "#15110f"
    readonly property string panelFg: theme ? theme.foreground : "#f1e7d0"
    readonly property string panelAccent: theme ? theme.accent : "#d7472f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#9f8f7c"
    readonly property string inkBg: theme && theme.surface ? theme.surface : "#1b1613"
    readonly property bool connected: statusController ? statusController.connected : false
    readonly property bool ethernet: statusController ? statusController.connectionType === "ethernet" : false

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

        SharedUi.StatusCard {
            width: parent.width
            theme: networkPanel.theme
            active: networkPanel.connected
            glyph: networkPanel.ethernet ? "󰈀" : (networkPanel.connected ? "󰤨" : "󰤭")
            title: networkPanel.connected
                ? (networkPanel.ethernet ? "Ethernet" : statusController.connectionName)
                : "No connection"
            subtitle: (statusController && statusController.device !== "" ? statusController.device + "  ·  " : "")
                + (statusController && statusController.lanIp !== "" ? statusController.lanIp : "No address")
            trailingWidth: 84

            // Live throughput of the interface the connection runs on.
            Column {
                anchors.fill: parent
                spacing: 4

                Repeater {
                    model: [{
                        "arrow": "↓",
                        "down": true
                    }, {
                        "arrow": "↑",
                        "down": false
                    }]

                    Item {
                        required property var modelData

                        width: parent.width
                        height: (parent.height - 4) / 2

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData.arrow
                            color: mutedFg
                            font.pixelSize: 11
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: throughput.format(parent.modelData.down ? throughput.downRate : throughput.upRate)
                            color: parent.modelData.down ? panelFg : mutedFg
                            font.family: "monospace"
                            font.pixelSize: 11
                        }

                    }

                }

            }

        }

        SharedUi.SectionBar {
            width: parent.width
            theme: networkPanel.theme
            title: "NETWORKS"
            detail: !wifiEnabled ? "" : (scanning ? "Scanning…" : String(networks.length))

            SharedUi.HeaderChip {
                theme: networkPanel.theme
                label: "Refresh"
                enabled: wifiEnabled && !scanning
                accessibleName: qsTr("Refresh Wi-Fi networks")
                onClicked: controller.refresh()
            }

            SharedUi.HeaderChip {
                theme: networkPanel.theme
                label: "Settings"
                accessibleName: qsTr("Open network settings")
                onClicked: openAdvancedSettings()
            }

        }

        Item {
            width: parent.width
            height: parent.height - 124 - (selectedSsid !== "" ? 88 : 0)

            Text {
                anchors.centerIn: parent
                width: parent.width - 32
                visible: !wifiEnabled || (!scanning && networks.length === 0)
                text: wifiEnabled ? "No networks found. Try refreshing." : "Turn on Wi-Fi to see networks."
                color: mutedFg
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
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

                        SharedUi.ListRow {
                            id: networkRow

                            required property var modelData
                            readonly property bool chosen: networkPanel.selectedSsid === modelData.ssid

                            width: networkColumn.width
                            theme: networkPanel.theme
                            glyph: networkPanel.signalIcon(modelData.signal)
                            title: modelData.ssid
                            subtitle: modelData.active
                                ? "Connected  ·  " + modelData.signal + "%"
                                : modelData.signal + "%  ·  " + (modelData.secure ? modelData.security : "Open network")
                            trailing: modelData.active
                                ? (networkPanel.busySsid === modelData.ssid ? "Wait…" : "Disconnect")
                                : (modelData.enterprise ? "802.1X settings" : (chosen && networkPanel.connecting ? "Connecting…" : "Connect"))
                            active: modelData.active
                            selected: chosen
                            accessibleName: modelData.active
                                ? qsTr("Disconnect from %1").arg(modelData.ssid)
                                : qsTr("Select %1").arg(modelData.ssid)
                            onClicked: {
                                if (modelData.active)
                                    networkPanel.disconnectNetwork(modelData);
                                else if (modelData.enterprise)
                                    networkPanel.openAdvancedSettings();
                                else
                                    networkPanel.chooseNetwork(modelData);
                            }
                        }

                    }

                }

            }

        }

        // A kivalasztott halozat jelszolapja: ugyanaz a kartyafelulet, benne a
        // mezo es a kiemelt Connect.
        Rectangle {
            width: parent.width
            height: selectedSsid !== "" ? 76 : 0
            visible: height > 0
            clip: true
            radius: 10
            color: inkBg

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                Row {
                    width: parent.width
                    height: 36
                    spacing: 8

                    SharedUi.SearchField {
                        id: passwordInput

                        width: parent.width - connectChip.width - parent.spacing
                        height: parent.height
                        enabled: selectedSecure
                        opacity: selectedSecure ? 1 : 0.7
                        indicator: ""
                        inputLeftMargin: 12
                        inputVerticalPadding: 8
                        echoMode: TextInput.Password
                        placeholder: selectedSecure ? "Wi-Fi password" : "No password required"
                        foreground: panelFg
                        accent: panelAccent
                        muted: mutedFg
                        surface: panelBg
                        onKeyPressed: (event) => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                connectSelected();
                                event.accepted = true;
                            }
                        }
                    }

                    SharedUi.HeaderChip {
                        id: connectChip

                        width: 104
                        height: parent.height
                        theme: networkPanel.theme
                        emphasized: true
                        enabled: !connecting
                        label: connecting ? "Connecting…" : "Connect"
                        accessibleName: qsTr("Connect to %1").arg(networkPanel.selectedSsid)
                        onClicked: connectSelected()
                    }

                }

                Text {
                    width: parent.width
                    text: errorMessage !== "" ? errorMessage : "Connect to " + selectedSsid + "  ·  select it again to cancel"
                    textFormat: Text.PlainText
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

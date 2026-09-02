import QtQuick
import "../../ui" as SharedUi

// Proton VPN half of the connectivity panel. Proton VPN does not expose
// activatable NetworkManager profiles, so every action goes through the
// `protonvpn` CLI in VpnController, which also keeps the state cached while this
// panel is unloaded. The CLI is only asked anything while `active`, so sitting
// on the network tab costs nothing.
Item {
    id: vpnPanel

    property var theme: null
    property var controller: null
    property bool active: false
    property string countryFilter: ""
    readonly property bool cliAvailable: controller ? controller.cliAvailable : true
    readonly property bool connected: controller ? controller.protonActive : false
    readonly property bool busy: controller ? controller.busy : false
    readonly property string action: controller ? controller.action : ""
    readonly property bool checking: controller ? controller.checking : false
    readonly property string server: controller ? controller.server : ""
    readonly property string location: controller ? controller.location : ""
    readonly property string load: controller ? controller.load : ""
    readonly property string protocol: controller ? controller.protocol : ""
    readonly property string publicIp: controller ? controller.publicIp : ""
    readonly property string killSwitch: controller ? controller.killSwitch : ""
    readonly property bool locationSelection: controller ? controller.locationSelection : false
    readonly property bool planKnown: controller ? controller.planKnown : false
    readonly property string errorMessage: controller ? controller.errorMessage : ""
    readonly property var countries: controller ? controller.countries : []
    readonly property int preferredHeight: locationSelection ? 504 : 350
    readonly property var visibleCountries: {
        if (countryFilter === "")
            return countries;

        var needle = countryFilter.toLowerCase();
        return countries.filter((country) => {
            return country.name.toLowerCase().indexOf(needle) !== -1 || country.code.toLowerCase().indexOf(needle) === 0;
        });
    }
    readonly property string panelBg: theme ? theme.background : "#15110f"
    readonly property string panelFg: theme ? theme.foreground : "#f1e7d0"
    readonly property string panelAccent: theme ? theme.accent : "#d7472f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#9f8f7c"
    readonly property string inkBg: theme && theme.surface ? theme.surface : "#1b1613"
    readonly property color hoverBg: Qt.rgba(1, 1, 1, 0.075)

    signal closeRequested()

    function refresh() {
        if (!controller)
            return ;

        controller.errorMessage = "";
        controller.refreshDetails(true);
        controller.refreshConfig(true);
    }

    function primaryAction() {
        if (!controller)
            return ;

        if (connected)
            controller.disconnectVpn();
        else
            controller.connectFastest();
    }

    function openProtonApp() {
        if (!controller)
            return ;

        controller.openApp();
        closeRequested();
    }

    onActiveChanged: {
        if (controller)
            controller.panelOpen = active;

        if (active) {
            if (controller)
                controller.panelOpened();

        } else {
            countryFilter = "";
        }
    }

    Column {
        anchors.fill: parent
        spacing: 12

        SharedUi.PopupHeader {
            width: parent.width
            theme: vpnPanel.theme
            title: "Proton VPN"
            subtitle: !cliAvailable
                ? "protonvpn CLI not found"
                : (busy
                    ? (action === "connect" ? "Connecting..." : "Disconnecting...")
                    : (connected
                        ? "Connected" + (protocol !== "" ? "  ·  " + protocol : "") + (checking ? "  ·  updating" : "")
                        : "Disconnected"))
            trailingWidth: 47

            Rectangle {
                anchors.fill: parent
                anchors.bottomMargin: 4
                color: connected ? panelAccent : inkBg
                border.color: connected ? panelAccent : mutedFg

                Text {
                    anchors.centerIn: parent
                    text: connected ? "ON" : "OFF"
                    color: connected ? panelBg : mutedFg
                    font.family: "monospace"
                    font.pixelSize: 8
                    font.bold: true
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
                color: connected ? panelAccent : mutedFg
            }

            Row {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Text {
                    width: 34
                    anchors.verticalCenter: parent.verticalCenter
                    text: connected ? "󰦝" : "󰦜"
                    color: connected ? panelAccent : mutedFg
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 25
                }

                Column {
                    width: parent.width - 46
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        width: parent.width
                        text: connected ? (location !== "" ? location : server) : "Traffic is not tunnelled"
                        color: panelFg
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: {
                            if (!connected)
                                return cliAvailable ? "Quick connect picks the fastest server" : "Install proton-vpn-cli to control the VPN here";

                            var parts = [];
                            // The title already shows the server name
                            // while the location is still unknown.
                            if (server !== "" && location !== "")
                                parts.push(server);

                            if (load !== "")
                                parts.push("Load " + load);

                            if (publicIp !== "")
                                parts.push(publicIp);

                            if (parts.length > 0)
                                return parts.join("  ·  ");

                            // The CLI reports nothing about tunnels the
                            // Proton app brought up on its own.
                            return checking ? "Reading server details..." : "Connected outside the CLI  ·  no details";
                        }
                        color: mutedFg
                        font.pixelSize: 12
                        font.letterSpacing: 0.5
                        elide: Text.ElideRight
                    }

                }

            }

        }

        Rectangle {
            width: parent.width
            height: 40
            color: connected ? inkBg : panelAccent
            border.color: panelAccent
            border.width: 1
            opacity: cliAvailable && !busy ? 1 : 0.55

            Text {
                anchors.centerIn: parent
                text: busy
                    ? (action === "connect" ? "CONNECTING..." : "DISCONNECTING...")
                    : (connected ? "DISCONNECT" : "QUICK CONNECT")
                color: connected ? panelAccent : panelBg
                font.family: "monospace"
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 2
            }

            MouseArea {
                anchors.fill: parent
                enabled: cliAvailable && !busy
                cursorShape: Qt.PointingHandCursor
                onClicked: primaryAction()
            }

        }

        Row {
            width: parent.width
            height: 28

            Text {
                width: parent.width - 170
                height: parent.height
                text: locationSelection ? "COUNTRIES  ·  " + countries.length : "SERVER"
                color: panelAccent
                font.family: "monospace"
                font.pixelSize: 8
                font.letterSpacing: 2
                font.bold: true
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                width: 100
                height: parent.height
                text: "Open app"
                color: appMouse.containsMouse ? panelAccent : mutedFg
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 10
                font.family: "monospace"

                MouseArea {
                    id: appMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: openProtonApp()
                }

            }

            Text {
                width: 70
                height: parent.height
                text: "Refresh"
                color: refreshMouse.containsMouse ? panelAccent : mutedFg
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 10
                font.family: "monospace"

                MouseArea {
                    id: refreshMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: refresh()
                }

            }

        }

        Item {
            width: parent.width
            height: parent.height - 282 - (errorLine.visible ? 26 : 0)

            Text {
                anchors.centerIn: parent
                width: parent.width - 10
                visible: !locationSelection
                text: !cliAvailable
                    ? "The protonvpn command is missing. Install the proton-vpn-cli package to connect from here."
                    : (planKnown
                        ? "Free plan: Proton picks the fastest free server automatically. Location selection needs VPN Plus."
                        : "Reading plan details...")
                color: mutedFg
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Column {
                anchors.fill: parent
                visible: locationSelection
                spacing: 8

                Rectangle {
                    width: parent.width
                    height: 30
                    color: inkBg
                    border.color: filterInput.activeFocus ? panelAccent : "transparent"

                    TextInput {
                        id: filterInput

                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        color: panelFg
                        verticalAlignment: TextInput.AlignVCenter
                        font.pixelSize: 12
                        onTextChanged: vpnPanel.countryFilter = text
                        Keys.onEscapePressed: text = ""

                        Text {
                            anchors.fill: parent
                            visible: filterInput.text === ""
                            text: "Search country"
                            color: mutedFg
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 11
                        }

                    }

                }

                Flickable {
                    width: parent.width
                    height: parent.height - 38
                    contentHeight: countryColumn.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: countryColumn

                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: visibleCountries

                            Rectangle {
                                width: countryColumn.width
                                height: 40
                                color: countryMouse.containsMouse ? inkBg : "transparent"

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Text {
                                        width: 30
                                        height: parent.height
                                        text: modelData.code
                                        color: panelAccent
                                        font.family: "monospace"
                                        font.pixelSize: 10
                                        font.bold: true
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Text {
                                        width: parent.width - 130
                                        height: parent.height
                                        text: modelData.name
                                        color: panelFg
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Text {
                                        width: 70
                                        height: parent.height
                                        text: "Connect"
                                        color: countryMouse.containsMouse ? panelAccent : mutedFg
                                        font.pixelSize: 11
                                        horizontalAlignment: Text.AlignRight
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                }

                                MouseArea {
                                    id: countryMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !vpnPanel.busy
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: vpnPanel.controller.connectCountry(modelData.code)
                                }

                            }

                        }

                    }

                }

            }

        }

        Row {
            width: parent.width
            height: 30
            spacing: 10

            Text {
                width: parent.width - 90
                height: parent.height
                // `protonvpn config set` is broken in the CLI (it always
                // reports an unexpected error), so this only reports the
                // value the CLI hands back.
                text: "KILL SWITCH  ·  change it in the Proton app"
                color: mutedFg
                font.family: "monospace"
                font.pixelSize: 8
                font.letterSpacing: 1
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            Rectangle {
                width: 80
                height: 26
                anchors.verticalCenter: parent.verticalCenter
                color: killSwitch !== "" && killSwitch !== "off" ? panelAccent : inkBg
                border.color: killSwitch !== "" && killSwitch !== "off" ? panelAccent : mutedFg
                opacity: killSwitch === "" ? 0.55 : 1

                Text {
                    anchors.centerIn: parent
                    text: killSwitch === "" ? "..." : (killSwitch === "off" ? "OFF" : killSwitch.toUpperCase())
                    color: killSwitch !== "" && killSwitch !== "off" ? panelBg : mutedFg
                    font.family: "monospace"
                    font.pixelSize: 8
                    font.bold: true
                }

            }

        }

        Text {
            id: errorLine

            width: parent.width
            height: 14
            visible: errorMessage !== ""
            text: errorMessage
            color: panelAccent
            font.pixelSize: 10
            elide: Text.ElideRight
        }

    }

}

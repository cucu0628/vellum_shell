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
    // Allapotkartya, fo gomb, szakaszcim es a kill switch sor (212) + a lista
    // vagy a tajekoztato szoveg.
    readonly property int preferredHeight: 212 + (locationSelection ? 240 : 68)
    readonly property var visibleCountries: {
        if (countryFilter === "")
            return countries;

        var needle = countryFilter.toLowerCase();
        return countries.filter((country) => {
            return country.name.toLowerCase().indexOf(needle) !== -1 || country.code.toLowerCase().indexOf(needle) === 0;
        });
    }
    readonly property string panelFg: theme ? theme.foreground : "#f1e7d0"
    readonly property string panelAccent: theme ? theme.accent : "#d7472f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#9f8f7c"
    readonly property string inkBg: theme && theme.surface ? theme.surface : "#1b1613"
    readonly property bool killSwitchOn: killSwitch !== "" && killSwitch !== "off"

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
            filterInput.text = "";
            countryFilter = "";
        }
    }

    Column {
        anchors.fill: parent
        spacing: 12

        SharedUi.StatusCard {
            width: parent.width
            theme: vpnPanel.theme
            active: connected
            glyph: connected ? "󰦝" : "󰦜"
            title: !cliAvailable
                ? "protonvpn CLI not found"
                : (busy
                    ? (action === "connect" ? "Connecting…" : "Disconnecting…")
                    : (connected ? (location !== "" ? location : server) : "Traffic is not tunnelled"))
            subtitle: {
                if (!cliAvailable)
                    return "Install proton-vpn-cli to control the VPN here";

                if (!connected)
                    return "Quick connect picks the fastest server";

                var parts = [];
                // The title already shows the server name
                // while the location is still unknown.
                if (server !== "" && location !== "")
                    parts.push(server);

                if (protocol !== "")
                    parts.push(protocol);

                if (load !== "")
                    parts.push("Load " + load);

                if (publicIp !== "")
                    parts.push(publicIp);

                if (parts.length > 0)
                    return parts.join("  ·  ");

                // The CLI reports nothing about tunnels the
                // Proton app brought up on its own.
                return checking ? "Reading server details…" : "Connected outside the CLI  ·  no details";
            }
        }

        // Csatlakozas kiemelt (akcentes) gomb, bontas csendes, telt gomb.
        SharedUi.HeaderChip {
            width: parent.width
            height: 36
            theme: vpnPanel.theme
            emphasized: !connected
            filled: connected
            enabled: cliAvailable && !busy
            label: busy
                ? (action === "connect" ? "Connecting…" : "Disconnecting…")
                : (connected ? "Disconnect" : "Quick connect")
            onClicked: primaryAction()
        }

        SharedUi.SectionBar {
            width: parent.width
            theme: vpnPanel.theme
            title: locationSelection ? "COUNTRIES" : "SERVER"
            detail: locationSelection ? String(countries.length) : (checking ? "Updating…" : "")

            SharedUi.HeaderChip {
                theme: vpnPanel.theme
                label: "Refresh"
                accessibleName: qsTr("Refresh VPN status")
                onClicked: refresh()
            }

            SharedUi.HeaderChip {
                theme: vpnPanel.theme
                label: "Open app"
                accessibleName: qsTr("Open the Proton VPN app")
                onClicked: openProtonApp()
            }

        }

        Item {
            width: parent.width
            height: parent.height - 212 - (errorLine.visible ? 26 : 0)

            Text {
                anchors.centerIn: parent
                width: parent.width - 32
                visible: !locationSelection
                text: !cliAvailable
                    ? "The protonvpn command is missing. Install the proton-vpn-cli package to connect from here."
                    : (planKnown
                        ? "Free plan: Proton picks the fastest free server automatically. Location selection needs VPN Plus."
                        : "Reading plan details…")
                color: mutedFg
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Column {
                anchors.fill: parent
                visible: locationSelection
                spacing: 8

                SharedUi.SearchField {
                    id: filterInput

                    width: parent.width
                    height: 36
                    inputVerticalPadding: 8
                    placeholder: "Search country"
                    foreground: panelFg
                    accent: panelAccent
                    muted: mutedFg
                    surface: inkBg
                    onTextEdited: (text) => vpnPanel.countryFilter = text
                    onKeyPressed: (event) => {
                        if (event.key === Qt.Key_Escape && filterInput.text !== "") {
                            filterInput.text = "";
                            event.accepted = true;
                        }
                    }
                }

                Flickable {
                    width: parent.width
                    height: parent.height - 44
                    contentHeight: countryColumn.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: countryColumn

                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: visibleCountries

                            SharedUi.ListRow {
                                required property var modelData

                                width: countryColumn.width
                                height: 44
                                theme: vpnPanel.theme
                                glyph: modelData.code
                                glyphFamily: "monospace"
                                glyphSize: 10
                                title: modelData.name
                                trailing: "Connect"
                                enabled: !vpnPanel.busy
                                accessibleName: qsTr("Connect to %1").arg(modelData.name)
                                onClicked: vpnPanel.controller.connectCountry(modelData.code)
                            }

                        }

                    }

                }

            }

        }

        // `protonvpn config set` is broken in the CLI (it always reports an
        // unexpected error), so this only reports the value the CLI hands back.
        Item {
            width: parent.width
            height: 28

            Text {
                anchors.left: parent.left
                anchors.right: killSwitchValue.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "Kill switch  ·  change it in the Proton app"
                color: mutedFg
                font.pixelSize: 10
                elide: Text.ElideRight
            }

            Text {
                id: killSwitchValue

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: killSwitch === "" ? "…" : (killSwitch === "off" ? "Off" : killSwitch.charAt(0).toUpperCase() + killSwitch.slice(1))
                color: killSwitchOn ? panelAccent : mutedFg
                font.pixelSize: 11
                font.weight: killSwitchOn ? Font.Medium : Font.Normal
            }

        }

        Text {
            id: errorLine

            width: parent.width
            height: 14
            visible: errorMessage !== ""
            text: errorMessage
            textFormat: Text.PlainText
            color: panelAccent
            font.pixelSize: 10
            elide: Text.ElideRight
        }

    }

}

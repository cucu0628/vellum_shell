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
    // Allapotsor (44); CLI-vel a fo gomb (8 + 36), ket elvalaszto (2 x 25),
    // a kill switch sor (32), kozottuk az orszaglista (36 + 240) vagy a
    // tajekoztato mondat (36), alul a hibasor.
    readonly property int preferredHeight: !cliAvailable
        ? 44
        : 44 + 44 + 50 + 32 + (locationSelection ? 276 : 36) + (errorMessage !== "" ? 18 : 0)
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

        SharedUi.StatusRow {
            width: parent.width
            theme: vpnPanel.theme
            active: connected
            glyph: connected ? "󰦝" : "󰦜"
            title: !cliAvailable
                ? "Proton VPN CLI not installed"
                : (busy
                    ? (action === "connect" ? "Connecting…" : "Disconnecting…")
                    : (connected ? (location !== "" ? location : server) : "Not connected"))
            subtitle: {
                if (!cliAvailable)
                    return "Install proton-vpn-cli to connect from here";

                if (!connected)
                    return busy ? "" : "Traffic leaves without a tunnel";

                var parts = [];
                // The title already shows the server name
                // while the location is still unknown.
                if (server !== "" && location !== "")
                    parts.push(server);

                if (protocol !== "")
                    parts.push(protocol);

                if (load !== "")
                    parts.push("load " + load);

                if (publicIp !== "")
                    parts.push(publicIp);

                if (parts.length > 0)
                    return parts.join(", ");

                // The CLI reports nothing about tunnels the
                // Proton app brought up on its own.
                return checking ? "Reading server details…" : "Connected outside the CLI, no details";
            }
        }

        Item {
            width: 1
            height: 8
            visible: cliAvailable
        }

        // Csatlakozas kiemelt (akcentes) gomb, bontas csendes, telt gomb.
        SharedUi.HeaderChip {
            width: parent.width
            height: 36
            visible: cliAvailable
            theme: vpnPanel.theme
            emphasized: !connected
            filled: connected
            enabled: !busy
            label: busy
                ? (action === "connect" ? "Connecting…" : "Disconnecting…")
                : (connected ? "Disconnect" : "Quick connect")
            onClicked: primaryAction()
        }

        SharedUi.GroupDivider {
            width: parent.width
            visible: cliAvailable
            theme: vpnPanel.theme
        }

        // Ingyenes csomagnal nincs orszagvalasztas: egy mondat mondja el, miert.
        Text {
            width: parent.width
            height: 36
            visible: cliAvailable && !locationSelection
            verticalAlignment: Text.AlignVCenter
            text: planKnown
                ? "The free plan connects to the fastest free server. Choosing a country needs VPN Plus."
                : "Reading plan details…"
            color: mutedFg
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Column {
            width: parent.width
            height: 276
            visible: cliAvailable && locationSelection
            spacing: 8

            SharedUi.SearchField {
                id: filterInput

                width: parent.width
                height: 36
                inputVerticalPadding: 8
                placeholder: qsTr("Search %1 countries").arg(countries.length)
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

        SharedUi.GroupDivider {
            width: parent.width
            visible: cliAvailable
            theme: vpnPanel.theme
        }

        // `protonvpn config set` is broken in the CLI (it always reports an
        // unexpected error), so this only reports the value the CLI hands back.
        Item {
            width: parent.width
            height: 32
            visible: cliAvailable

            Column {
                anchors.left: parent.left
                anchors.right: killSwitchValue.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: "Kill switch"
                    color: panelFg
                    font.pixelSize: 12
                }

                Text {
                    width: parent.width
                    text: "Change it in the Proton app"
                    color: mutedFg
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

            }

            Text {
                id: killSwitchValue

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: killSwitch === "" ? "…" : (killSwitch === "off" ? "Off" : killSwitch.charAt(0).toUpperCase() + killSwitch.slice(1))
                color: killSwitchOn ? panelAccent : mutedFg
                font.pixelSize: 12
                font.weight: killSwitchOn ? Font.Medium : Font.Normal
            }

        }

        Text {
            id: errorLine

            width: parent.width
            height: 18
            visible: cliAvailable && errorMessage !== ""
            verticalAlignment: Text.AlignBottom
            text: errorMessage
            textFormat: Text.PlainText
            color: panelAccent
            font.pixelSize: 10
            elide: Text.ElideRight
        }

    }

}

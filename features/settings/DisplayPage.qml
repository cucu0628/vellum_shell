pragma ComponentBehavior: Bound

import QtQuick
import "../../ui" as SharedUi

// Kijelzo-beallitasok. A monitorvaltas mindig visszaszamlalassal jar: egy rossz
// mod vagy pozicio sotet kepernyot hagyhat, amit mar nem lehet visszakattintani,
// ezert megerosites nelkul magatol visszaall.
//
// Magat a tranzakciot a backend birtokolja (`hypr.previewMonitors`), ez az
// oldal csak megjeleniti: igy az oldalvaltas vagy az ablak bezarasa sem
// hagyhat allva egy meg nem erositett beallitast.
Item {
    id: page

    required property var controller
    property var theme: null

    // A vasznon vegzett huzas csak elonezet. Apply utan kerul a backendhez.
    property var pendingArrangement: null
    property bool applyingArrangement: false
    // A backend legutobbi elutasitasa (ervenytelen mod, atfedes, ...).
    property string errorMessage: ""

    readonly property bool awaitingConfirmation: controller.previewToken !== ""

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string errorColor: "#d7472f"
    readonly property var monitor: controller.selectedMonitor
    readonly property int activeMonitorCount: {
        var count = 0;
        for (var i = 0; i < controller.monitors.length; i++) {
            if (controller.monitors[i].disabled !== true)
                count++;
        }
        return count;
    }

    // A `hyprctl monitors` friss modjai, "1920x1080@144.00Hz" alakban. Az
    // ismetlodo frissitesi ratakat kiszurjuk, mert a lista kulonben tucatnyi
    // gyakorlatilag azonos sort tartalmaz.
    readonly property var modeOptions: {
        if (!monitor || !monitor.availableModes)
            return [];

        var seen = ({});
        var result = [];
        for (var i = 0; i < monitor.availableModes.length; i++) {
            var raw = monitor.availableModes[i].toString();
            var parts = raw.split("@");
            if (parts.length < 2)
                continue;

            var hertz = Math.round(parseFloat(parts[1]));
            var value = parts[0] + "@" + hertz;
            if (seen[value])
                continue;

            seen[value] = true;
            result.push({
                "label": parts[0] + "  " + hertz + " Hz",
                "value": value
            });
        }
        return result;
    }

    readonly property string currentMode: {
        if (!monitor)
            return "";

        return monitor.width + "x" + monitor.height + "@" + Math.round(monitor.refreshRate);
    }

    // Egy teljes MonitorSetting az aktualis allapotbol, egy mezot felulirva.
    function settingForMonitor(source, overrides) {
        if (!source)
            return null;

        var setting = {
            "output": source.name,
            "mode": source.width + "x" + source.height + "@" + Math.round(source.refreshRate),
            "position": source.x + "x" + source.y,
            "scale": source.scale > 0 ? source.scale : 1,
            "transform": source.transform || 0,
            "vrr": source.vrr ? 1 : 0,
            "disabled": source.disabled === true
        };
        for (var key in overrides) setting[key] = overrides[key]
        return setting;
    }

    function settingFor(overrides) {
        return settingForMonitor(monitor, overrides);
    }

    function monitorForOutput(output) {
        for (var i = 0; i < controller.monitors.length; i++) {
            if (controller.monitors[i].name === output)
                return controller.monitors[i];
        }
        return null;
    }

    // Kockazatos valtoztatas: a backend alkalmazza eloben, elteszi a korabbi
    // allapotot, es megerosites nelkul visszaallitja.
    function applyWithRevert(overrides) {
        var next = settingFor(overrides);
        if (!next)
            return ;

        page.errorMessage = "";
        page.controller.previewMonitors([next], null);
    }

    // A huzas utan az egesz elrendezest ujraszamoljuk, es a bal felso sarkot
    // 0,0-ra toljuk. Enelkul minden huzas tovabb csusztatna az asztalt negativ
    // koordinatak fele: a Hyprland ezt elfogadja, de a tarolt ertekek egyre
    // ertelmetlenebbek lennenek, es a ket kijelzo kozti tavolsag maradna csak
    // helyes.
    function normalizedLayout(output, x, y) {
        var boxes = [];
        var minX = null;
        var minY = null;
        for (var i = 0; i < controller.monitors.length; i++) {
            var source = controller.monitors[i];
            if (source.disabled === true)
                continue;

            var px = source.name === output ? x : source.x;
            var py = source.name === output ? y : source.y;
            boxes.push({
                "source": source,
                "x": px,
                "y": py
            });
            if (minX === null || px < minX)
                minX = px;

            if (minY === null || py < minY)
                minY = py;

        }
        var result = [];
        for (var j = 0; j < boxes.length; j++) result.push(settingForMonitor(boxes[j].source, {
            "position": (boxes[j].x - minX) + "x" + (boxes[j].y - minY)
        }))
        return result;
    }

    function stageMove(output, x, y) {
        var source = monitorForOutput(output);
        if (!source)
            return;

        var layout = normalizedLayout(output, x, y);
        if (layout.length === 0)
            return;

        var moved = null;
        for (var j = 0; j < layout.length; j++) {
            if (layout[j].output === output)
                moved = layout[j];

        }

        // A visszaallitando allapotot a backend rogziti, amikor az elonezet
        // elindul -- itt csak azt tartjuk, amit alkalmazni akarunk.
        pendingArrangement = {
            "output": output,
            "position": moved ? moved.position : x + "x" + y,
            "next": layout
        };
    }

    function cancelPendingArrangement() {
        pendingArrangement = null;
        monitorCanvas.clearOverrides();
    }

    function applyPendingArrangement() {
        var pending = pendingArrangement;
        if (!pending || applyingArrangement)
            return;

        applyingArrangement = true;
        page.errorMessage = "";
        page.controller.previewMonitors(pending.next, () => {
            page.applyingArrangement = false;
            page.cancelPendingArrangement();
        });
    }

    Connections {
        function onPreviewFailed(message) {
            page.errorMessage = message;
        }

        target: page.controller
    }

    Flickable {
        id: settingsFlickable

        anchors.fill: parent
        contentWidth: width
        contentHeight: column.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column

            width: settingsFlickable.width
            spacing: 0

            SettingsSection {
                width: parent.width
                theme: page.theme
                title: "Display arrangement"
                description: "Place active outputs in the shared workspace"
            }

        Text {
            width: parent.width
            text: "Drag a display to move it. Released edges snap to the neighbouring display."
            color: page.muted
            font.pixelSize: 10
            wrapMode: Text.WordWrap
            bottomPadding: 8
        }

        MonitorCanvas {
            id: monitorCanvas

            width: parent.width
            height: 190
            enabled: !page.applyingArrangement
            theme: page.theme
            monitors: page.controller.monitors
            selectedOutput: page.controller.selectedOutput
            onSelected: (output) => page.controller.selectedOutput = output
            onMoved: (output, x, y) => page.stageMove(output, x, y)
            onPreviewCleared: page.pendingArrangement = null
        }

        Item {
            width: parent.width
            height: 42

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.rightMargin: 190
                anchors.verticalCenter: parent.verticalCenter
                text: page.errorMessage !== ""
                    ? page.errorMessage
                    : (page.pendingArrangement
                        ? (page.applyingArrangement
                            ? "Applying " + page.pendingArrangement.output + " at " + page.pendingArrangement.position + "…"
                            : page.pendingArrangement.output + " staged at " + page.pendingArrangement.position)
                        : "Drag a display, then press Apply.")
                color: page.errorMessage !== ""
                    ? page.errorColor
                    : (page.pendingArrangement ? page.foreground : page.muted)
                font.family: "monospace"
                font.pixelSize: 10
                elide: Text.ElideRight
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                SharedUi.ActionButton {
                    visible: page.pendingArrangement !== null
                    enabled: !page.applyingArrangement
                    opacity: enabled ? 1 : 0.4
                    theme: page.theme
                    label: "Cancel"
                    onClicked: page.cancelPendingArrangement()
                }

                SharedUi.ActionButton {
                    enabled: page.pendingArrangement !== null && !page.applyingArrangement
                    opacity: enabled ? 1 : 0.4
                    theme: page.theme
                    label: page.applyingArrangement ? "Applying…" : "Apply"
                    primary: true
                    onClicked: page.applyPendingArrangement()
                }
            }
        }

            SettingsSection {
                width: parent.width
                theme: page.theme
                title: page.monitor ? page.monitor.name : "Display"
                description: "Mode and output-specific rendering controls"
            }

            SharedUi.SettingRow {
            theme: page.theme
            enabled: page.monitor !== null
            label: "Resolution and refresh rate"
            description: "Applied immediately; reverts on its own unless you confirm."
            showDescription: true

            SharedUi.SettingSelect {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                theme: page.theme
                model: page.modeOptions
                value: page.currentMode
                onActivated: (value) => page.applyWithRevert({
                    "mode": value
                })
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            enabled: page.monitor !== null
            label: "Scale"
            description: "Fractional scales can blur applications that do not support them."
            showDescription: true

            SharedUi.SettingSelect {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                theme: page.theme
                model: [{
                    "label": "100%",
                    "value": "1"
                }, {
                    "label": "125%",
                    "value": "1.25"
                }, {
                    "label": "150%",
                    "value": "1.5"
                }, {
                    "label": "175%",
                    "value": "1.75"
                }, {
                    "label": "200%",
                    "value": "2"
                }]
                value: page.monitor ? page.monitor.scale.toString() : "1"
                onActivated: (value) => page.applyWithRevert({
                    "scale": Number(value)
                })
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            enabled: page.monitor !== null
            label: "Orientation"
            description: "Rotates the display output."

            SharedUi.SettingSelect {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                theme: page.theme
                model: [{
                    "label": "Landscape",
                    "value": "0"
                }, {
                    "label": "Portrait",
                    "value": "1"
                }, {
                    "label": "Landscape (flipped)",
                    "value": "2"
                }, {
                    "label": "Portrait (flipped)",
                    "value": "3"
                }]
                value: page.monitor ? (page.monitor.transform || 0).toString() : "0"
                onActivated: (value) => page.applyWithRevert({
                    "transform": Number(value)
                })
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            enabled: page.monitor !== null
            label: "Variable refresh rate"
            description: "Lets the display follow the render rate. Can flicker on some panels."
            showDescription: true

            SharedUi.SettingToggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                theme: page.theme
                checked: page.monitor ? page.monitor.vrr === true : false
                onToggled: (value) => page.applyWithRevert({
                    "vrr": value ? 1 : 0
                })
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            // Az utolso aktiv kijelzot nem engedjuk kikapcsolni: utana nem
            // lenne mivel visszakapcsolni.
            enabled: page.monitor !== null && (page.activeMonitorCount > 1 || (page.monitor && page.monitor.disabled))
            label: "Enabled"
            description: "Turning a display off frees its workspaces for the others."

            SharedUi.SettingToggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                theme: page.theme
                checked: page.monitor ? page.monitor.disabled !== true : false
                onToggled: (value) => page.applyWithRevert({
                    "disabled": !value
                })
            }

            }

        }
    }

    // A megerosito sav. Modalis szandekkal ul a tartalom felett, de nem blokkolja
    // az ablakot -- csak ez a ket gomb szamit, amig fut.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 62
        visible: page.awaitingConfirmation
        color: page.theme && page.theme.surface ? page.theme.surface : "#1b1613"
        border.color: page.accent
        border.width: 2

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: "Keep these display settings?"
                color: page.foreground
                font.pixelSize: 13
            }

            Text {
                text: "Reverting in " + page.controller.previewSeconds + " s"
                color: page.muted
                font.family: "monospace"
                font.pixelSize: 10
            }

        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Rectangle {
                width: 84
                height: 30
                color: revertMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                border.color: page.muted
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "Revert"
                    color: page.foreground
                    font.pixelSize: 12
                }

                MouseArea {
                    id: revertMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.controller.revertPreview()
                }

            }

            Rectangle {
                width: 84
                height: 30
                color: page.accent

                Text {
                    anchors.centerIn: parent
                    text: "Keep"
                    color: page.theme ? page.theme.background : "#11130f"
                    font.pixelSize: 12
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.controller.confirmPreview()
                }

            }

        }

    }

}

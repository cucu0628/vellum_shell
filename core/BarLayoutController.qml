import QtQuick

// A topbar moduljainak kozos, monitorfuggetlen elrendezese. A teljes katalogus
// minden modulja pontosan egy zonaban szerepel; a `hidden` ugyanennek a negyedik,
// nem renderelt zonaja. Az elrendezes a `settings.json` `bar` szekcioja; a
// tarolo figyeli a fajlt, igy egy kulso szerkesztes is eloben megjelenik, de
// iras csak egy drag-and-drop muvelet utan tortenik.
Item {
    id: controller

    // A kozos `settings.json` (core/SettingsStore.qml).
    property var settings: null

    readonly property var moduleCatalog: [{
        "id": "workspaces",
        "label": "Workspaces",
        "icon": "󰍹",
        "defaultZone": "left"
    }, {
        "id": "privacy",
        "label": "Privacy",
        "icon": "󰒃",
        "defaultZone": "left"
    }, {
        "id": "clock",
        "label": "Clock / media",
        "icon": "󰥔",
        "defaultZone": "center"
    }, {
        "id": "tray",
        "label": "System tray",
        "icon": "󰀻",
        "defaultZone": "right"
    }, {
        "id": "connectivity",
        "label": "Network / VPN",
        "icon": "󰤨",
        "defaultZone": "right"
    }, {
        "id": "bluetooth",
        "label": "Bluetooth",
        "icon": "󰂯",
        "defaultZone": "right"
    }, {
        "id": "removable",
        "label": "Removable drives",
        "icon": "󰕓",
        "defaultZone": "right"
    }, {
        "id": "audio",
        "label": "Audio",
        "icon": "",
        "defaultZone": "right"
    }, {
        "id": "notifications",
        "label": "Notifications",
        "icon": "󰂞",
        "defaultZone": "right"
    }, {
        "id": "ai",
        "label": "AI usage",
        "icon": "󰚩",
        "defaultZone": "right"
    }, {
        "id": "system-monitor",
        "label": "System monitor",
        "icon": "󰍛",
        "defaultZone": "right"
    }, {
        "id": "battery",
        "label": "Battery",
        "icon": "󰁹",
        "defaultZone": "right"
    }]
    readonly property var zoneNames: ["left", "center", "right", "hidden"]

    property var leftModules: ["workspaces", "privacy"]
    property var centerModules: ["clock"]
    property var rightModules: ["tray", "connectivity", "bluetooth", "removable", "audio", "notifications", "ai", "system-monitor", "battery"]
    property var hiddenModules: []
    readonly property bool ready: settings !== null && settings.loaded
    property string errorMessage: ""

    width: 0
    height: 0
    visible: false

    function defaultLayout() {
        var result = {
            "left": [],
            "center": [],
            "right": [],
            "hidden": []
        };
        for (var i = 0; i < moduleCatalog.length; i++)
            result[moduleCatalog[i].defaultZone].push(moduleCatalog[i].id);
        return result;
    }

    function knownModule(id) {
        for (var i = 0; i < moduleCatalog.length; i++) {
            if (moduleCatalog[i].id === id)
                return true;
        }
        return false;
    }

    function moduleInfo(id) {
        for (var i = 0; i < moduleCatalog.length; i++) {
            if (moduleCatalog[i].id === id)
                return moduleCatalog[i];
        }
        return {
            "id": id,
            "label": id,
            "icon": "?",
            "defaultZone": "hidden"
        };
    }

    function items(zone) {
        if (zone === "left") return leftModules;
        if (zone === "center") return centerModules;
        if (zone === "right") return rightModules;
        return hiddenModules;
    }

    function sanitizedLayout(candidate) {
        var result = {
            "left": [],
            "center": [],
            "right": [],
            "hidden": []
        };
        var seen = {};
        for (var z = 0; z < zoneNames.length; z++) {
            var zone = zoneNames[z];
            var source = candidate && Array.isArray(candidate[zone]) ? candidate[zone] : [];
            for (var i = 0; i < source.length; i++) {
                var id = (source[i] || "").toString();
                if (!knownModule(id) || seen[id])
                    continue;
                seen[id] = true;
                result[zone].push(id);
            }
        }

        // Egy uj Vellum-verzio uj modulja regi config mellett se tunjon el.
        for (var j = 0; j < moduleCatalog.length; j++) {
            var module = moduleCatalog[j];
            if (!seen[module.id])
                result[module.defaultZone].push(module.id);
        }
        return result;
    }

    function applyLayout(layout) {
        leftModules = layout.left.slice();
        centerModules = layout.center.slice();
        rightModules = layout.right.slice();
        hiddenModules = layout.hidden.slice();
    }

    function currentLayout() {
        return {
            "left": leftModules,
            "center": centerModules,
            "right": rightModules,
            "hidden": hiddenModules
        };
    }

    // Barmelyik beallitas valtozasa uj `data`-t ad; a zonakat csak tenyleges
    // elteres eseten csereljuk, kulonben a sav modulai feleslegesen ujraepulnenek.
    function syncFromSettings() {
        if (!settings || !settings.loaded)
            return;
        if (settings.invalid) {
            errorMessage = "settings.json is invalid; the bar layout cannot be saved.";
            return;
        }
        var layout = sanitizedLayout(settings.section("bar"));
        if (JSON.stringify(layout) !== JSON.stringify(currentLayout()))
            applyLayout(layout);
        errorMessage = "";
    }

    function zoneOf(id) {
        for (var z = 0; z < zoneNames.length; z++) {
            var zone = zoneNames[z];
            if (items(zone).indexOf(id) >= 0)
                return zone;
        }
        return "";
    }

    function moveModule(id, targetZone, targetIndex) {
        if (!knownModule(id) || zoneNames.indexOf(targetZone) < 0)
            return;

        var layout = {
            "left": leftModules.slice(),
            "center": centerModules.slice(),
            "right": rightModules.slice(),
            "hidden": hiddenModules.slice()
        };
        var sourceZone = zoneOf(id);
        var sourceIndex = sourceZone === "" ? -1 : layout[sourceZone].indexOf(id);
        if (sourceIndex >= 0)
            layout[sourceZone].splice(sourceIndex, 1);

        var requestedIndex = Number(targetIndex);
        if (isNaN(requestedIndex))
            requestedIndex = layout[targetZone].length;
        if (sourceZone === targetZone && sourceIndex >= 0 && sourceIndex < requestedIndex)
            requestedIndex--;
        var index = Math.max(0, Math.min(layout[targetZone].length, Math.round(requestedIndex)));
        layout[targetZone].splice(index, 0, id);

        applyLayout(layout);
        errorMessage = "";
        saveTimer.restart();
    }

    function reset() {
        applyLayout(defaultLayout());
        errorMessage = "";
        saveTimer.restart();
    }

    function save() {
        if (!settings) {
            errorMessage = "The bar layout could not be saved.";
            return;
        }
        var layout = currentLayout();
        settings.setSection("bar", {
            "left": layout.left.slice(),
            "center": layout.center.slice(),
            "right": layout.right.slice(),
            "hidden": layout.hidden.slice()
        });
    }

    Timer {
        id: saveTimer

        interval: 120
        onTriggered: controller.save()
    }

    Connections {
        target: controller.settings

        function onDataChanged() {
            controller.syncFromSettings();
        }

        function onLoadedChanged() {
            controller.syncFromSettings();
        }

        function onInvalidChanged() {
            controller.syncFromSettings();
        }

        function onSaveFailed() {
            controller.errorMessage = "The bar layout could not be saved.";
        }
    }

    onSettingsChanged: syncFromSettings()
    Component.onCompleted: syncFromSettings()
}

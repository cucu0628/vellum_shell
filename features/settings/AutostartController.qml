pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Bejelentkezesi .desktop fajlok es a felhasznaloi systemd szolgaltatasok.
// Mindket lista csak oldalnyitaskor vagy egy muvelet utan frissul.
Item {
    id: controller

    readonly property string shellDir: Quickshell.env("VELLUM_SHELL_DIR")
        || (Quickshell.env("HOME") + "/.config/quickshell/vellum_shell")

    property var autostartEntries: []
    property var services: []
    property bool autostartLoading: false
    property bool servicesLoading: false
    property string autostartError: ""
    property string servicesError: ""
    property string busyTarget: ""
    property string operationKind: ""

    width: 0
    height: 0
    visible: false

    function reload() {
        reloadAutostart();
        reloadServices();
    }

    function reloadAutostart() {
        if (autostartReader.running)
            return;

        autostartLoading = true;
        autostartError = "";
        autostartReader.command = [shellDir + "/scripts/settings-autostart", "list"];
        autostartReader.running = true;
    }

    function reloadServices() {
        if (servicesReader.running)
            return;

        servicesLoading = true;
        servicesError = "";
        servicesReader.command = ["sh", "-c", "files=$(systemctl --user list-unit-files --type=service --output=json --no-pager 2>/dev/null) || exit 1; [ -n \"$files\" ] || files='[]'; units=$(systemctl --user list-units --type=service --all --output=json --no-pager 2>/dev/null || printf '[]'); [ -n \"$units\" ] || units='[]'; printf '{\"files\":%s,\"units\":%s}\\n' \"$files\" \"$units\""];
        servicesReader.running = true;
    }

    function setAutostart(id, enabled) {
        if (operation.running)
            return;

        busyTarget = id;
        operationKind = "autostart";
        operation.command = [shellDir + "/scripts/settings-autostart", "set", id, enabled ? "true" : "false"];
        operation.running = true;
    }

    function setServiceEnabled(unit, enabled) {
        if (operation.running)
            return;

        busyTarget = unit;
        operationKind = "service";
        operation.command = ["systemctl", "--user", enabled ? "enable" : "disable", unit];
        operation.running = true;
    }

    function setServiceRunning(unit, running) {
        if (operation.running)
            return;

        busyTarget = unit;
        operationKind = "service";
        operation.command = ["systemctl", "--user", running ? "start" : "stop", unit];
        operation.running = true;
    }

    function parseAutostart(output) {
        var result = [];
        var lines = (output || "").split("\n");
        for (var i = 0; i < lines.length; i++) {
            if (lines[i].trim() === "")
                continue;

            var fields = lines[i].split("\t");
            if (fields.length < 5)
                continue;

            result.push({
                "id": fields[0],
                "name": fields[1],
                "command": fields[2],
                "enabled": fields[3] === "true",
                "source": fields[4]
            });
        }
        result.sort(function(a, b) {
            return a.name.localeCompare(b.name);
        });
        autostartEntries = result;
    }

    function parseServices(output) {
        var parsed;
        try {
            parsed = JSON.parse(output || "{}");
        } catch (error) {
            services = [];
            servicesError = "The systemd response was not valid JSON.";
            return;
        }

        var activeByUnit = {};
        var runningUnits = parsed.units || [];
        for (var i = 0; i < runningUnits.length; i++)
            activeByUnit[runningUnits[i].unit] = runningUnits[i];

        var result = [];
        var files = parsed.files || [];
        for (var j = 0; j < files.length; j++) {
            var file = files[j];
            var unit = file.unit_file || file.unit || "";
            var state = file.state || "unknown";
            // Az aliasok ugyanarra az egysegre mutato duplikatumok, az ures
            // peldanysablonok pedig nev nelkul nem indithatok ertelmesen.
            if (unit === "" || state === "alias" || unit.indexOf("@.service") >= 0)
                continue;

            var runtime = activeByUnit[unit] || {};
            result.push({
                "unit": unit,
                "description": runtime.description || "User service",
                "active": runtime.active === "active",
                "substate": runtime.sub || runtime.active || "inactive",
                "enabled": state === "enabled" || state === "enabled-runtime" || state === "linked" || state === "linked-runtime",
                "enableAllowed": ["disabled", "enabled", "enabled-runtime", "linked", "linked-runtime"].indexOf(state) >= 0,
                "unitState": state
            });
        }
        result.sort(function(a, b) {
            return a.unit.localeCompare(b.unit);
        });
        services = result;
    }

    Process {
        id: autostartReader

        onExited: (exitCode) => {
            controller.autostartLoading = false;
            if (exitCode !== 0) {
                controller.autostartEntries = [];
                controller.autostartError = "Autostart entries could not be read.";
            }
        }

        stdout: StdioCollector {
            onStreamFinished: controller.parseAutostart(this.text || "")
        }
    }

    Process {
        id: servicesReader

        onExited: (exitCode) => {
            controller.servicesLoading = false;
            if (exitCode !== 0) {
                controller.services = [];
                controller.servicesError = "The user systemd manager is unavailable.";
            }
        }

        stdout: StdioCollector {
            onStreamFinished: controller.parseServices(this.text || "")
        }
    }

    Process {
        id: operation

        onExited: (exitCode) => {
            var kind = controller.operationKind;
            controller.busyTarget = "";
            controller.operationKind = "";
            if (exitCode !== 0) {
                if (kind === "autostart")
                    controller.autostartError = "The autostart setting could not be changed.";
                else
                    controller.servicesError = "The service operation failed.";
            } else if (kind === "autostart") {
                controller.reloadAutostart();
            } else {
                controller.reloadServices();
            }
        }
    }
}

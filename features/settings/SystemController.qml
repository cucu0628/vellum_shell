import QtQuick
import Quickshell
import Quickshell.Io

// A rendszer-oldal allapota. A korabbi Setup beallitasok mellett egyszeri
// diagnosztikai pillanatkepet ker a munkamenetrol es a backend health moduljarol.
Item {
    id: controller

    property var backend: null

    // Ugyanaz a szabaly, mint a backend `theme::paths::shell_dir()`-jeben,
    // hogy a ket oldal ne csusszon szet athelyezett repo eseten.
    readonly property string shellDir: Quickshell.env("VELLUM_SHELL_DIR")
        || (Quickshell.env("HOME") + "/.config/quickshell/vellum_shell")

    property string weatherLocation: ""
    property string powerProfile: ""
    property var powerProfiles: []
    property bool powerProfilesAvailable: false
    property var lockscreenMonitors: []
    property string lockscreenMonitor: ""
    property var diagnosticFacts: []
    property var backendModules: []
    property var failedServices: []
    property bool diagnosticsLoading: false
    property bool backendHealthy: false
    property string backendSummary: "Not connected"
    property string diagnosticsMessage: ""
    property bool clipboardAvailable: false

    width: 0
    height: 0
    visible: false

    function reload() {
        readWeather.running = false;
        // Az utvonal pozicionalis argumentumkent megy, nem a parancsba fuzve:
        // egy szokozt vagy pontosvesszot tartalmazo HOME kulonben szethasitana.
        readWeather.command = ["sh", "-c", "cat -- \"$1\" 2>/dev/null || true", "sh", shellDir + "/current-weather-location"];
        readWeather.running = true;

        readProfiles.running = false;
        // Egy hivas adja a listat es az aktivat is: a `list` csillaggal jeloli
        // az eppen ervenyeset, de az konnyen valtozik -- ezert kerdezzuk kulon.
        readProfiles.command = ["sh", "-c", "command -v powerprofilesctl >/dev/null 2>&1 || exit 1; printf 'active:%s\\n' \"$(powerprofilesctl get)\"; powerprofilesctl list | sed -n 's/^[* ] \\([a-z-]*\\):$/name:\\1/p'"];
        readProfiles.running = true;

        readMonitors.running = false;
        readMonitors.command = ["sh", "-c", "exec \"$1\" list", "sh", shellDir + "/scripts/lockscreen-monitor"];
        readMonitors.running = true;

        reloadDiagnostics();
    }

    function reloadDiagnostics() {
        if (!diagnostics.running) {
            diagnosticsLoading = true;
            diagnosticsMessage = "";
            diagnostics.command = ["sh", "-c", [
                "os=Unknown",
                "if [ -r /etc/os-release ]; then . /etc/os-release; os=${PRETTY_NAME:-${NAME:-Unknown}}; fi",
                "printf 'os\\t%s\\n' \"$os\"",
                "printf 'kernel\\t%s\\n' \"$(uname -sr 2>/dev/null || printf Unknown)\"",
                "desktop=${XDG_CURRENT_DESKTOP:-${XDG_SESSION_DESKTOP:-Unknown}}",
                "session=${XDG_SESSION_TYPE:-Unknown}",
                "printf 'session\\t%s / %s\\n' \"$desktop\" \"$session\"",
                "manager=$(systemctl --user is-system-running 2>/dev/null || true)",
                "[ -n \"$manager\" ] || manager=unavailable",
                "printf 'manager\\t%s\\n' \"$manager\"",
                "failed=$(systemctl --user --failed --type=service --no-legend --no-pager --plain 2>/dev/null || true)",
                "count=$(printf '%s\\n' \"$failed\" | awk 'NF { count++ } END { print count + 0 }')",
                "printf 'failedCount\\t%s\\n' \"$count\"",
                "printf '%s\\n' \"$failed\" | awk 'NF { print \"failed\\t\" $1 }'",
                "command -v wl-copy >/dev/null 2>&1 && printf 'clipboard\\ttrue\\n' || printf 'clipboard\\tfalse\\n'"
            ].join("; ")];
            diagnostics.running = true;
        }

        requestBackendHealth();
    }

    function requestBackendHealth() {
        if (!backend || !backend.connected) {
            backendHealthy = false;
            backendSummary = "Not connected";
            backendModules = [];
            return;
        }

        backend.call("health", "ping", {}, (result, error) => {
            if (error || !result) {
                controller.backendHealthy = false;
                controller.backendSummary = "No health response";
                controller.backendModules = [];
                return;
            }

            controller.backendHealthy = true;
            var revision = result.revision && result.revision !== "unknown" ? " · " + result.revision : "";
            controller.backendSummary = "v" + (result.version || "?") + revision + " · PID " + (result.pid || "?") + " · " + controller.formatDuration(result.uptimeSeconds || 0);

            var modules = [];
            var health = result.modules || {};
            var names = Object.keys(health).sort();
            for (var i = 0; i < names.length; i++) {
                var entry = health[names[i]] || {};
                modules.push({
                    "name": names[i],
                    "state": entry.state || "unknown",
                    "error": entry.error || ""
                });
            }
            controller.backendModules = modules;
        });
    }

    function formatDuration(seconds) {
        var value = Math.max(0, Number(seconds) || 0);
        var days = Math.floor(value / 86400);
        var hours = Math.floor((value % 86400) / 3600);
        var minutes = Math.floor((value % 3600) / 60);
        if (days > 0)
            return days + "d " + hours + "h";
        if (hours > 0)
            return hours + "h " + minutes + "m";
        return Math.max(1, minutes) + "m";
    }

    function diagnosticReport() {
        var lines = ["Vellum Shell diagnostics"];
        for (var i = 0; i < diagnosticFacts.length; i++)
            lines.push(diagnosticFacts[i].label + ": " + diagnosticFacts[i].value);

        lines.push("Backend: " + backendSummary);
        for (var j = 0; j < backendModules.length; j++) {
            var module = backendModules[j];
            lines.push("Module " + module.name + ": " + module.state + (module.error !== "" ? " (" + module.error + ")" : ""));
        }
        if (failedServices.length > 0)
            lines.push("Failed user services: " + failedServices.join(", "));
        return lines.join("\n");
    }

    function copyDiagnostics() {
        if (!clipboardAvailable || copyProcess.running)
            return;

        diagnosticsMessage = "";
        copyProcess.command = ["wl-copy", diagnosticReport()];
        copyProcess.running = true;
    }

    Connections {
        target: controller.backend

        function onConnectedChanged() {
            controller.requestBackendHealth();
        }
    }

    function setWeatherLocation(value) {
        var trimmed = (value || "").trim();
        if (trimmed === "")
            return ;

        weatherLocation = trimmed;
        write.running = false;
        write.command = ["sh", "-c", "printf '%s\\n' \"$1\" > " + shellDir + "/current-weather-location", "sh", trimmed];
        write.running = true;
    }

    function setPowerProfile(value) {
        powerProfile = value;
        write.running = false;
        write.command = ["powerprofilesctl", "set", value];
        write.running = true;
    }

    function setLockscreenMonitor(value) {
        lockscreenMonitor = value;
        write.running = false;
        write.command = [shellDir + "/scripts/lockscreen-monitor", "set", value];
        write.running = true;
    }

    Process {
        id: write
    }

    Process {
        id: readWeather

        stdout: StdioCollector {
            onStreamFinished: {
                var value = (this.text || "").trim();
                controller.weatherLocation = value === "" ? "Budapest" : value;
            }
        }

    }

    Process {
        id: readProfiles

        onExited: (exitCode) => {
            if (exitCode !== 0)
                controller.powerProfilesAvailable = false;

        }

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = (this.text || "").trim().split("\n");
                var profiles = [];
                var active = "";
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line.indexOf("active:") === 0)
                        active = line.slice(7).trim();
                    else if (line.indexOf("name:") === 0)
                        profiles.push(line.slice(5).trim());
                }
                controller.powerProfiles = profiles;
                controller.powerProfile = active;
                controller.powerProfilesAvailable = profiles.length > 0;
            }
        }

    }

    Process {
        id: readMonitors

        stdout: StdioCollector {
            onStreamFinished: {
                // A script `Cimke|ertek` sorokat ad, az aktivat "[current]"-tel.
                var lines = (this.text || "").trim().split("\n");
                var monitors = [];
                var current = "";
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line === "")
                        continue;

                    var index = line.indexOf("|");
                    if (index < 0)
                        continue;

                    var label = line.slice(0, index).trim();
                    var value = line.slice(index + 1).trim();
                    if (label.indexOf("[current]") >= 0)
                        current = value;

                    monitors.push({
                        "label": value,
                        "value": value
                    });
                }
                controller.lockscreenMonitors = monitors;
                controller.lockscreenMonitor = current;
            }
        }

    }

    Process {
        id: diagnostics

        onExited: (exitCode) => {
            controller.diagnosticsLoading = false;
            if (exitCode !== 0)
                controller.diagnosticsMessage = "Some system details could not be read.";
        }

        stdout: StdioCollector {
            onStreamFinished: {
                var facts = [];
                var failed = [];
                var failedCount = "0";
                var lines = (this.text || "").split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var separator = lines[i].indexOf("\t");
                    if (separator < 0)
                        continue;

                    var key = lines[i].slice(0, separator);
                    var value = lines[i].slice(separator + 1).trim();
                    if (key === "os")
                        facts.push({ "label": "Operating system", "value": value });
                    else if (key === "kernel")
                        facts.push({ "label": "Kernel", "value": value });
                    else if (key === "session")
                        facts.push({ "label": "Session", "value": value });
                    else if (key === "manager")
                        facts.push({ "label": "User service manager", "value": value });
                    else if (key === "failedCount")
                        failedCount = value;
                    else if (key === "failed")
                        failed.push(value);
                    else if (key === "clipboard")
                        controller.clipboardAvailable = value === "true";
                }
                facts.push({
                    "label": "Failed user services",
                    "value": failedCount === "0" ? "None" : failedCount
                });
                controller.diagnosticFacts = facts;
                controller.failedServices = failed;
            }
        }
    }

    Process {
        id: copyProcess

        onExited: (exitCode) => {
            controller.diagnosticsMessage = exitCode === 0 ? "Diagnostic report copied." : "The report could not be copied.";
        }
    }

}

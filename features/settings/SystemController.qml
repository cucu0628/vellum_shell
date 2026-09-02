import QtQuick
import Quickshell
import Quickshell.Io

// A rendszer-oldal allapota. Harom fuggetlen dolgot olvas es ir; mindharom a
// megszunt menu "Setup" almenujebol jott at, de urlappa alakitva -- a
// `weather-location` interaktiv TUI-t itt egy szovegmezo valtja ki.
Item {
    id: controller

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

}

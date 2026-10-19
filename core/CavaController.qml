import QtQuick
import Quickshell.Io

Item {
    id: controller

    property bool active: false
    property bool available: false
    // A savbeli jelzo 6 erteke, 0..100: a spektrum atlagolva.
    property var values: [0, 0, 0, 0, 0, 0]
    // A teljes spektrum a dashboardnak, 0..100.
    property var spectrum: []
    // Egyetlen, allando beallitas: egy mod-valtas ujrainditana a cavat, es a
    // zene kozben egy pillanatra megallna a kijelzes. 32 sav 30 fps-sel
    // merve ~1% CPU.
    readonly property int barCount: 32
    readonly property string configPath: "/tmp/vellum-shell-cava-" + Date.now() + "-" + Math.floor(Math.random() * 1000000) + ".conf"

    width: 0
    height: 0
    visible: false

    function syncProcess() {
        var shouldRun = available && active
        if (cavaProcess.running !== shouldRun) cavaProcess.running = shouldRun
    }

    onActiveChanged: syncProcess()
    onAvailableChanged: syncProcess()
    // A spektrumbol a jelzo 6 erteke: egyenlo savok atlaga.
    function downsample(source) {
        var result = []
        var chunk = source.length / 6
        for (var i = 0; i < 6; i++) {
            var sum = 0
            var from = Math.floor(i * chunk)
            var to = Math.floor((i + 1) * chunk)
            for (var j = from; j < to; j++) sum += source[j]
            result.push(Math.round(sum / Math.max(1, to - from)))
        }
        return result
    }

    Process {
        id: availabilityCheck
        command: ["sh", "-c", "command -v cava >/dev/null 2>&1"]
        onExited: exitCode => controller.available = exitCode === 0
    }

    Process {
        id: cavaProcess
        command: ["sh", "-c", "cat > '" + controller.configPath + "' <<'EOF'\n"
            + "[general]\n"
            + "framerate=30\n"
            + "bars=" + controller.barCount + "\n"
            // Automatikus erzekenyseg: a csucsok halk es hangos zenenel is a
            // 0..100 tartomany felso reszebe esnek.
            + "autosens=1\n"
            + "sensitivity=100\n"
            + "lower_cutoff_freq=50\n"
            + "higher_cutoff_freq=12000\n\n"
            + "[output]\n"
            + "method=raw\n"
            + "raw_target=/dev/stdout\n"
            + "data_format=ascii\n"
            + "ascii_max_range=100\n"
            + "channels=mono\n"
            + "mono_option=average\n\n"
            + "[smoothing]\n"
            + "noise_reduction=35\n"
            + "integral=90\n"
            + "gravity=95\n"
            + "ignore=2\n"
            + "monstercat=1.5\n"
            + "EOF\n"
            + "trap \"rm -f '" + controller.configPath + "'\" EXIT\n"
            + "exec cava -p '" + controller.configPath + "' < /dev/null"]

        onRunningChanged: {
            if (running) return
            controller.values = [0, 0, 0, 0, 0, 0]
            controller.spectrum = []
            Qt.callLater(controller.syncProcess)
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var parts = data.split(";")
                var count = controller.barCount
                if (parts.length < count) return

                var next = []
                var changed = controller.spectrum.length !== count
                for (var i = 0; i < count; i++) {
                    var value = parseInt(parts[i], 10) || 0
                    if (!changed && value !== controller.spectrum[i]) changed = true
                    next.push(value)
                }
                if (!changed) return
                controller.spectrum = next
                controller.values = controller.downsample(next)
            }
        }
    }

    Component.onCompleted: availabilityCheck.running = true
}

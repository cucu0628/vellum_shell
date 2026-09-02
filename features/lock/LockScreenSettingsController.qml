import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // Ugyanaz a szabaly, mint a backend `theme::paths::shell_dir()`-jeben,
    // hogy a ket oldal ne csusszon szet athelyezett repo eseten.
    readonly property string shellDir: Quickshell.env("VELLUM_SHELL_DIR")
        || (Quickshell.env("HOME") + "/.config/quickshell/vellum_shell")

    property string inputMonitorName: ""
    property bool ready: false

    function load() {
        ready = false
        loader.command = ["sh", "-c", "exec sh \"$1\" current", "sh", shellDir + "/scripts/lockscreen-monitor"]
        loader.running = true
    }

    property Process loader: Process {
        onExited: (exitCode) => root.ready = true

        stdout: StdioCollector {
            onStreamFinished: root.inputMonitorName = (this.text || "").trim()
        }
    }
}

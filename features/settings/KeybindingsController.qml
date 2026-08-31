import QtQuick
import Quickshell
import Quickshell.Io

// A Hyprland billentyukombinaciok listaja. A parsert a megszunt
// `features/menu/MenuController.qml` orokolte: a `scripts/keybindings-list`
// elsodlegesen a `hyprctl binds -j` JSON-jat adja vissza, es csak akkor esik
// vissza szoveges formara, ha a Hyprland nem elerheto.
Item {
    id: controller

    // Ugyanaz a szabaly, mint a backend `theme::paths::shell_dir()`-jeben,
    // hogy a ket oldal ne csusszon szet athelyezett repo eseten.
    readonly property string shellDir: Quickshell.env("VELLUM_SHELL_DIR")
        || (Quickshell.env("HOME") + "/.config/quickshell/vellum_shell")

    property var bindings: []
    property bool loading: false

    width: 0
    height: 0
    visible: false

    function reload() {
        if (fetcher.running)
            return ;

        loading = true;
        bindings = [];
        timeout.restart();
        fetcher.command = ["sh", "-c", "exec \"$1\"", "sh", shellDir + "/scripts/keybindings-list"];
        fetcher.running = true;
    }

    function modMaskLabel(mask) {
        var parts = [];
        if (mask & 64)
            parts.push("SUPER");

        if (mask & 4)
            parts.push("CTRL");

        if (mask & 8)
            parts.push("ALT");

        if (mask & 1)
            parts.push("SHIFT");

        return parts.join(" + ");
    }

    function keyLabel(binding) {
        if (binding.key && binding.key !== "")
            return binding.key.replace("mouse:272", "LEFT MOUSE BUTTON").replace("mouse:273", "RIGHT MOUSE BUTTON");

        if (binding.keycode && binding.keycode !== 0)
            return "keycode " + binding.keycode;

        return "";
    }

    function load(output) {
        var text = (output || "").trim();
        loading = false;
        if (text === "") {
            bindings = [];
            return ;
        }
        bindings = text.charAt(0) === "[" ? parseJson(text) : parseLines(text);
    }

    function parseJson(text) {
        var parsed = [];
        try {
            parsed = JSON.parse(text);
        } catch (error) {
            return [];
        }
        var result = [];
        for (var i = 0; i < parsed.length; i++) {
            var binding = parsed[i];
            var modifiers = modMaskLabel(binding.modmask || 0);
            var key = keyLabel(binding);
            var shortcut = modifiers !== "" && key !== "" ? modifiers + " + " + key : key;
            var action = binding.description && binding.description !== "" ? binding.description : ((binding.dispatcher || "") + (binding.arg ? " " + binding.arg : ""));
            if (shortcut === "" && action === "")
                continue;

            result.push({
                "shortcut": shortcut !== "" ? shortcut : "UNREPORTED KEY",
                "action": action
            });
        }
        return result;
    }

    // Tartalek forma: `kombinacio<TAB>muvelet` vagy `kombinacio → muvelet`.
    function parseLines(text) {
        var lines = text.split("\n");
        var result = [];
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line === "")
                continue;

            var index = line.indexOf("\t");
            if (index < 0)
                index = line.indexOf("→");

            result.push({
                "shortcut": index >= 0 ? line.slice(0, index).trim() : line,
                "action": index >= 0 ? line.slice(index + 1).trim() : ""
            });
        }
        return result;
    }

    Timer {
        id: timeout

        interval: 3500
        onTriggered: {
            if (fetcher.running)
                fetcher.signal(9);

            controller.loading = false;
        }
    }

    Process {
        id: fetcher

        onExited: (exitCode) => {
            timeout.stop();
            controller.loading = false;
            if (exitCode !== 0)
                controller.bindings = [];

        }

        stdout: StdioCollector {
            onStreamFinished: controller.load(this.text || "")
        }

    }

}

import QtQuick
import Quickshell.Io

// A Hyprland billentyukombinaciok listaja. A `scripts/keybindings-list` a
// `hyprctl binds -j` JSON-jat adja, utana `#source` sor mogott a config
// forrasabol olvasott leirasokat; Hyprland nelkul csak az utobbiakat.
Item {
    id: controller

    required property string shellDir

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
        fetcher.command = [shellDir + "/scripts/keybindings-list"];
        fetcher.running = true;
    }

    // Hyprland modmask bitjei, a megjelenitesi sorrendben.
    readonly property var modifierBits: [{
        "bit": 64,
        "name": "SUPER"
    }, {
        "bit": 4,
        "name": "CTRL"
    }, {
        "bit": 8,
        "name": "ALT"
    }, {
        "bit": 1,
        "name": "SHIFT"
    }, {
        "bit": 2,
        "name": "CAPS"
    }, {
        "bit": 16,
        "name": "MOD2"
    }, {
        "bit": 32,
        "name": "MOD3"
    }, {
        "bit": 128,
        "name": "MOD5"
    }]
    readonly property var modifierAliases: ({
        "WIN": "SUPER",
        "LOGO": "SUPER",
        "META": "SUPER",
        "MOD4": "SUPER",
        "CONTROL": "CTRL",
        "MOD1": "ALT"
    })
    readonly property var modifierLabels: ({
        "SUPER": "Super",
        "CTRL": "Ctrl",
        "ALT": "Alt",
        "SHIFT": "Shift",
        "CAPS": "Caps"
    })
    // xkb keysym -> amit a billentyun latni. Ami nincs itt, az alahuzas nelkul
    // es egykarakteresnel nagybetuvel jelenik meg.
    readonly property var keyLabels: ({
        "return": "Enter",
        "space": "Space",
        "tab": "Tab",
        "escape": "Esc",
        "backspace": "Backspace",
        "delete": "Delete",
        "print": "Print",
        "page_up": "Page Up",
        "page_down": "Page Down",
        "left": "←",
        "right": "→",
        "up": "↑",
        "down": "↓",
        "bracketleft": "[",
        "bracketright": "]",
        "minus": "-",
        "equal": "=",
        "plus": "+",
        "comma": ",",
        "period": ".",
        "slash": "/",
        "backslash": "\\",
        "semicolon": ";",
        "apostrophe": "'",
        "grave": "`",
        "mouse:272": "Left click",
        "mouse:273": "Right click",
        "mouse:274": "Middle click",
        "mouse_up": "Wheel up",
        "mouse_down": "Wheel down",
        "mouse_left": "Wheel left",
        "mouse_right": "Wheel right",
        "xf86audioraisevolume": "Volume up",
        "xf86audiolowervolume": "Volume down",
        "xf86audiomute": "Mute",
        "xf86audiomicmute": "Mic mute",
        "xf86audioplay": "Play",
        "xf86audiopause": "Pause",
        "xf86audioprev": "Previous",
        "xf86audionext": "Next",
        "xf86audiostop": "Stop",
        "xf86monbrightnessup": "Brightness up",
        "xf86monbrightnessdown": "Brightness down"
    })

    function modifiersFromMask(mask) {
        var result = [];
        for (var i = 0; i < modifierBits.length; i++) {
            if (mask & modifierBits[i].bit)
                result.push(modifierBits[i].name);

        }
        return result;
    }

    // "SUPER + shift + left" -> { modifiers: ["SUPER", "SHIFT"], key: "left" }
    function splitShortcut(text) {
        var parts = text.split("+");
        var modifiers = [];
        var key = "";
        for (var i = 0; i < parts.length; i++) {
            var part = parts[i].trim();
            if (i === parts.length - 1) {
                key = part;
                break;
            }
            var name = part.toUpperCase();
            modifiers.push(modifierAliases[name] || name);
        }
        return {
            "modifiers": modifiers,
            "key": key
        };
    }

    // A forras es a futo Hyprland ugyanarra a kotesre ugyanezt adja, barmilyen
    // sorrendben vagy kis-nagybetuvel irtak a modositokat.
    function shortcutId(modifiers, key) {
        var ordered = [];
        for (var i = 0; i < modifierBits.length; i++) {
            if (modifiers.indexOf(modifierBits[i].name) >= 0)
                ordered.push(modifierBits[i].name);

        }
        return ordered.concat([key.toUpperCase()]).join("+");
    }

    function keyLabel(key) {
        var known = keyLabels[key.toLowerCase()];
        if (known !== undefined)
            return known;

        if (key.length === 1)
            return key.toUpperCase();

        if (key.indexOf("XF86") === 0)
            key = key.slice(4);

        return key.replace(/_/g, " ");
    }

    function formatShortcut(modifiers, key) {
        var parts = [];
        for (var i = 0; i < modifierBits.length; i++) {
            var name = modifierBits[i].name;
            if (modifiers.indexOf(name) >= 0)
                parts.push(modifierLabels[name] || name);

        }
        parts.push(key !== "" ? keyLabel(key) : "Unknown key");
        return parts.join(" + ");
    }

    function load(output) {
        var lines = (output || "").split("\n");
        var marker = lines.indexOf("#source");
        var runtime = (marker < 0 ? lines : lines.slice(0, marker)).join("\n").trim();
        var source = marker < 0 ? [] : parseLines(lines.slice(marker + 1).join("\n"));
        loading = false;
        if (runtime.charAt(0) === "[")
            bindings = parseJson(runtime, source);
        else if (marker < 0)
            bindings = parseLines(runtime);
        else
            bindings = source;
    }

    // A futo Hyprland a mertekado: ami a JSON-ban van, az el. A Lua config
    // viszont minden kotest `__lua` dispatcherrel jelent, ezert a muvelet
    // leirasa -- es a `code:NN` kotesek billentyuje -- a forrasbol jon.
    function parseJson(text, source) {
        var parsed = [];
        try {
            parsed = JSON.parse(text);
        } catch (error) {
            return source;
        }
        var byId = {};
        var byDescription = {};
        for (var s = 0; s < source.length; s++) {
            byId[source[s].id] = source[s];
            if (byDescription[source[s].action] === undefined)
                byDescription[source[s].action] = source[s];

        }
        var result = [];
        for (var i = 0; i < parsed.length; i++) {
            var binding = parsed[i];
            var description = binding.description || "";
            var modifiers = modifiersFromMask(binding.modmask || 0);
            var key = binding.key || "";
            if (key === "" && binding.keycode)
                key = "code:" + binding.keycode;

            var known = key !== "" ? byId[shortcutId(modifiers, key)] : (description !== "" ? byDescription[description] : undefined);
            if (key === "" && known) {
                modifiers = known.modifiers;
                key = known.key;
            }
            var action = description;
            if (action === "" && binding.dispatcher === "__lua")
                action = known ? known.action : "Lua action";
            else if (action === "")
                action = (binding.dispatcher || "") + (binding.arg ? " " + binding.arg : "");
            if (key === "" && action === "")
                continue;

            result.push({
                "shortcut": formatShortcut(modifiers, key),
                "action": action
            });
        }
        return result;
    }

    // Forras-sorok: `kombinacio<TAB>muvelet` vagy `kombinacio → muvelet`.
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

            var parts = splitShortcut(index >= 0 ? line.slice(0, index) : line);
            result.push({
                "id": shortcutId(parts.modifiers, parts.key),
                "modifiers": parts.modifiers,
                "key": parts.key,
                "shortcut": formatShortcut(parts.modifiers, parts.key),
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

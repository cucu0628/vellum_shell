import QtQuick
import Quickshell
import Quickshell.Io

// Az alapertelmezett terminalemulator. A valasztas az xdg-terminal-exec
// szabvany `xdg-terminals.list` fajljanak elso bejegyzese, igy a GLib, az
// xdg-terminal-exec es a shell ugyanazt a terminalt inditja. Ha a lista hianyzik
// vagy ures, a kitty marad -- a shell eddig is azt hasznalta. A fajlt figyeljuk,
// egy kulso szerkesztes is azonnal ervenyes.
Item {
    id: controller

    required property string configHome

    readonly property string listPath: configHome + "/xdg-terminals.list"
    readonly property string fallbackId: "kitty.desktop"

    // A lista nyers sorai; iraskor a tobbi bejegyzest es a megjegyzeseket
    // valtozatlanul visszairjuk.
    property var lines: []
    property string desktopId: ""
    readonly property string effectiveId: desktopId !== "" ? desktopId : fallbackId
    property var terminals: []
    property bool saving: false

    signal saveFinished(bool ok)

    width: 0
    height: 0
    visible: false

    Component.onCompleted: refreshTerminals()

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            controller.refreshTerminals();
        }
    }

    function desktopFileId(entryId) {
        var id = (entryId || "").toString();
        return id.endsWith(".desktop") ? id : id + ".desktop";
    }

    // A listaban `azonosito.desktop:akcio` is allhat; a `/` direktiva, a `-`
    // kizart bejegyzes, a `+` csak hangsulyoz.
    function entryIdOf(line) {
        var value = (line || "").trim();
        if (value === "" || value[0] === "#" || value[0] === "/" || value[0] === "-")
            return "";

        if (value[0] === "+")
            value = value.slice(1);
        var colon = value.indexOf(":");
        return colon >= 0 ? value.slice(0, colon) : value;
    }

    function loadText(text) {
        var parsed = (text || "").split("\n");
        if (parsed.length > 0 && parsed[parsed.length - 1] === "")
            parsed.pop();
        lines = parsed;

        var found = "";
        for (var i = 0; i < parsed.length && found === ""; i++)
            found = entryIdOf(parsed[i]);
        desktopId = found;
    }

    function refreshTerminals() {
        var entries = DesktopEntries.applications.values;
        var result = [];
        var seen = {};
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i];
            if (!entry || entry.noDisplay || !entry.id)
                continue;

            var categories = entry.categories || [];
            var isTerminal = false;
            for (var c = 0; c < categories.length; c++) {
                if (categories[c] === "TerminalEmulator")
                    isTerminal = true;
            }
            var id = desktopFileId(entry.id);
            if (!isTerminal || seen[id])
                continue;

            seen[id] = true;
            result.push({
                "label": entry.name && entry.name !== "" ? entry.name : id,
                "value": id
            });
        }
        result.sort(function(a, b) {
            return a.label.localeCompare(b.label);
        });
        terminals = result;
    }

    function setDefault(id) {
        if (saving || id === "")
            return;

        var next = [id];
        for (var i = 0; i < lines.length; i++) {
            if (entryIdOf(lines[i]) !== id)
                next.push(lines[i]);
        }
        saving = true;
        desktopId = id;
        lines = next;
        listFile.setText(next.join("\n") + "\n");
    }

    // A terminal sajat inditoparancsa a desktop bejegyzesbol, mezokodok nelkul.
    function baseCommand() {
        var entry = DesktopEntries.byId(effectiveId.replace(/\.desktop$/, ""));
        var parsed = entry ? (entry.command || []) : [];
        var command = [];
        for (var i = 0; i < parsed.length; i++)
            command.push(parsed[i]);
        if (command.length > 0)
            return command;

        return [effectiveId.replace(/\.desktop$/, "").split(".").pop().toLowerCase()];
    }

    // A desktop fajl `X-TerminalArgExec` kulcsat a Quickshell nem adja at, ezert
    // az ismert terminalok kapcsoloja itt van; a tobbi az xterm-fele `-e`-t kapja.
    function execArgs() {
        var id = effectiveId.toLowerCase();
        var known = [
            ["gnome-terminal", ["--"]],
            ["xfce4-terminal", ["-x"]],
            ["terminator", ["-x"]],
            ["wezterm", ["start", "--"]],
            ["ptyxis", ["--"]],
            ["kitty", ["--"]],
            ["foot", []]
        ];
        for (var i = 0; i < known.length; i++) {
            if (id.indexOf(known[i][0]) >= 0)
                return known[i][1];
        }
        return ["-e"];
    }

    // Egy parancs argv-je a valasztott terminalban; ures parancsra maga a terminal.
    function argv(command) {
        var base = baseCommand();
        if (!command || command.length === 0)
            return base;

        // Egy alparancsot (wezterm `start`) nem ismetlunk meg, ha a desktop
        // bejegyzes Exec-je mar tartalmazza: `wezterm start --cwd . -- cmd`.
        var args = execArgs();
        if (args.length > 1 && args[0] !== "--" && base.indexOf(args[0]) > 0)
            args = args.slice(1);
        return base.concat(args, command);
    }

    FileView {
        id: listFile

        path: controller.listPath
        atomicWrites: true
        watchChanges: true
        printErrors: false
        onLoaded: controller.loadText(listFile.text())
        onFileChanged: listFile.reload()
        onLoadFailed: controller.loadText("")
        onSaved: {
            controller.saving = false;
            controller.saveFinished(true);
        }
        onSaveFailed: {
            controller.saving = false;
            listFile.reload();
            controller.saveFinished(false);
        }
    }
}

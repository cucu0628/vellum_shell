pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// A freedesktop MIME-tarsitasokat kezeli. Az alkalmazaslista a Quickshell
// DesktopEntries szolgaltatasabol jon, az xdg-mime csak egyszer olvas oldalnyitaskor
// es egy valasztas utan ir -- nincs hatterpolling.
Item {
    id: controller

    readonly property var categories: [{
        "id": "browser",
        "label": "Web browser",
        "description": "Links and HTML documents.",
        "mimeTypes": ["x-scheme-handler/http", "x-scheme-handler/https", "text/html"]
    }, {
        "id": "mail",
        "label": "Email",
        "description": "Email links and message files.",
        "mimeTypes": ["x-scheme-handler/mailto", "message/rfc822"]
    }, {
        "id": "calendar",
        "label": "Calendar",
        "description": "Calendar invitations and events.",
        "mimeTypes": ["text/calendar"]
    }, {
        "id": "music",
        "label": "Music",
        "description": "Common audio files and playlists.",
        "mimeTypes": ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav", "audio/x-mpegurl"]
    }, {
        "id": "video",
        "label": "Video",
        "description": "Common video files.",
        "mimeTypes": ["video/mp4", "video/webm", "video/x-matroska"]
    }, {
        "id": "images",
        "label": "Images",
        "description": "Photos and other raster images.",
        "mimeTypes": ["image/jpeg", "image/png", "image/webp", "image/gif"]
    }, {
        "id": "text",
        "label": "Text editor",
        "description": "Plain-text documents.",
        "mimeTypes": ["text/plain"]
    }, {
        "id": "pdf",
        "label": "PDF viewer",
        "description": "Portable Document Format files.",
        "mimeTypes": ["application/pdf"]
    }, {
        "id": "files",
        "label": "File manager",
        "description": "Folders opened from applications.",
        "mimeTypes": ["inode/directory"]
    }, {
        "id": "terminal",
        "label": "Terminal",
        "description": "Terminal apps and the launcher's terminal action.",
        "mimeTypes": []
    }]

    // Az alapertelmezett terminalt nem az xdg-mime tarolja, hanem a core
    // TerminalController (`xdg-terminals.list`). Nelkule a sor nem allithato.
    property var terminal: null

    property var applications: []
    property var defaults: ({})
    property bool loading: false
    property bool available: true
    // A GLib (es vele a `gio open`, az `xdg-open` es a fajlkezelok) csak az
    // xdg-terminal-exec-en at olvassa a terminallistat. Nelkule a sajat
    // beepitett sorrendjet koveti, amiben a kitty nem szerepel -- ott
    // tipikusan a Konsole nyerne.
    property bool terminalExecAvailable: true
    property string busyCategory: ""
    property string message: ""
    property var defaultsBeforeWrite: ({})

    width: 0
    height: 0
    visible: false

    Component.onCompleted: refreshApplications()

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            controller.refreshApplications();
        }
    }

    // A Quickshell a desktop entry bazisazonositojat adja (pl. `zen`), mig
    // az xdg-mime a telepitett fajl teljes azonositojat (`zen.desktop`) keri.
    function desktopFileId(entryId) {
        var id = (entryId || "").toString();
        return id.endsWith(".desktop") ? id : id + ".desktop";
    }

    function refreshApplications() {
        var entries = DesktopEntries.applications.values;
        var result = [];
        var seen = {};
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i];
            if (!entry || entry.noDisplay || !entry.id)
                continue;

            var desktopId = desktopFileId(entry.id);
            if (seen[desktopId])
                continue;

            seen[desktopId] = true;
            result.push({
                "label": entry.name && entry.name !== "" ? entry.name : desktopId,
                "value": desktopId
            });
        }
        result.sort(function(a, b) {
            return a.label.localeCompare(b.label);
        });
        applications = result;
    }

    function isTerminal(category) {
        return category && category.id === "terminal";
    }

    function valueFor(categoryId) {
        if (categoryId === "terminal")
            return terminal ? terminal.effectiveId : "";

        return defaults[categoryId] || "";
    }

    function descriptionFor(category) {
        if (isTerminal(category) && !terminalExecAvailable)
            return "Install xdg-terminal-exec so other apps use it too.";

        return category.description;
    }

    function canChange(category) {
        if (isTerminal(category))
            return terminal !== null && !terminal.saving;

        return available && busyCategory === "";
    }

    // Egy eltavolitott vagy NoDisplay desktop-fajl meg mindig lehet aktiv
    // tarsitas. Ne tunjon el a jelenlegi ertek csak azert, mert nincs a listaban.
    // A terminal sorban csak a TerminalEmulator kategoriaju alkalmazasok allnak.
    function applicationsFor(category) {
        var list = isTerminal(category) ? (terminal ? terminal.terminals : []) : applications;
        var currentValue = valueFor(category.id);
        if (currentValue === "")
            return list;

        for (var i = 0; i < list.length; i++) {
            if (list[i].value === currentValue)
                return list;
        }
        return [{
            "label": currentValue,
            "value": currentValue
        }].concat(list);
    }

    function reload() {
        if (reader.running)
            return;

        loading = true;
        message = "";
        var command = ["sh", "-c", "if command -v xdg-terminal-exec >/dev/null 2>&1; then t=1; else t=0; fi; printf '@terminal-exec\\t%s\\n' \"$t\"; command -v xdg-mime >/dev/null 2>&1 || exit 127; while [ \"$#\" -ge 2 ]; do key=$1; mime=$2; shift 2; value=$(xdg-mime query default \"$mime\" 2>/dev/null || true); printf '%s\\t%s\\n' \"$key\" \"$value\"; done", "sh"];
        for (var i = 0; i < categories.length; i++) {
            if (categories[i].mimeTypes.length === 0)
                continue;

            command.push(categories[i].id);
            command.push(categories[i].mimeTypes[0]);
        }
        reader.command = command;
        reader.running = true;
    }

    function setDefault(category, desktopId) {
        if (isTerminal(category)) {
            if (!terminal || desktopId === "" || desktopId === terminal.effectiveId)
                return;

            message = "";
            terminal.setDefault(desktopId);
            return;
        }

        if (writer.running || desktopId === "")
            return;

        busyCategory = category.id;
        message = "";
        defaultsBeforeWrite = defaults;
        var next = Object.assign({}, defaults);
        next[category.id] = desktopId;
        defaults = next;

        writer.command = ["xdg-mime", "default", desktopId].concat(category.mimeTypes);
        writer.running = true;
    }

    Connections {
        target: controller.terminal

        function onSaveFinished(ok) {
            controller.message = ok ? "Default terminal updated." : "The default terminal could not be changed.";
        }
    }

    Process {
        id: reader

        onExited: (exitCode) => {
            controller.loading = false;
            controller.available = exitCode !== 127;
            if (exitCode !== 0)
                controller.message = exitCode === 127 ? "xdg-utils is not installed." : "Default applications could not be read.";
        }

        stdout: StdioCollector {
            onStreamFinished: {
                var parsed = {};
                var lines = (this.text || "").split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var separator = lines[i].indexOf("\t");
                    if (separator < 0)
                        continue;

                    parsed[lines[i].slice(0, separator)] = lines[i].slice(separator + 1).trim();
                }
                controller.terminalExecAvailable = parsed["@terminal-exec"] !== "0";
                delete parsed["@terminal-exec"];
                controller.defaults = parsed;
            }
        }
    }

    Process {
        id: writer

        onExited: (exitCode) => {
            var category = controller.busyCategory;
            controller.busyCategory = "";
            if (exitCode !== 0) {
                controller.message = "The default application could not be changed.";
                controller.defaults = controller.defaultsBeforeWrite;
            } else {
                controller.message = "Default application updated.";
            }
            controller.defaultsBeforeWrite = ({});
        }
    }
}

import QtQuick

// A launcher muveletei: minden, amit be lehet gepelni, de nem egy .desktop
// alkalmazas. Ez valtotta ki a korabbi menu palettat; a keresheto, azonnal
// indithato muveletek vannak itt, koztuk az interaktiv telepitok is.
//
// Mezok:
//   name      a megjelenitett nev, egyben az elsodleges keresokulcs
//   terms     tovabbi keresoszavak
//   icon      nerd font glif
//   subtitle  egysoros magyarazat
//   command   `sh -c`-vel futtatva
//   confirm   igaz eseten ket Enter kell (visszafordithatatlan muveletek)
//   delay     bezaras utan indul, hogy maga a launcher ne keruljon a kepre
QtObject {
    readonly property string shellPath: "~/.config/quickshell/vellum_shell/shell.qml"
    readonly property string scriptsPath: "~/.config/quickshell/vellum_shell/scripts"

    function ipc(target, method) {
        return "quickshell ipc --path " + shellPath + " call " + target + " " + method;
    }

    function terminalScript(script) {
        return scriptsPath + "/floating-terminal " + scriptsPath + "/" + script;
    }

    readonly property var items: [{
        "name": "settings",
        "terms": ["preferences", "control", "config", "display", "monitor", "hyprland"],
        "icon": "󰒓",
        "subtitle": "Open Vellum Settings",
        "command": ipc("settings", "toggle")
    }, {
        "name": "appearance",
        "terms": ["wallpaper", "background", "studio", "style"],
        "icon": "󰸌",
        "subtitle": "Open Appearance Studio",
        "command": ipc("style", "wallpaper")
    }, {
        "name": "palette",
        "terms": ["theme", "colors", "colours"],
        "icon": "󰏘",
        "subtitle": "Pick a colour theme",
        "command": ipc("style", "theme")
    }, {
        "name": "clipboard",
        "terms": ["history", "paste", "copy"],
        "icon": "󰅌",
        "subtitle": "Open clipboard history",
        "command": ipc("clipboard", "toggle")
    }, {
        "name": "audio",
        "terms": ["sound", "volume", "output", "mixer"],
        "icon": "󰕾",
        "subtitle": "Open audio devices",
        "command": ipc("audio", "toggle")
    }, {
        "name": "notifications",
        "terms": ["notify", "center", "history"],
        "icon": "󰂞",
        "subtitle": "Open notification centre",
        "command": ipc("notifications", "toggle")
    }, {
        "name": "do not disturb",
        "terms": ["dnd", "silence", "mute notifications"],
        "icon": "󰂛",
        "subtitle": "Toggle notification silence",
        "command": ipc("notifications", "dnd")
    }, {
        "name": "screenshot",
        "terms": ["capture", "screen", "grab"],
        "icon": "󰄀",
        "subtitle": "Capture the screen",
        "command": ipc("screenshot", "capture"),
        "delay": true
    }, {
        "name": "terminal",
        "terms": ["term", "shell", "kitty"],
        "icon": "",
        "subtitle": "Open terminal",
        "command": "kitty"
    }, {
        "name": "files",
        "terms": ["file", "folder", "nautilus", "home"],
        "icon": "󰉋",
        "subtitle": "Open home folder",
        "command": "xdg-open $HOME"
    }, {
        "name": "browser",
        "terms": ["web", "internet"],
        "icon": "󰖟",
        "subtitle": "Open default browser",
        "command": "xdg-open https://www.google.com"
    }, {
        "name": "install package",
        "terms": ["pacman", "official", "repository", "software", "add"],
        "icon": "󰏔",
        "subtitle": "Search and install from the official repositories",
        "command": terminalScript("pkg-install"),
        "delay": true
    }, {
        "name": "install AUR package",
        "terms": ["yay", "arch user repository", "software", "add"],
        "icon": "󰣇",
        "subtitle": "Search and install from the Arch User Repository",
        "command": terminalScript("aur-install"),
        "delay": true
    }, {
        "name": "install web app",
        "terms": ["website", "browser", "wrapper", "software", "add"],
        "icon": "󰖟",
        "subtitle": "Wrap a website as a desktop application",
        "command": terminalScript("webapp-install"),
        "delay": true
    }, {
        "name": "install terminal app",
        "terms": ["tui", "cli", "curated", "software", "add"],
        "icon": "",
        "subtitle": "Install a curated terminal tool",
        "command": terminalScript("tui-install"),
        "delay": true
    }, {
        "name": "remove package",
        "terms": ["pacman", "aur", "uninstall", "software", "delete"],
        "icon": "󰆴",
        "subtitle": "Remove an installed repository or AUR package",
        "command": terminalScript("pkg-remove"),
        "delay": true
    }, {
        "name": "remove web app",
        "terms": ["website", "wrapper", "uninstall", "delete"],
        "icon": "󰅖",
        "subtitle": "Remove a web app wrapper",
        "command": terminalScript("webapp-remove"),
        "delay": true
    }, {
        "name": "remove terminal app",
        "terms": ["tui", "cli", "uninstall", "delete"],
        "icon": "󰆍",
        "subtitle": "Remove a curated terminal tool",
        "command": terminalScript("tui-remove"),
        "delay": true
    }, {
        "name": "refresh shell",
        "terms": ["reload", "restart", "vellum"],
        "icon": "󰑐",
        "subtitle": "Reload Vellum Shell",
        "command": scriptsPath + "/theme-refresh"
    }, {
        "name": "about",
        "terms": ["system", "info", "version"],
        "icon": "󰋼",
        "subtitle": "System information",
        "command": ipc("about", "toggle")
    }, {
        "name": "lock",
        "terms": ["lockscreen", "screensaver"],
        "icon": "󰌾",
        "subtitle": "Lock the session",
        "command": ipc("lock", "lock")
    }, {
        "name": "suspend",
        "terms": ["sleep", "power"],
        "icon": "󰒲",
        "subtitle": "Suspend the system",
        "command": "systemctl suspend",
        "confirm": true
    }, {
        "name": "logout",
        "terms": ["exit", "sign out", "power"],
        "icon": "󰍃",
        "subtitle": "End the Hyprland session",
        "command": "hyprctl dispatch 'hl.dsp.exit()'",
        "confirm": true
    }, {
        "name": "reboot",
        "terms": ["restart", "power"],
        "icon": "󰜉",
        "subtitle": "Restart the system",
        "command": "systemctl reboot",
        "confirm": true
    }, {
        "name": "shutdown",
        "terms": ["poweroff", "power", "halt", "turn off"],
        "icon": "󰐥",
        "subtitle": "Power off the system",
        "command": "systemctl poweroff",
        "confirm": true
    }]
}

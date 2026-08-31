import QtQuick

// A launcher muveletei: minden, amit be lehet gepelni, de nem egy .desktop
// alkalmazas. Ez valtotta ki a korabbi menu palettat -- a beallitas-jellegu
// pontok a settings appba kerultek, ide csak az egy kattintassal elsulo
// muveletek jottek at.
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

    readonly property var items: [{
        "name": "settings",
        "terms": ["preferences", "control", "config", "display", "monitor", "hyprland"],
        "icon": "",
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
        "icon": "",
        "subtitle": "Pick a colour theme",
        "command": ipc("style", "theme")
    }, {
        "name": "clipboard",
        "terms": ["history", "paste", "copy"],
        "icon": "",
        "subtitle": "Open clipboard history",
        "command": ipc("clipboard", "toggle")
    }, {
        "name": "audio",
        "terms": ["sound", "volume", "output", "mixer"],
        "icon": "",
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
        "icon": "",
        "subtitle": "Open terminal",
        "command": "kitty"
    }, {
        "name": "files",
        "terms": ["file", "folder", "nautilus", "home"],
        "icon": "",
        "subtitle": "Open home folder",
        "command": "xdg-open $HOME"
    }, {
        "name": "browser",
        "terms": ["web", "internet"],
        "icon": "󰖟",
        "subtitle": "Open default browser",
        "command": "xdg-open https://www.google.com"
    }, {
        "name": "refresh shell",
        "terms": ["reload", "restart", "vellum"],
        "icon": "",
        "subtitle": "Reload Vellum Shell",
        "command": scriptsPath + "/theme-refresh"
    }, {
        "name": "about",
        "terms": ["system", "info", "version"],
        "icon": "",
        "subtitle": "System information",
        "command": ipc("about", "toggle")
    }, {
        "name": "lock",
        "terms": ["lockscreen", "screensaver"],
        "icon": "",
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

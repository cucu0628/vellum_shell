import QtQuick
import Quickshell
import Quickshell.Io

// Akik bejelentkezhetnek, es amibe: a felhasznalok az /etc/passwd-bol, a
// munkamenetek a wayland-sessions .desktop fajljaibol. X11-es munkamenetet
// szandekosan nem kinalunk: a greeter nem indit X szervert.
//
// A legutobbi valasztast a greeter sajat gyorsitotaraban jegyezzuk meg,
// felhasznalonkent kulon munkamenettel.
QtObject {
    id: root

    readonly property string cacheDir: Quickshell.env("VELLUM_GREETER_CACHE") || "/var/cache/vellum-greeter"

    // { name, label }
    property var users: []
    // { id, label, exec, desktopNames }
    property var sessions: []
    property int userIndex: 0
    property int sessionIndex: 0
    property bool sessionsLoaded: false

    property var memory: ({ "user": "", "sessions": {} })
    property bool memoryLoaded: false

    readonly property var user: userIndex >= 0 && userIndex < users.length ? users[userIndex] : null
    readonly property var session: sessionIndex >= 0 && sessionIndex < sessions.length ? sessions[sessionIndex] : null
    readonly property string userName: user ? user.name : ""
    readonly property string userLabel: user ? user.label : ""
    readonly property string sessionLabel: session ? session.label : ""

    function selectUser(index) {
        if (index < 0 || index >= users.length) return
        userIndex = index
        restoreSession()
    }

    function selectSession(index) {
        if (index < 0 || index >= sessions.length) return
        sessionIndex = index
    }

    // A belepes elott: legkozelebb ugyanez a felhasznalo es ugyanez a munkamenet.
    function remember() {
        if (!user || !session) return
        var next = { "user": user.name, "sessions": {} }
        var known = memory && memory.sessions ? memory.sessions : {}
        for (var name in known) next.sessions[name] = known[name]
        next.sessions[user.name] = session.id
        memory = next
        memoryFile.setText(JSON.stringify(next) + "\n")
    }

    function indexOfUser(name) {
        for (var i = 0; i < users.length; i++) {
            if (users[i].name === name) return i
        }
        return -1
    }

    function indexOfSession(id) {
        for (var i = 0; i < sessions.length; i++) {
            if (sessions[i].id === id) return i
        }
        return -1
    }

    // A felhasznalo sajat legutobbi munkamenete, kulonben a Hyprland, kulonben
    // az elso a listaban.
    function restoreSession() {
        if (sessions.length === 0) return
        var remembered = user && memory.sessions ? memory.sessions[user.name] : undefined
        var index = remembered ? indexOfSession(remembered) : -1
        if (index < 0) index = indexOfSession("hyprland")
        sessionIndex = Math.max(0, index)
    }

    function restoreUser() {
        if (users.length === 0) return
        var index = indexOfUser(memory.user || "")
        userIndex = Math.max(0, index)
        restoreSession()
    }

    function parseUsers(text) {
        var list = []
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var fields = lines[i].split(":")
            if (fields.length < 7) continue
            var uid = parseInt(fields[2], 10)
            // Az emberi fiokok tartomanya a login.defs alapertekei szerint.
            if (isNaN(uid) || uid < 1000 || uid >= 60000) continue
            if (/(nologin|false)$/.test(fields[6])) continue
            var realName = fields[4].split(",")[0].trim()
            list.push({ "name": fields[0], "label": realName !== "" ? realName : fields[0] })
        }
        users = list
        restoreUser()
    }

    // A desktop-fajlok rekordelvalasztoval (\036) jonnek; a TryExec szureset a
    // shell vegzi, mert ahhoz PATH-kereses kell.
    function parseSessions(text) {
        var list = []
        var seen = {}
        var records = text.split("\x1e")
        for (var i = 0; i < records.length; i++) {
            var record = records[i]
            if (record.trim() === "") continue
            var newline = record.indexOf("\n")
            var path = (newline < 0 ? record : record.substring(0, newline)).trim()
            var id = path.substring(path.lastIndexOf("/") + 1).replace(/\.desktop$/, "")
            if (id === "" || seen[id]) continue

            var entry = parseDesktopEntry(newline < 0 ? "" : record.substring(newline + 1))
            if (!entry.Exec || entry.Hidden === "true" || entry.NoDisplay === "true") continue
            seen[id] = true
            list.push({
                "id": id,
                "label": entry.Name || id,
                // A mezokodok (%f, %U, ...) egy munkamenetnel ertelmetlenek.
                "exec": entry.Exec.replace(/%[a-zA-Z]/g, "").trim(),
                "desktopNames": (entry.DesktopNames || "").split(";").filter(function (name) { return name !== "" })
            })
        }
        sessions = list
        sessionsLoaded = true
        restoreSession()
    }

    function parseDesktopEntry(text) {
        var entry = {}
        var inSection = false
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line.charAt(0) === "[") {
                inSection = line === "[Desktop Entry]"
                continue
            }
            if (!inSection || line === "" || line.charAt(0) === "#") continue
            var split = line.indexOf("=")
            if (split <= 0) continue
            var key = line.substring(0, split).trim()
            // A lokalizalt kulcsokat (Name[hu]) kihagyjuk: a greeter nyelve angol.
            if (key.indexOf("[") >= 0 || entry[key] !== undefined) continue
            entry[key] = line.substring(split + 1).trim()
        }
        return entry
    }

    property FileView passwdFile: FileView {
        path: "/etc/passwd"
        printErrors: false
        onLoaded: root.parseUsers(root.passwdFile.text())
    }

    property FileView memoryFile: FileView {
        path: root.cacheDir + "/memory.json"
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                var parsed = JSON.parse(root.memoryFile.text())
                if (parsed && typeof parsed === "object") {
                    root.memory = {
                        "user": typeof parsed.user === "string" ? parsed.user : "",
                        "sessions": parsed.sessions && typeof parsed.sessions === "object" ? parsed.sessions : {}
                    }
                }
            } catch (error) {
                console.warn("Greeter: a memory.json nem ertelmezheto:", error)
            }
            root.memoryLoaded = true
            root.restoreUser()
        }
        onLoadFailed: root.memoryLoaded = true
    }

    property Process sessionReader: Process {
        running: true
        // /usr/local elol: egy helyi felulirast a disztribucio azonos nevu
        // fajlja ne takarjon el.
        command: ["sh", "-c", "for dir in /usr/local/share/wayland-sessions /usr/share/wayland-sessions; do for file in \"$dir\"/*.desktop; do [ -r \"$file\" ] || continue; try=$(sed -n 's/^TryExec=//p' \"$file\" | head -n 1); if [ -n \"$try\" ] && ! command -v \"$try\" >/dev/null 2>&1; then continue; fi; printf '\\036%s\\n' \"$file\"; cat \"$file\"; printf '\\n'; done; done"]

        stdout: StdioCollector {
            onStreamFinished: root.parseSessions(this.text || "")
        }
    }
}

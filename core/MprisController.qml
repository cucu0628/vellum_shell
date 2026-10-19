import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
    id: controller

    // A beallitasokban felvett kivetelek: ezeket a lejatszokat a shell sehol nem
    // mutatja (sem a sav jelzojeben, sem a dashboardon). Pl. egy bongeszo, amely
    // a hover-elonezeteket is lejatszaskent jelenti. Soronkent egy nev a
    // `media-ignore` fajlban; a lejatszo nevere (identity) vagy bus-nevere illik,
    // kis- es nagybetutol fuggetlenul.
    property string shellDir: ""
    property var ignoredPlayers: []
    // A nem kihagyott lejatszok: mindenki ezt hasznalja a nyers lista helyett.
    readonly property var players: Mpris.players.values.filter((player) => !isIgnored(player))

    function parseIgnored(text) {
        var result = []
        var lines = (text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var name = lines[i].trim()
            if (name !== "" && name[0] !== "#" && result.indexOf(name) < 0) result.push(name)
        }
        return result
    }

    function isIgnored(player) {
        if (!player || ignoredPlayers.length === 0) return false
        var identity = (player.identity || "").toLowerCase()
        var dbusName = (player.dbusName || "").toLowerCase()
        for (var i = 0; i < ignoredPlayers.length; i++) {
            var entry = ignoredPlayers[i].toLowerCase()
            if (identity === entry || dbusName.indexOf(entry) >= 0) return true
        }
        return false
    }

    function setIgnored(name, ignored) {
        var clean = (name || "").trim()
        if (clean === "") return
        var next = ignoredPlayers.filter((entry) => entry.toLowerCase() !== clean.toLowerCase())
        if (ignored) next.push(clean)
        ignoredPlayers = next
        ignoreFile.setText(next.length > 0 ? next.join("\n") + "\n" : "")
    }

    onIgnoredPlayersChanged: updateActivePlayer()

    FileView {
        id: ignoreFile

        path: controller.shellDir !== "" ? controller.shellDir + "/media-ignore" : ""
        watchChanges: true
        printErrors: false
        onLoaded: controller.ignoredPlayers = controller.parseIgnored(text())
        onFileChanged: reload()
        onLoadFailed: controller.ignoredPlayers = []
    }

    property string preferredPlayerDbusName: ""
    // A felhasznalo altal kivalasztott lejatszo (a dashboardon). Amig letezik,
    // ez az aktiv -- a sav jelzoje es a dashboard is ezt mutatja. Ures:
    // automatikus valasztas.
    property string pinnedDbusName: ""
    property var activePlayer: null

    onPinnedDbusNameChanged: updateActivePlayer()

    width: 0
    height: 0
    visible: false

    function isBrowserPlayer(player) {
        if (!player) return false
        var name = ((player.identity || "") + " " + (player.dbusName || "")).toLowerCase()
        return name.indexOf("firefox") !== -1
            || name.indexOf("zen") !== -1
            || name.indexOf("chromium") !== -1
            || name.indexOf("chrome") !== -1
            || name.indexOf("brave") !== -1
            || name.indexOf("vivaldi") !== -1
            || name.indexOf("edge") !== -1
            || name.indexOf("browser") !== -1
    }

    function chooseActivePlayer() {
        // Kozvetlenul szurunk: a `players` kotes a kivetelek valtozasakor meg a
        // regi erteket adhatna, mert az ujraertekelese nem garantaltan elobb fut.
        var players = Mpris.players.values.filter((player) => !isIgnored(player))
        if (players.length === 0) {
            preferredPlayerDbusName = ""
            return null
        }

        if (pinnedDbusName !== "") {
            for (var p = 0; p < players.length; p++) {
                if (players[p].dbusName === pinnedDbusName) return players[p]
            }
        }

        for (var i = 0; i < players.length; i++) {
            if (!isBrowserPlayer(players[i]) && players[i].playbackState === MprisPlaybackState.Playing) {
                preferredPlayerDbusName = players[i].dbusName
                return players[i]
            }
        }

        if (preferredPlayerDbusName !== "") {
            for (var j = 0; j < players.length; j++) {
                if (players[j].dbusName === preferredPlayerDbusName) return players[j]
            }
        }

        for (var k = 0; k < players.length; k++) {
            if (!isBrowserPlayer(players[k]) && (players[k].trackTitle !== "" || players[k].trackArtist !== "")) {
                preferredPlayerDbusName = players[k].dbusName
                return players[k]
            }
        }

        if (activePlayer) {
            for (var activeIndex = 0; activeIndex < players.length; activeIndex++) {
                if (players[activeIndex] === activePlayer) return activePlayer
            }
        }

        for (var l = 0; l < players.length; l++) {
            if (players[l].playbackState === MprisPlaybackState.Playing) {
                preferredPlayerDbusName = players[l].dbusName
                return players[l]
            }
        }

        return null
    }

    function updateActivePlayer() {
        activePlayer = chooseActivePlayer()
    }

    Component.onCompleted: updateActivePlayer()

    Connections {
        target: Mpris.players

        function onValuesChanged() {
            controller.updateActivePlayer()
        }
    }

    Instantiator {
        model: Mpris.players

        delegate: Item {
            required property var modelData

            width: 0
            height: 0
            visible: false

            Connections {
                target: modelData

                function onPlaybackStateChanged() { controller.updateActivePlayer() }
                function onTrackTitleChanged() { controller.updateActivePlayer() }
                function onTrackArtistChanged() { controller.updateActivePlayer() }
            }
        }
    }
}

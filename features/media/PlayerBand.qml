import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import Quickshell.Widgets
import "../../ui" as SharedUi

// A dashboard teteje: a zenelejatszo. Amig van mit mutatni, a lap fo eleme --
// borito, a boritobol elmosott hatter, cim, spektrum, idosav, vezerlok. Ha nem
// szol semmi, egy vekony sorra huzodik ossze, es a lap ennyivel alacsonyabb.
Item {
    id: band

    property var theme: null
    property var player: null
    property var players: []
    property bool artworkEnabled: true
    property var cavaValues: [0, 0, 0, 0, 0, 0]
    property real livePosition: -1
    // A kivalasztott lejatszo bus-neve; ures: automatikus.
    property string pinnedDbusName: ""
    // A lejatszo-valaszto lista latszik a lejatszo helyen.
    property bool choosing: false
    readonly property bool canChoose: players.length > 1
    // null: automatikus valasztas.
    signal playerSelected(var player)
    signal seeked(real seconds)
    signal trackChangeRequested()

    readonly property string background: theme ? theme.background : "#11130f"
    readonly property string surface: theme && theme.surface ? theme.surface : "#191b16"
    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property color hoverBg: Qt.rgba(1, 1, 1, 0.075)
    readonly property color lineBg: Qt.rgba(1, 1, 1, 0.08)
    readonly property color surfaceColor: surface

    // A megjelenitett adatok (felulirhatok, alapbol a lejatszoe).
    property string trackTitle: player ? (player.trackTitle || "") : ""
    property string trackArtist: player ? (player.trackArtist || player.identity || "") : ""
    property string trackArtUrl: player ? (player.trackArtUrl || "") : ""

    readonly property bool hasTrack: player !== null && trackTitle !== ""
    readonly property bool isPlaying: player && player.playbackState === MprisPlaybackState.Playing
    readonly property real currentPosition: livePosition >= 0 ? livePosition : (player ? player.position : 0)
    readonly property string artUrl: artworkEnabled && player && trackArtUrl !== "" ? trackArtUrl : ""

    function formatTime(seconds) {
        if (!seconds || seconds < 0) return "0:00"
        var total = Math.floor(seconds)
        return Math.floor(total / 60) + ":" + (total % 60).toString().padStart(2, "0")
    }

    function progress() {
        if (!player || !player.lengthSupported || player.length <= 0) return 0
        return Math.max(0, Math.min(1, currentPosition / player.length))
    }

    function seekSupported() {
        return player && player.canSeek && player.positionSupported && player.lengthSupported && player.length > 0
    }

    function seekTo(ratio) {
        if (!seekSupported()) return
        var target = Math.max(0, Math.min(1, ratio)) * player.length
        player.position = target
        player.positionChanged()
        seeked(target)
    }

    function volumeSupported() {
        return player && player.volumeSupported && player.canControl
    }

    function setVolume(ratio) {
        if (volumeSupported()) player.volume = Math.max(0, Math.min(1, ratio))
    }

    function changeTrack(forward) {
        if (!player || (forward ? !player.canGoNext : !player.canGoPrevious)) return
        trackChangeRequested()
        if (forward) player.next()
        else player.previous()
    }

    function choose(nextPlayer) {
        choosing = false
        playerSelected(nextPlayer)
    }

    onCanChooseChanged: if (!canChoose) choosing = false

    // A spektrum szintje egy 0..1 kozotti pozicion. A cava savjai kozott
    // koszinuszos interpolacio: a csucsok kerekek, nem lepcsosek.
    function spectrumLevel(position) {
        var values = cavaValues
        if (!isPlaying || !values || values.length < 2) return 0
        var scaled = Math.max(0, Math.min(1, position)) * (values.length - 1)
        var lower = Math.floor(scaled)
        var upper = Math.min(values.length - 1, lower + 1)
        var t = (1 - Math.cos((scaled - lower) * Math.PI)) / 2
        var raw = values[lower] * (1 - t) + values[upper] * t
        // A cava 0..100 kozott ad; a gyok a halk reszeket emeli ki.
        return Math.sqrt(Math.max(0, Math.min(100, raw)) / 100)
    }

    implicitHeight: hasTrack || choosing ? 164 : 44
    clip: true

    Behavior on implicitHeight { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }

    ClippingRectangle {
        anchors.fill: parent
        radius: 10
        color: band.surface

        // A borito szinei: egy kicsi, erosen elmosott masolat a sav mogott. A
        // sourceSize szandekosan kicsi -- a blur ugyis eltunteti a reszleteket.
        Image {
            id: backdropSource

            anchors.fill: parent
            source: band.artUrl
            sourceSize: Qt.size(96, 96)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: backdropSource
            visible: band.hasTrack && backdropSource.status === Image.Ready
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: 1
            saturation: 0.15
            opacity: 0.5
        }

        // Fatyol a temaszinbol, jobbra erosodve: a szoveg alatt mindig olvashato.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }
                GradientStop { position: 0.55; color: Qt.rgba(band.surfaceColor.r, band.surfaceColor.g, band.surfaceColor.b, 0.55) }
                GradientStop { position: 1.0; color: Qt.rgba(band.surfaceColor.r, band.surfaceColor.g, band.surfaceColor.b, 0.8) }
            }
            visible: band.hasTrack
        }
    }

    // -- teljes lejatszo ----------------------------------------------------
    Item {
        id: full

        anchors.fill: parent
        anchors.margins: 14
        opacity: band.hasTrack && !band.choosing ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        ClippingRectangle {
            id: art

            width: 136
            height: 136
            radius: 8
            color: band.background

            Image {
                id: artImage

                anchors.fill: parent
                source: band.artUrl
                sourceSize: Qt.size(272, 272)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            Text {
                anchors.centerIn: parent
                visible: artImage.status !== Image.Ready
                text: "󰎆"
                color: band.muted
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 40
            }
        }

        Column {
            anchors.left: art.right
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.verticalCenter: art.verticalCenter
            spacing: 10

            Item {
                width: parent.width
                height: titleColumn.implicitHeight

                Column {
                    id: titleColumn

                    anchors.left: parent.left
                    anchors.right: source.left
                    anchors.rightMargin: 12
                    spacing: 2

                    Text {
                        width: parent.width
                        text: band.trackTitle
                        textFormat: Text.PlainText
                        color: band.foreground
                        font.family: "serif"
                        font.pixelSize: 21
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: band.trackArtist
                        textFormat: Text.PlainText
                        color: band.muted
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        visible: text !== ""
                    }
                }

                // Forras: melyik lejatszo szol. Tobb lejatszonal kattintasra
                // a lejatszo helyen megjelenik a valaszto lista.
                Rectangle {
                    id: source

                    anchors.right: parent.right
                    anchors.top: parent.top
                    width: sourceRow.implicitWidth + 16
                    height: 28
                    radius: 6
                    color: sourceMouse.containsMouse && band.canChoose ? band.hoverBg : "transparent"

                    Row {
                        id: sourceRow

                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6
                            height: 6
                            radius: 3
                            color: band.isPlaying ? band.accent : band.muted
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: band.player ? (band.player.identity || "Media") : ""
                            textFormat: Text.PlainText
                            color: band.muted
                            font.pixelSize: 11
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: band.canChoose
                            text: "󰅀"
                            color: band.muted
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 11
                        }
                    }

                    SharedUi.Pressable {
                        id: sourceMouse

                        anchors.fill: parent
                        enabled: band.canChoose
                        theme: band.theme
                        accessibleName: qsTr("Choose media player")
                        onClicked: band.choosing = true
                    }
                }
            }

            // Spektrum: vekony, lekerekitett csikok a kozepvonalbol szimmetrikusan.
            // A csikok szama a szelessegbol jon (3 px csik, 3 px rés), az
            // ertekeket a cava savjai kozott simán interpolaljuk.
            Item {
                id: spectrum

                readonly property int barWidth: 3
                readonly property int gap: 3
                readonly property int count: Math.max(8, Math.floor((width + gap) / (barWidth + gap)))
                readonly property real offset: (width - (count * (barWidth + gap) - gap)) / 2

                width: parent.width
                height: 28

                Repeater {
                    model: spectrum.count

                    Rectangle {
                        required property int index
                        readonly property real level: band.spectrumLevel(index / Math.max(1, spectrum.count - 1))

                        x: spectrum.offset + index * (spectrum.barWidth + spectrum.gap)
                        anchors.verticalCenter: parent.verticalCenter
                        width: spectrum.barWidth
                        height: Math.max(spectrum.barWidth, spectrum.height * level)
                        radius: width / 2
                        color: band.accent
                        opacity: band.isPlaying ? 0.35 + 0.65 * level : 0.22

                        Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                }
            }

            Item {
                width: parent.width
                height: 14

                Text {
                    id: elapsed

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: band.player && band.player.lengthSupported ? band.formatTime(band.currentPosition) : "--:--"
                    color: band.muted
                    font.family: "monospace"
                    font.pixelSize: 10
                }

                Text {
                    id: total

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: band.player && band.player.lengthSupported ? band.formatTime(band.player.length) : "--:--"
                    color: band.muted
                    font.family: "monospace"
                    font.pixelSize: 10
                }

                Rectangle {
                    id: timeline

                    anchors.left: elapsed.right
                    anchors.right: total.left
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: timelineMouse.containsMouse ? 5 : 3
                    radius: height / 2
                    color: band.lineBg
                    Behavior on height { NumberAnimation { duration: 90 } }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * band.progress()
                        radius: parent.radius
                        color: band.accent
                        Behavior on width { enabled: !timelineMouse.pressed; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        id: timelineMouse

                        anchors.fill: parent
                        anchors.topMargin: -10
                        anchors.bottomMargin: -10
                        enabled: band.seekSupported()
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onPressed: (mouse) => band.seekTo(mouse.x / Math.max(1, width))
                        onPositionChanged: (mouse) => { if (pressed) band.seekTo(mouse.x / Math.max(1, width)) }
                    }
                }
            }

            Item {
                width: parent.width
                height: 30

                Row {
                    id: transport

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Repeater {
                        model: [
                            { "key": "shuffle", "icon": "󰒝", "name": qsTr("Shuffle") },
                            { "key": "previous", "icon": "󰒮", "name": qsTr("Previous track") },
                            { "key": "play", "icon": "", "name": qsTr("Play or pause") },
                            { "key": "next", "icon": "󰒭", "name": qsTr("Next track") },
                            { "key": "loop", "icon": "󰑖", "name": qsTr("Repeat") }
                        ]

                        Rectangle {
                            id: control

                            required property var modelData
                            readonly property bool isPlay: modelData.key === "play"
                            readonly property bool available: {
                                var p = band.player
                                if (!p) return false
                                switch (modelData.key) {
                                case "shuffle": return p.shuffleSupported === true
                                case "loop": return p.loopSupported === true
                                case "previous": return p.canGoPrevious
                                case "next": return p.canGoNext
                                default: return p.canTogglePlaying
                                }
                            }
                            readonly property bool active: {
                                var p = band.player
                                if (!p) return false
                                if (modelData.key === "shuffle") return p.shuffle === true
                                if (modelData.key === "loop") return p.loopState !== undefined && p.loopState !== MprisLoopState.None
                                return false
                            }

                            // A shuffle/ismetles csak akkor latszik, ha a lejatszo tamogatja.
                            visible: isPlay || modelData.key === "previous" || modelData.key === "next" || available
                            width: isPlay ? 46 : 34
                            height: 30
                            radius: 6
                            color: isPlay
                                ? (controlMouse.containsMouse ? Qt.lighter(band.accent, 1.12) : band.accent)
                                : (controlMouse.containsMouse && available ? band.hoverBg : "transparent")
                            Behavior on color { ColorAnimation { duration: 110 } }

                            Text {
                                anchors.centerIn: parent
                                text: control.isPlay ? (band.isPlaying ? "󰏤" : "󰐊") : (control.modelData.key === "loop" && band.player && band.player.loopState === MprisLoopState.Track ? "󰑘" : control.modelData.icon)
                                color: control.isPlay ? band.background : (control.active ? band.accent : band.foreground)
                                opacity: control.available ? 1 : 0.35
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: control.isPlay ? 17 : 15
                            }

                            SharedUi.Pressable {
                                id: controlMouse

                                anchors.fill: parent
                                enabled: control.available
                                theme: band.theme
                                accessibleName: control.modelData.name
                                onClicked: {
                                    var p = band.player
                                    switch (control.modelData.key) {
                                    case "previous": band.changeTrack(false); break
                                    case "next": band.changeTrack(true); break
                                    case "play": p.togglePlaying(); break
                                    case "shuffle": p.shuffle = !p.shuffle; break
                                    case "loop":
                                        p.loopState = p.loopState === MprisLoopState.None
                                            ? MprisLoopState.Playlist
                                            : (p.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None)
                                        break
                                    }
                                }
                            }
                        }
                    }
                }

                // A lejatszo sajat hangereje (nem a rendszere).
                Item {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(150, parent.width - transport.width - 16)
                    height: 30
                    visible: band.volumeSupported()

                    Text {
                        id: volumeGlyph

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰕾"
                        color: band.muted
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 14
                    }

                    Rectangle {
                        id: volumeTrack

                        anchors.left: volumeGlyph.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 4
                        radius: 2
                        color: band.lineBg

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * (band.player ? Math.max(0, Math.min(1, band.player.volume)) : 0)
                            radius: 2
                            color: band.foreground
                            opacity: 0.8
                        }
                    }

                    MouseArea {
                        anchors.fill: volumeTrack
                        anchors.topMargin: -12
                        anchors.bottomMargin: -12
                        cursorShape: Qt.PointingHandCursor
                        onPressed: (mouse) => band.setVolume(mouse.x / Math.max(1, width))
                        onPositionChanged: (mouse) => { if (pressed) band.setVolume(mouse.x / Math.max(1, width)) }
                        onWheel: (wheel) => band.setVolume(band.player.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                    }
                }
            }
        }
    }

    // -- lejatszo-valaszto -----------------------------------------------------
    Item {
        anchors.fill: parent
        anchors.margins: 14
        opacity: band.choosing ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Item {
            id: chooserHead

            width: parent.width
            height: 24

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Choose what the dashboard shows")
                color: band.muted
                font.pixelSize: 11
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                radius: 6
                color: chooserClose.containsMouse ? band.hoverBg : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    color: chooserClose.containsMouse ? band.foreground : band.muted
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 13
                }

                SharedUi.Pressable {
                    id: chooserClose
                    anchors.fill: parent
                    theme: band.theme
                    accessibleName: qsTr("Close player list")
                    onClicked: band.choosing = false
                }
            }
        }

        ListView {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: chooserHead.bottom
            anchors.bottom: parent.bottom
            anchors.topMargin: 2
            clip: true
            spacing: 0
            boundsBehavior: Flickable.StopAtBounds
            // Elso sor: automatikus; utana a lejatszok.
            model: [null].concat(band.players)

            delegate: Rectangle {
                id: choice

                required property var modelData
                readonly property bool automatic: modelData === null
                readonly property bool current: automatic
                    ? band.pinnedDbusName === ""
                    : band.pinnedDbusName === (modelData.dbusName || "")
                readonly property bool playing: !automatic && modelData.playbackState === MprisPlaybackState.Playing

                width: ListView.view.width
                height: 34
                radius: 6
                color: choiceMouse.containsMouse ? band.hoverBg : "transparent"

                Rectangle {
                    id: choiceDot

                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6
                    height: 6
                    radius: 3
                    color: choice.playing ? band.accent : band.muted
                    opacity: choice.automatic ? 0 : 1
                }

                Column {
                    anchors.left: choiceDot.right
                    anchors.leftMargin: 10
                    anchors.right: choiceCheck.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: choice.automatic ? qsTr("Automatic") : (choice.modelData.identity || choice.modelData.dbusName || "Media")
                        textFormat: Text.PlainText
                        color: band.foreground
                        font.pixelSize: 12
                        font.weight: choice.current ? Font.Medium : Font.Normal
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: choice.automatic
                            ? qsTr("Follow whatever is playing")
                            : ((choice.modelData.trackTitle || qsTr("Nothing playing"))
                                + (choice.playing ? "" : "  ·  " + qsTr("paused")))
                        textFormat: Text.PlainText
                        color: band.muted
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }

                Text {
                    id: choiceCheck

                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰄬"
                    color: band.accent
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 14
                    opacity: choice.current ? 1 : 0
                }

                MouseArea {
                    id: choiceMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: band.choose(choice.modelData)
                }
            }
        }
    }

    // -- csendes sor ----------------------------------------------------------
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 14
        anchors.rightMargin: 8
        height: 44
        opacity: band.hasTrack || band.choosing ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Text {
            id: quietGlyph

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "󰝚"
            color: band.muted
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 14
        }

        Text {
            anchors.left: quietGlyph.right
            anchors.leftMargin: 10
            anchors.right: resume.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: band.player ? qsTr("Nothing playing in %1").arg(band.player.identity || qsTr("the player")) : qsTr("Nothing playing")
            textFormat: Text.PlainText
            color: band.muted
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        SharedUi.HeaderChip {
            id: resume

            anchors.right: playersChip.visible ? playersChip.left : parent.right
            anchors.rightMargin: playersChip.visible ? 4 : 0
            anchors.verticalCenter: parent.verticalCenter
            width: implicitWidth
            visible: band.player !== null && band.player.canPlay
            theme: band.theme
            label: qsTr("Resume")
            onClicked: band.player.play()
        }

        // Tobb lejatszonal itt is valaszthato, melyik latszodjon.
        SharedUi.HeaderChip {
            id: playersChip

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: implicitWidth
            visible: band.canChoose
            theme: band.theme
            label: qsTr("Players")
            onClicked: band.choosing = true
        }
    }
}

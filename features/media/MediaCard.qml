import QtQuick
import Quickshell.Services.Mpris
import "../../ui" as SharedUi

Item {
    id: card

    property var theme: null
    property var player: null
    property var players: []
    property bool compact: false
    property bool artworkEnabled: true
    property var cavaValues: [0, 0, 0, 0, 0, 0]
    property real livePosition: -1
    readonly property int spectrumBars: 36
    signal playerSelected(var player)
    signal seeked(real seconds)
    signal trackChangeRequested()

    readonly property string background: theme ? theme.background : "#11130f"
    readonly property string surface: theme && theme.surface ? theme.surface : "#191b16"
    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property color hoverBg: Qt.rgba(1, 1, 1, 0.075)
    readonly property color lineBg: Qt.rgba(1, 1, 1, 0.055)

    readonly property bool isPlaying: player && player.playbackState === MprisPlaybackState.Playing
    readonly property real currentPosition: livePosition >= 0 ? livePosition : (player ? player.position : 0)
    readonly property string statusLabel: !player
        ? "MEDIA IDLE"
        : (player.playbackState === MprisPlaybackState.Playing ? "NOW PLAYING" : "MEDIA PAUSED")
    readonly property string trackTitle: player && player.trackTitle !== "" ? player.trackTitle : "No music playing"
    readonly property string trackArtist: player && player.trackArtist !== ""
        ? player.trackArtist
        : (player && player.identity ? player.identity : "No active source")

    function playerIcon(value) {
        if (!value) return "󰎆"
        var name = ((value.identity || "") + " " + (value.dbusName || "")).toLowerCase()
        if (name.indexOf("firefox") !== -1 || name.indexOf("zen") !== -1 || name.indexOf("chrome") !== -1 || name.indexOf("browser") !== -1) return "󰖟"
        return "󰎆"
    }

    function restingLevel(index) {
        return 0.05 + 0.045 * Math.abs(Math.sin(index * 0.62))
    }

    function spectrumLevel(index) {
        if (!card.isPlaying || !cavaValues || cavaValues.length < 2) return restingLevel(index)
        var position = index / Math.max(1, spectrumBars - 1) * (cavaValues.length - 1)
        var lower = Math.floor(position)
        var upper = Math.min(cavaValues.length - 1, lower + 1)
        var blend = position - lower
        var raw = cavaValues[lower] * (1 - blend) + cavaValues[upper] * blend
        return raw <= 0 ? restingLevel(index) : Math.max(restingLevel(index), Math.min(1, Math.sqrt(raw / 100)))
    }

    function formatTime(seconds) {
        if (!seconds || seconds < 0) return "0:00"
        var total = Math.floor(seconds)
        return Math.floor(total / 60) + ":" + (total % 60).toString().padStart(2, "0")
    }

    function progress(value) {
        if (!value || !value.lengthSupported || value.length <= 0) return 0
        return Math.max(0, Math.min(1, card.currentPosition / value.length))
    }

    function seekSupported(value) {
        return value && value.canSeek && value.positionSupported && value.lengthSupported && value.length > 0
    }

    function seekTo(value, ratio) {
        if (!seekSupported(value)) return
        var target = Math.max(0, Math.min(1, ratio)) * value.length
        value.position = target
        value.positionChanged()
        card.seeked(target)
    }

    function volume(value) {
        if (!value || value.volume === undefined) return 0
        return Math.max(0, Math.min(1, value.volume))
    }

    function volumeSupported(value) {
        return value && value.volume !== undefined
    }

    function setVolume(value, ratio) {
        if (volumeSupported(value)) value.volume = Math.max(0, Math.min(1, ratio))
    }

    function changeTrack(value, forward) {
        if (!value || (forward ? !value.canGoNext : !value.canGoPrevious)) return
        trackChangeRequested()
        if (forward) value.next()
        else value.previous()
    }

    SharedUi.DashPanel {
        id: compactPanel
        anchors.fill: parent
        visible: card.compact
        theme: card.theme
        editorial: true
        title: card.statusLabel
        kanji: ""
        trailing: card.player && card.player.identity ? card.player.identity.toUpperCase() : "NO SOURCE"

        Rectangle {
            id: compactArtFrame
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height
            height: parent.height
            color: card.background
            border.color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1
            clip: true

            Image {
                id: compactArt
                anchors.fill: parent
                anchors.margins: 1
                source: card.artworkEnabled && card.compact && card.player && card.player.trackArtUrl !== "" ? card.player.trackArtUrl : ""
                sourceSize: Qt.size(192, 192)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                visible: status === Image.Ready
            }

            Rectangle { anchors.fill: parent; anchors.margins: 1; color: card.background; opacity: 0.18; visible: compactArt.visible }
            Text { anchors.centerIn: parent; text: "󰎆"; color: card.accent; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 34; opacity: 0.72; visible: !compactArt.visible }
        }

        Column {
            anchors.left: compactArtFrame.right
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Text {
                width: parent.width
                height: 24
                text: card.trackTitle
                color: card.foreground
                font.family: "serif"
                font.pixelSize: 20
                font.weight: Font.Medium
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                width: parent.width
                height: 15
                text: card.trackArtist
                color: card.muted
                font.pixelSize: 12
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            Item {
                width: parent.width
                height: 14

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.player && card.player.lengthSupported ? card.formatTime(card.currentPosition) : "--:--"
                    color: card.muted
                    font.pixelSize: 9
                }

                Rectangle {
                    id: compactTrack
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 44
                    anchors.rightMargin: 44
                    anchors.verticalCenter: parent.verticalCenter
                    height: 3
                    color: card.lineBg

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * card.progress(card.player)
                        color: card.accent
                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.player && card.player.lengthSupported ? card.formatTime(card.player.length) : "--:--"
                    color: card.muted
                    font.pixelSize: 9
                    horizontalAlignment: Text.AlignRight
                }
            }

            Row {
                spacing: 8
                height: 30

                Rectangle {
                    width: 34
                    height: 30
                    color: compactPrevHover.containsMouse ? card.hoverBg : "transparent"
                    border.color: card.lineBg
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "󰒮"; color: card.foreground; opacity: card.player && card.player.canGoPrevious ? 1 : 0.35; font.pixelSize: 15 }
                    MouseArea { id: compactPrevHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.changeTrack(card.player, false) }
                }

                Rectangle {
                    width: 44
                    height: 30
                    color: compactPlayHover.containsMouse ? Qt.lighter(card.accent, 1.18) : card.accent
                    Text { anchors.centerIn: parent; text: card.player && card.player.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"; color: card.background; font.pixelSize: 18 }
                    MouseArea { id: compactPlayHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (card.player && card.player.canTogglePlaying) card.player.togglePlaying() }
                }

                Rectangle {
                    width: 34
                    height: 30
                    color: compactNextHover.containsMouse ? card.hoverBg : "transparent"
                    border.color: card.lineBg
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "󰒭"; color: card.foreground; opacity: card.player && card.player.canGoNext ? 1 : 0.35; font.pixelSize: 15 }
                    MouseArea { id: compactNextHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.changeTrack(card.player, true) }
                }
            }
        }
    }

    SharedUi.DashPanel {
        id: fullPanel
        anchors.fill: parent
        visible: !card.compact
        theme: card.theme
        editorial: true
        title: "MEDIA"
        kanji: ""
        trailing: card.statusLabel

        Item {
            id: fullHead
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 168

            Rectangle {
                id: fullArtFrame
                anchors.left: parent.left
                anchors.top: parent.top
                width: parent.height
                height: parent.height
                color: card.background
                border.color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                clip: true

                Image {
                    id: fullArt
                    anchors.fill: parent
                    anchors.margins: 1
                    source: card.artworkEnabled && !card.compact && card.player && card.player.trackArtUrl !== "" ? card.player.trackArtUrl : ""
                    sourceSize: Qt.size(256, 256)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    visible: status === Image.Ready
                }

                Rectangle { anchors.fill: parent; anchors.margins: 1; color: card.background; opacity: 0.16; visible: fullArt.visible }
                Text { anchors.centerIn: parent; text: "󰎆"; color: card.accent; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 46; opacity: 0.6; visible: !fullArt.visible }
                Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 3; color: card.accent; opacity: 0.9 }
            }

            Column {
                anchors.left: fullArtFrame.right
                anchors.leftMargin: 20
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Item {
                    id: sourceStrip
                    width: parent.width
                    height: 28

                    Text {
                        id: sourceLabel
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "SOURCE"
                        color: card.accent
                        font.pixelSize: 9
                        font.letterSpacing: 2
                        font.bold: true
                    }

                    Flickable {
                        anchors.left: sourceLabel.right
                        anchors.leftMargin: 14
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 28
                        contentWidth: sourceRow.width
                        contentHeight: height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Row {
                            id: sourceRow
                            height: 28
                            spacing: 8

                            Repeater {
                                model: card.players

                                Rectangle {
                                    id: sourceChip
                                    property bool current: modelData === card.player

                                    width: Math.min(158, Math.max(104, sourceChipText.implicitWidth + 40))
                                    height: 28
                                    color: sourceChip.current ? card.accent : (sourceChipHover.containsMouse ? card.hoverBg : "transparent")
                                    border.color: sourceChip.current ? card.accent : card.lineBg
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 9
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: card.playerIcon(modelData)
                                        color: sourceChip.current ? card.background : card.accent
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        id: sourceChipText
                                        anchors.left: parent.left
                                        anchors.leftMargin: 29
                                        anchors.right: parent.right
                                        anchors.rightMargin: 9
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.identity || modelData.dbusName || "Media"
                                        color: sourceChip.current ? card.background : card.foreground
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }

                                    MouseArea {
                                        id: sourceChipHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: card.playerSelected(modelData)
                                    }
                                }
                            }

                            Rectangle {
                                width: 148
                                height: 28
                                visible: card.players.length === 0
                                color: "transparent"
                                border.color: card.lineBg
                                border.width: 1
                                Text { anchors.centerIn: parent; text: "No media source"; color: card.muted; font.pixelSize: 10 }
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    height: 58
                    text: card.trackTitle
                    color: card.foreground
                    font.family: "serif"
                    font.pixelSize: 25
                    font.weight: Font.Medium
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    width: parent.width
                    text: card.trackArtist
                    color: card.muted
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }
        }

        Item {
            id: spectrum
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: fullHead.bottom
            anchors.bottom: fullFoot.top
            anchors.topMargin: 18
            anchors.bottomMargin: 18

            Row {
                id: spectrumRow
                anchors.fill: parent
                spacing: 3

                Repeater {
                    model: card.spectrumBars

                    Rectangle {
                        required property int index

                        width: (spectrumRow.width - spectrumRow.spacing * (card.spectrumBars - 1)) / card.spectrumBars
                        height: Math.max(2, parent.height * card.spectrumLevel(index))
                        anchors.bottom: parent.bottom
                        color: card.accent
                        opacity: card.isPlaying ? 0.85 : 0.3

                        Behavior on height { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: card.accent
                opacity: 0.22
            }
        }

        Item {
            id: fullFoot
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 96

            Item {
                id: fullTimeline
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 34

                Rectangle {
                    id: playbackTrack
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    height: fullTimelineMouse.containsMouse ? 5 : 3
                    color: card.lineBg
                    Behavior on height { NumberAnimation { duration: 90 } }
                }

                Rectangle {
                    anchors.left: playbackTrack.left
                    anchors.verticalCenter: playbackTrack.verticalCenter
                    width: playbackTrack.width * card.progress(card.player)
                    height: playbackTrack.height
                    color: card.accent
                    Behavior on width { enabled: !fullTimelineMouse.pressed; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }

                Text { anchors.left: parent.left; anchors.bottom: parent.bottom; text: card.player && card.player.lengthSupported ? card.formatTime(card.currentPosition) : "--:--"; color: card.muted; font.pixelSize: 10 }
                Text { anchors.right: parent.right; anchors.bottom: parent.bottom; text: card.player && card.player.lengthSupported ? card.formatTime(card.player.length) : "--:--"; color: card.muted; font.pixelSize: 10 }

                MouseArea {
                    id: fullTimelineMouse
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 20
                    enabled: card.seekSupported(card.player)
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onPressed: (mouse) => card.seekTo(card.player, mouse.x / Math.max(1, width))
                    onPositionChanged: (mouse) => { if (pressed) card.seekTo(card.player, mouse.x / Math.max(1, width)) }
                }
            }

            Row {
                id: transportRow
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                height: 46
                spacing: 10

                Rectangle {
                    width: 50
                    height: 46
                    color: fullPrevHover.containsMouse ? card.hoverBg : "transparent"
                    border.color: card.lineBg
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "󰒮"; color: card.foreground; opacity: card.player && card.player.canGoPrevious ? 1 : 0.35; font.pixelSize: 20 }
                    MouseArea { id: fullPrevHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.changeTrack(card.player, false) }
                }

                Rectangle {
                    width: 64
                    height: 46
                    color: fullPlayHover.containsMouse ? Qt.lighter(card.accent, 1.18) : card.accent
                    Text { anchors.centerIn: parent; text: card.isPlaying ? "󰏤" : "󰐊"; color: card.background; font.pixelSize: 24 }
                    MouseArea { id: fullPlayHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (card.player && card.player.canTogglePlaying) card.player.togglePlaying() }
                }

                Rectangle {
                    width: 50
                    height: 46
                    color: fullNextHover.containsMouse ? card.hoverBg : "transparent"
                    border.color: card.lineBg
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "󰒭"; color: card.foreground; opacity: card.player && card.player.canGoNext ? 1 : 0.35; font.pixelSize: 20 }
                    MouseArea { id: fullNextHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.changeTrack(card.player, true) }
                }
            }

            Item {
                id: volumeControl
                anchors.left: transportRow.right
                anchors.leftMargin: 24
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 46
                opacity: card.volumeSupported(card.player) ? 1 : 0.35

                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "VOL"; color: card.accent; font.pixelSize: 9; font.letterSpacing: 2; font.bold: true }

                Rectangle {
                    id: volumeTrack
                    anchors.left: parent.left
                    anchors.leftMargin: 42
                    anchors.right: parent.right
                    anchors.rightMargin: 46
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4
                    color: card.lineBg

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * card.volume(card.player)
                        color: card.accent
                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }
                }

                Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: Math.round(card.volume(card.player) * 100) + "%"; color: card.muted; font.pixelSize: 9 }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: card.volumeSupported(card.player) ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onPressed: (mouse) => card.setVolume(card.player, Math.max(0, Math.min(volumeTrack.width, mouse.x - volumeTrack.x)) / Math.max(1, volumeTrack.width))
                    onPositionChanged: (mouse) => { if (pressed) card.setVolume(card.player, Math.max(0, Math.min(volumeTrack.width, mouse.x - volumeTrack.x)) / Math.max(1, volumeTrack.width)) }
                    onWheel: (wheel) => card.setVolume(card.player, card.volume(card.player) + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                }
            }
        }
    }
}

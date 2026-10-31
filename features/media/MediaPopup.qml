import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "." as MediaUi
import "../../core" as Core
import "../../ui" as SharedUi

PanelWindow {
    id: mediaPopup

    property var theme: null
    property var backend: null
    property bool opened: false
    property int barHeight: 26
    property var activePlayer: null
    // Stored as a bus name rather than an object so the choice survives the
    // popup being unloaded on close, and re-resolves if the player restarts.
    property string selectedPlayerDbusName: ""
    property var calendarNow: new Date()
    property var calendarView: new Date()
    property var monthNames: []
    property var dayNames: []
    property var cavaValues: [0, 0, 0, 0, 0, 0]
    // A kivetelek nelkuli lejatszolista (core/MprisController).
    property var players: []
    // A shell szintjen futo SystemStatsController: igy a CPU-grafikon mar a
    // megnyitas pillanataban az utolso percet mutatja, nem uresen indul.
    property var stats: null
    readonly property var selectedPlayer: {
        if (selectedPlayerDbusName === "") return null
        var players = mediaPopup.players
        for (var i = 0; i < players.length; i++) {
            if (players[i].dbusName === selectedPlayerDbusName) return players[i]
        }
        return null
    }
    readonly property var effectivePlayer: selectedPlayer || activePlayer
    readonly property real trackedPosition: positionController.valid ? positionController.position : -1

    visible: opened || sheet.reveal > 0
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "quickshell.media"
    WlrLayershell.exclusiveZone: -1

    // Melyik kartya van kinagyitva: "", "calendar" vagy "weather". Nyitaskor
    // all vissza (nem zaraskor, hogy a felcsuszo lap ne valtson nezetet).
    property string expandedCard: ""
    property string initialCard: ""

    onOpenedChanged: {
        if (opened) {
            expandedCard = initialCard
            calendarNow = new Date()
            calendarView = new Date(calendarNow.getFullYear(), calendarNow.getMonth(), 1)
        }
    }

    function changeCalendarMonth(delta) {
        calendarView = new Date(calendarView.getFullYear(), calendarView.getMonth() + delta, 1)
    }

    Core.WeatherController {
        id: weatherController
        backend: mediaPopup.backend
        active: mediaPopup.opened
    }

    Core.CalendarController {
        id: calendarController
        backend: mediaPopup.backend
        active: mediaPopup.opened
    }

    MediaUi.PlaybackPositionController {
        id: positionController
        active: mediaPopup.opened
        dbusName: mediaPopup.effectivePlayer ? (mediaPopup.effectivePlayer.dbusName || "") : ""
        trackKey: mediaPopup.effectivePlayer
            ? (mediaPopup.effectivePlayer.trackTitle || "") + "\u001f"
                + (mediaPopup.effectivePlayer.trackArtist || "") + "\u001f"
                + (mediaPopup.effectivePlayer.length || 0)
            : ""
        playing: mediaPopup.effectivePlayer && mediaPopup.effectivePlayer.playbackState === MprisPlaybackState.Playing
    }

    MouseArea { anchors.fill: parent; enabled: mediaPopup.opened; onClicked: mediaPopup.opened = false }

    Item {
        id: mediaMenuContainer
        anchors.horizontalCenter: parent.horizontalCenter
        enabled: mediaPopup.opened
        // A sav aljahoz tapad: a panel a savbol nyilik le, nem lebeg alatta.
        y: mediaPopup.barHeight
        width: Math.min(760, mediaPopup.width - 24)
        // A lap annyi, amennyi a tartalom: csendben a lejatszo osszehuzodik,
        // es vele a lap is.
        height: Math.min(dashboard.implicitHeight + 32, mediaPopup.height - mediaPopup.barHeight - 12)
        clip: true
        Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }

        SharedUi.PopupFrame {
            id: sheet
            shown: mediaPopup.opened
            anchors.fill: parent
            theme: mediaPopup.theme

            MouseArea { anchors.fill: parent; onClicked: (mouse) => mouse.accepted = true }

            Column {
                id: dashboard

                x: 16
                y: 16
                width: parent.width - 32
                spacing: 12

                MediaUi.PlayerBand {
                    width: parent.width
                    theme: mediaPopup.theme
                    player: mediaPopup.effectivePlayer
                    players: mediaPopup.players
                    pinnedDbusName: mediaPopup.selectedPlayerDbusName
                    // A borito addig marad, amig a lap latszik -- zaraskor is,
                    // kulonben a felcsuszo lapon mar ures keret lenne.
                    artworkEnabled: mediaPopup.visible
                    cavaValues: mediaPopup.cavaValues
                    livePosition: mediaPopup.trackedPosition
                    onPlayerSelected: (player) => mediaPopup.selectedPlayerDbusName = player ? (player.dbusName || "") : ""
                    onSeeked: (seconds) => positionController.adopt(seconds)
                    onTrackChangeRequested: positionController.beginTrackChange()
                }

                // A kartyak sora es a kinagyitott nezet ugyanazon a helyen
                // osztozik; a magassag valtasat a lap is kovetni tudja.
                Item {
                    id: cardsArea

                    readonly property bool expanded: mediaPopup.expandedCard !== ""

                    width: parent.width
                    // A kinagyitott nezet a sajat tartalmahoz igazodik: a naptar
                    // racsa magasabb, az idojaras alacsonyabb.
                    height: !expanded ? 250 : (mediaPopup.expandedCard === "calendar" ? (calendarController.connected ? 360 : 330) : 268)
                    focus: expanded
                    Keys.onEscapePressed: mediaPopup.expandedCard = ""

                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

                    Row {
                        id: cards

                        readonly property real share: width - spacing * 2

                        width: parent.width
                        height: 250
                        spacing: 12
                        opacity: cardsArea.expanded ? 0 : 1
                        visible: opacity > 0
                        scale: cardsArea.expanded ? 0.97 : 1

                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }

                        MediaUi.CalendarCard {
                            width: Math.round(cards.share * 0.37)
                            height: parent.height
                            theme: mediaPopup.theme
                            now: mediaPopup.calendarView
                            today: mediaPopup.calendarNow
                            monthNames: mediaPopup.monthNames
                            dayNames: mediaPopup.dayNames
                            eventIndex: calendarController.connected ? calendarController.eventsByDay : ({})
                            dense: true
                            clickable: true
                            onClicked: mediaPopup.expandedCard = "calendar"
                            onMonthChangeRequested: (delta) => mediaPopup.changeCalendarMonth(delta)
                        }

                        MediaUi.WeatherSummaryCard {
                            width: Math.round(cards.share * 0.33)
                            height: parent.height
                            theme: mediaPopup.theme
                            location: weatherController.location
                            temp: weatherController.temp
                            description: weatherController.description
                            forecast: weatherController.forecast
                            clickable: true
                            onClicked: mediaPopup.expandedCard = "weather"
                        }

                        MediaUi.SystemStatsCard {
                            width: cards.share - Math.round(cards.share * 0.37) - Math.round(cards.share * 0.33)
                            height: parent.height
                            theme: mediaPopup.theme
                            cpuUsage: mediaPopup.stats.cpuUsage
                            ramUsage: mediaPopup.stats.ramUsage
                            diskUsage: mediaPopup.stats.diskUsage
                            ramUsedGib: mediaPopup.stats.ramUsedGib
                            ramTotalGib: mediaPopup.stats.ramTotalGib
                            diskUsedGib: mediaPopup.stats.diskUsedGib
                            diskTotalGib: mediaPopup.stats.diskTotalGib
                            uptimeSeconds: mediaPopup.stats.uptimeSeconds
                            cpuHistory: mediaPopup.stats.cpuHistory
                        }
                    }

                    // A kinagyitott kartya a sajat oldalarol no ki: a naptar
                    // balrol, az idojaras kozeprol.
                    Loader {
                        id: detail

                        anchors.fill: parent
                        active: cardsArea.expanded
                        opacity: cardsArea.expanded ? 1 : 0
                        scale: cardsArea.expanded ? 1 : 0.94
                        transformOrigin: mediaPopup.expandedCard === "calendar" ? Item.Left : Item.Center
                        sourceComponent: mediaPopup.expandedCard === "calendar" ? calendarDetail : weatherDetail
                        onLoaded: cardsArea.forceActiveFocus()

                        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                    }

                    Component {
                        id: calendarDetail

                        MediaUi.CalendarDetail {
                            theme: mediaPopup.theme
                            today: mediaPopup.calendarNow
                            monthNames: mediaPopup.monthNames
                            dayNames: mediaPopup.dayNames
                            eventsEnabled: calendarController.connected
                            keyringLocked: calendarController.locked
                            eventIndex: calendarController.eventsByDay
                            onCloseRequested: mediaPopup.expandedCard = ""
                            // A bongeszo a panel mogott nyilna meg, ezert a
                            // panel bezarul.
                            onEventActivated: (link) => {
                                Qt.openUrlExternally(link)
                                mediaPopup.opened = false
                            }
                        }
                    }

                    Component {
                        id: weatherDetail

                        MediaUi.WeatherDetail {
                            theme: mediaPopup.theme
                            now: mediaPopup.calendarNow
                            location: weatherController.location
                            temp: weatherController.temp
                            feels: weatherController.feels
                            description: weatherController.description
                            humidity: weatherController.humidity
                            wind: weatherController.wind
                            pressure: weatherController.pressure
                            precip: weatherController.precip
                            sunrise: weatherController.sunrise
                            sunset: weatherController.sunset
                            forecast: weatherController.forecast
                            onCloseRequested: mediaPopup.expandedCard = ""
                        }
                    }
                }
            }
        }

        Timer {
            interval: 1000
            running: mediaPopup.opened && effectivePlayer && effectivePlayer.playbackState === MprisPlaybackState.Playing
            repeat: true
            onTriggered: effectivePlayer.positionChanged()
        }

        Timer {
            interval: 30000
            running: mediaPopup.opened
            repeat: true
            onTriggered: mediaPopup.calendarNow = new Date()
        }
    }

}

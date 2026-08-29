import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "." as MediaUi
import "../weather" as WeatherUi

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
    property int currentTab: 0
    property int previousTab: 0
    property var cavaValues: [0, 0, 0, 0, 0, 0]
    property string userName: Quickshell.env("USER") || "user"
    readonly property alias weatherLocation: weatherController.location
    readonly property alias weatherTemp: weatherController.temp
    readonly property alias weatherFeels: weatherController.feels
    readonly property alias weatherDesc: weatherController.description
    readonly property alias weatherHumidity: weatherController.humidity
    readonly property alias weatherWind: weatherController.wind
    readonly property alias weatherPressure: weatherController.pressure
    readonly property alias weatherPrecip: weatherController.precip
    readonly property alias weatherSunrise: weatherController.sunrise
    readonly property alias weatherSunset: weatherController.sunset
    readonly property alias weatherForecast: weatherController.forecast
    readonly property alias cpuUsage: statsController.cpuUsage
    readonly property alias ramUsage: statsController.ramUsage
    readonly property alias diskUsage: statsController.diskUsage
    readonly property var selectedPlayer: {
        if (selectedPlayerDbusName === "") return null
        var players = Mpris.players.values
        for (var i = 0; i < players.length; i++) {
            if (players[i].dbusName === selectedPlayerDbusName) return players[i]
        }
        return null
    }
    readonly property var effectivePlayer: selectedPlayer || activePlayer
    readonly property real trackedPosition: positionController.valid ? positionController.position : -1

    readonly property string panelBg: theme ? theme.background : "#11130f"
    readonly property string panelFg: theme ? theme.foreground : "#e8ddc7"
    readonly property string panelAccent: theme ? theme.accent : "#b7372f"
    readonly property string panelSurface: theme && theme.surface ? theme.surface : "#191b16"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property color hoverBg: Qt.rgba(1, 1, 1, 0.075)
    readonly property color lineBg: Qt.rgba(1, 1, 1, 0.055)

    visible: opened || mediaMenuContainer.opacity > 0
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "quickshell.media"
    WlrLayershell.exclusiveZone: -1

    onOpenedChanged: {
        if (opened) {
            previousTab = currentTab
            calendarNow = new Date()
            calendarView = new Date(calendarNow.getFullYear(), calendarNow.getMonth(), 1)
        }
    }

    onCurrentTabChanged: {
        if (!opened) {
            previousTab = currentTab
            return
        }
        pageUnloadTimer.restart()
    }

    function changeCalendarMonth(delta) {
        calendarView = new Date(calendarView.getFullYear(), calendarView.getMonth() + delta, 1)
    }

    function two(value) {
        return value.toString().padStart(2, "0")
    }

    function headerDate() {
        if (dayNames.length === 0 || monthNames.length === 0) return ""
        return (dayNames[(calendarNow.getDay() + 6) % 7] + ", " + monthNames[calendarNow.getMonth()] + " " + calendarNow.getDate()).toUpperCase()
    }

    WeatherUi.WeatherController {
        id: weatherController
        backend: mediaPopup.backend
        active: mediaPopup.opened && mediaPopup.currentTab === 2
    }

    MediaUi.SystemStatsController {
        id: statsController
        backend: mediaPopup.backend
        active: mediaPopup.opened && mediaPopup.currentTab === 0
    }

    MediaUi.PlaybackPositionController {
        id: positionController
        active: mediaPopup.opened && mediaPopup.currentTab !== 2
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
        y: mediaPopup.barHeight + 6
        width: Math.min(720, mediaPopup.width - 20)
        height: mediaPopup.opened ? 576 : 0
        clip: true
        opacity: mediaPopup.opened ? 1 : 0
        Behavior on height { NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            color: panelBg
            border.color: panelAccent
            border.width: 1
            radius: 0
            clip: true

            MouseArea { anchors.fill: parent; onClicked: (mouse) => mouse.accepted = true }

            Item {
                id: header
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 16
                height: 40

                Rectangle {
                    id: headerSeal
                    width: 40
                    height: 40
                    color: panelAccent

                    Text {
                        anchors.centerIn: parent
                        text: "󰕮"
                        color: panelBg
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                    }
                }

                Column {
                    anchors.left: headerSeal.right
                    anchors.leftMargin: 12
                    anchors.right: headerClock.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        text: "DASHBOARD"
                        color: panelFg
                        font.pixelSize: 12
                        font.letterSpacing: 3
                        font.bold: true
                    }

                    Text {
                        width: parent.width
                        text: mediaPopup.userName
                        color: mutedFg
                        font.pixelSize: 9
                        elide: Text.ElideRight
                    }
                }

                Column {
                    id: headerClock
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        anchors.right: parent.right
                        text: two(calendarNow.getHours()) + ":" + two(calendarNow.getMinutes())
                        color: panelFg
                        font.pixelSize: 24
                        font.weight: Font.Light
                    }

                    Text {
                        anchors.right: parent.right
                        text: mediaPopup.headerDate()
                        color: panelAccent
                        font.pixelSize: 9
                        font.letterSpacing: 2
                        font.bold: true
                    }
                }
            }

            Rectangle {
                id: headerRule
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: header.bottom
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 12
                height: 1
                color: mutedFg
                opacity: 0.35
            }

            Row {
                id: tabBar
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: headerRule.bottom
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 12
                height: 30
                spacing: 8

                Repeater {
                    model: [
                        { icon: "󰕮", label: "OVERVIEW" },
                        { icon: "󰎆", label: "MEDIA" },
                        { icon: "󰖕", label: "WEATHER" }
                    ]

                    Rectangle {
                        id: tabChip
                        property bool selected: mediaPopup.currentTab === index

                        width: (tabBar.width - tabBar.spacing * 2) / 3
                        height: tabBar.height
                        radius: 0
                        color: tabChip.selected ? panelAccent : (tabMouse.containsMouse ? hoverBg : "transparent")
                        border.color: tabChip.selected ? panelAccent : lineBg
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.icon
                                color: tabChip.selected ? panelBg : panelAccent
                                font.pixelSize: 14
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                color: tabChip.selected ? panelBg : panelFg
                                font.pixelSize: 9
                                font.letterSpacing: 2
                                font.bold: true
                            }

                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mediaPopup.currentTab = index
                        }
                    }
                }
            }

            Item {
                id: pages
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: tabBar.bottom
                anchors.bottom: parent.bottom
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 12
                anchors.bottomMargin: 16
                clip: true

                // Keep the outgoing page until the slide finishes, then unload it.
                Item {
                    id: pageTrack
                    // Animate the index, not x: a width change then repositions the
                    // track instantly instead of sliding it.
                    property real slidePosition: mediaPopup.currentTab
                    readonly property bool sliding: pageSlide.running
                    // Gap between pages so two panels read as separate sheets
                    // passing each other rather than one smeared surface.
                    readonly property real stride: pages.width + 16

                    width: pages.width
                    height: pages.height
                    x: -slidePosition * stride

                    Behavior on slidePosition {
                        NumberAnimation { id: pageSlide; duration: 320; easing.type: Easing.OutQuart }
                    }

                    Loader {
                        x: 0
                        width: pages.width
                        height: pages.height
                        enabled: mediaPopup.currentTab === 0
                        active: mediaPopup.currentTab === 0 || mediaPopup.previousTab === 0

                        sourceComponent: Column {
                            anchors.fill: parent
                            spacing: 12

                            MediaUi.MediaCard {
                                width: parent.width
                                height: 168
                                theme: mediaPopup.theme
                                player: mediaPopup.effectivePlayer
                                players: Mpris.players.values
                                compact: true
                                artworkEnabled: mediaPopup.currentTab === 0
                                livePosition: mediaPopup.trackedPosition
                                onPlayerSelected: (player) => mediaPopup.selectedPlayerDbusName = player ? (player.dbusName || "") : ""
                                onSeeked: (seconds) => positionController.adopt(seconds)
                                onTrackChangeRequested: positionController.beginTrackChange()
                            }

                            Row {
                                width: parent.width
                                height: parent.height - 180
                                spacing: 12

                                MediaUi.CalendarCard {
                                    width: parent.width - 244
                                    height: parent.height
                                    theme: mediaPopup.theme
                                    now: mediaPopup.calendarView
                                    today: mediaPopup.calendarNow
                                    monthNames: mediaPopup.monthNames
                                    dayNames: mediaPopup.dayNames
                                    dense: true
                                    onMonthChangeRequested: (delta) => mediaPopup.changeCalendarMonth(delta)
                                }

                                MediaUi.SystemStatsCard {
                                    width: 232
                                    height: parent.height
                                    theme: mediaPopup.theme
                                    cpuUsage: statsController.cpuUsage
                                    ramUsage: statsController.ramUsage
                                    diskUsage: statsController.diskUsage
                                }
                            }
                        }
                    }

                    Loader {
                        x: pageTrack.stride
                        width: pages.width
                        height: pages.height
                        enabled: mediaPopup.currentTab === 1
                        active: mediaPopup.currentTab === 1 || mediaPopup.previousTab === 1

                        sourceComponent: MediaUi.MediaCard {
                            anchors.fill: parent
                            theme: mediaPopup.theme
                            player: mediaPopup.effectivePlayer
                            players: Mpris.players.values
                            compact: false
                            cavaValues: mediaPopup.cavaValues
                            artworkEnabled: mediaPopup.currentTab === 1
                            livePosition: mediaPopup.trackedPosition
                            onPlayerSelected: (player) => mediaPopup.selectedPlayerDbusName = player ? (player.dbusName || "") : ""
                            onSeeked: (seconds) => positionController.adopt(seconds)
                            onTrackChangeRequested: positionController.beginTrackChange()
                        }
                    }

                    Loader {
                        x: pageTrack.stride * 2
                        width: pages.width
                        height: pages.height
                        enabled: mediaPopup.currentTab === 2
                        active: mediaPopup.currentTab === 2 || mediaPopup.previousTab === 2

                        sourceComponent: WeatherUi.WeatherCard {
                            anchors.fill: parent
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
                        }
                    }
                }
            }
        }

        Timer {
            id: pageUnloadTimer
            interval: 360
            onTriggered: mediaPopup.previousTab = mediaPopup.currentTab
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

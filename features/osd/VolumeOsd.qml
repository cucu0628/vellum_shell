import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// Hangero-OSD a kepernyo aljan, a shell kulonallo paneljeinek formajaban:
// kerekitett lap halvany kerettel, balra csempe, mellette cim, egy
// metaadat-sor es a sav. Harom valtozata van: a rendszer hangereje (kimeneti
// eszkoz), a zene sajat hangereje (MPRIS lejatszo, boritoval) es a beepitett
// kijelzo fenyereje.
PanelWindow {
    id: osd

    property var theme: null
    property int volumePercent: 0
    property bool muted: false
    property bool shown: false
    // "system", "music" vagy "brightness".
    property string mode: "system"
    property string title: ""
    property string detail: ""
    property string artUrl: ""

    readonly property bool music: mode === "music"
    readonly property bool brightness: mode === "brightness"
    readonly property color panelBg: theme ? theme.background : "#15110f"
    readonly property color panelFg: theme ? theme.foreground : "#f1e7d0"
    readonly property color panelAccent: theme ? theme.accent : "#d7472f"
    readonly property color mutedFg: theme && theme.muted ? theme.muted : "#9f8f7c"
    readonly property color surface: theme && theme.surface ? theme.surface : "#1b1613"
    readonly property real volumeRatio: Math.max(0, Math.min(1, volumePercent / 100))

    function present(targetScreen) {
        if (targetScreen) screen = targetScreen
        shown = true
        hideTimer.restart()
    }

    // A rendszer hangereje: az alapertelmezett kimenet neve a cim.
    function showVolume(percent, isMuted, targetScreen, deviceName) {
        mode = "system"
        volumePercent = percent
        muted = isMuted
        title = deviceName || qsTr("Volume")
        detail = qsTr("System volume")
        artUrl = ""
        present(targetScreen)
    }

    // A zene sajat hangereje: a szam cime, alatta a lejatszo neve.
    function showPlayerVolume(percent, player, targetScreen) {
        mode = "music"
        volumePercent = percent
        muted = false
        title = player && player.trackTitle ? player.trackTitle : qsTr("Music")
        detail = qsTr("Music volume") + (player && player.identity ? "  ·  " + player.identity : "")
        artUrl = player && player.trackArtUrl ? player.trackArtUrl : ""
        present(targetScreen)
    }

    // A beepitett kijelzo fenyereje; a szazalek a savon is ugyanugy latszik.
    function showBrightness(percent, targetScreen) {
        mode = "brightness"
        volumePercent = percent
        muted = false
        title = qsTr("Brightness")
        detail = qsTr("Built-in display")
        artUrl = ""
        present(targetScreen)
    }

    visible: shown || card.opacity > 0
    implicitWidth: 352
    implicitHeight: 84
    color: "transparent"
    mask: Region {}
    anchors.bottom: true
    margins.bottom: 42
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "quickshell.volume-osd"
    WlrLayershell.exclusiveZone: -1

    Rectangle {
        id: card

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 2
        height: 68
        radius: 12
        color: osd.panelBg
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
        opacity: osd.shown ? 1 : 0
        // Alulrol usztat a helyere, eltuneskor vissza.
        transform: Translate {
            y: (1 - card.opacity) * 8
        }

        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        // Rendszer: akcentes csempe a hangszoroval. Zene: a borito, ha van.
        Rectangle {
            id: tile

            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 44
            radius: 10
            color: osd.music || osd.muted
                ? osd.surface
                : Qt.rgba(osd.panelAccent.r, osd.panelAccent.g, osd.panelAccent.b, 0.16)

            Behavior on color { ColorAnimation { duration: 140 } }

            Text {
                anchors.centerIn: parent
                visible: !artClip.visible
                text: osd.music
                    ? "󰝚"
                    : osd.brightness
                        ? (osd.volumePercent < 34 ? "󰃞" : (osd.volumePercent < 67 ? "󰃟" : "󰃠"))
                        : (osd.muted || osd.volumePercent === 0 ? "󰖁" : (osd.volumePercent < 50 ? "󰖀" : "󰕾"))
                color: osd.muted ? osd.mutedFg : osd.panelAccent
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 20
            }

            ClippingRectangle {
                id: artClip

                anchors.fill: parent
                radius: tile.radius
                color: "transparent"
                visible: osd.music && art.status === Image.Ready

                Image {
                    id: art

                    anchors.fill: parent
                    source: osd.music ? osd.artUrl : ""
                    sourceSize: Qt.size(88, 88)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                }
            }
        }

        // A zene jele a borito sarkan, hogy kepes boritonal is egyertelmu legyen.
        Rectangle {
            visible: artClip.visible
            anchors.right: tile.right
            anchors.bottom: tile.bottom
            anchors.rightMargin: -4
            anchors.bottomMargin: -4
            width: 20
            height: 20
            radius: 10
            color: osd.panelBg

            Rectangle {
                anchors.centerIn: parent
                width: 16
                height: 16
                radius: 8
                color: osd.panelAccent

                Text {
                    anchors.centerIn: parent
                    text: "󰝚"
                    color: osd.panelBg
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 10
                }
            }
        }

        Column {
            anchors.left: tile.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Item {
                width: parent.width
                height: 16

                Text {
                    anchors.left: parent.left
                    anchors.right: percentText.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: osd.title
                    textFormat: Text.PlainText
                    color: osd.panelFg
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    id: percentText

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: osd.muted ? qsTr("Muted") : osd.volumePercent + "%"
                    color: osd.muted ? osd.mutedFg : osd.panelFg
                    font.pixelSize: 12
                    font.features: { "tnum": 1 }
                }
            }

            Text {
                width: parent.width
                text: osd.detail
                textFormat: Text.PlainText
                color: osd.mutedFg
                font.pixelSize: 10
                elide: Text.ElideRight
            }

            Item {
                width: parent.width
                height: 14

                Rectangle {
                    id: track

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.1)

                    Rectangle {
                        width: Math.max(osd.volumeRatio > 0 ? track.height : 0, track.width * osd.volumeRatio)
                        height: parent.height
                        radius: parent.radius
                        color: osd.muted ? osd.mutedFg : osd.panelAccent
                        opacity: osd.muted ? 0.5 : 1
                        Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: osd.shown = false
    }
}

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: osd

    property var theme: null
    property int volumePercent: 0
    property bool muted: false
    property bool shown: false

    readonly property color panelBg: theme ? theme.background : "#15110f"
    readonly property color panelFg: theme ? theme.foreground : "#f1e7d0"
    readonly property color panelAccent: theme ? theme.accent : "#d7472f"
    readonly property color mutedFg: theme && theme.muted ? theme.muted : "#9f8f7c"
    readonly property real volumeRatio: Math.max(0, Math.min(1, volumePercent / 150))

    function showVolume(percent, isMuted, targetScreen) {
        if (targetScreen) screen = targetScreen
        volumePercent = percent
        muted = isMuted
        shown = true
        hideTimer.restart()
    }

    visible: shown || content.opacity > 0
    implicitWidth: 360
    implicitHeight: 70
    color: "transparent"
    mask: Region {}
    anchors.bottom: true
    margins.bottom: 42
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "quickshell.volume-osd"
    WlrLayershell.exclusiveZone: -1

    Rectangle {
        id: content

        anchors.fill: parent
        color: osd.panelBg
        border.color: osd.panelAccent
        border.width: 1
        radius: 0
        opacity: osd.shown ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 3
            color: osd.panelAccent
            opacity: osd.muted ? 0.45 : 1
        }

        Row {
            anchors.fill: parent
            anchors.margins: 14
            anchors.leftMargin: 18
            spacing: 12

            Text {
                width: 24
                height: parent.height
                text: osd.muted || osd.volumePercent === 0 ? "" : ""
                color: osd.muted ? osd.mutedFg : osd.panelAccent
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 20
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }

            Column {
                width: parent.width - 36
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Row {
                    width: parent.width
                    height: 14

                    Text {
                        width: parent.width - 56
                        text: "VOLUME"
                        color: osd.panelAccent
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 3
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        width: 56
                        text: osd.muted ? "MUTE" : osd.volumePercent + "%"
                        color: osd.muted ? osd.mutedFg : osd.panelFg
                        font.family: "monospace"
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Item {
                    width: parent.width
                    height: 5

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(1, 1, 1, 0.12)
                    }

                    Rectangle {
                        width: parent.width * osd.volumeRatio
                        height: parent.height
                        color: osd.muted ? osd.mutedFg : osd.panelAccent
                        opacity: osd.muted ? 0.45 : 1
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

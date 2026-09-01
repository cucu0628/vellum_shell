import QtQuick
import Quickshell
import Quickshell.Wayland
import "." as AboutUi
import "../../ui" as SharedUi

PanelWindow {
    id: aboutWindow

    property var theme: null
    property bool opened: false
    property alias themeName: systemInfo.themeName
    property int shellUptime: 0

    readonly property string panelFg: theme ? theme.foreground : "#e8ddc7"
    readonly property string panelAccent: theme ? theme.accent : "#b7372f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string inkBg: theme && theme.surface ? theme.surface : "#191b16"

    readonly property string screensText: {
        var count = Quickshell.screens ? Quickshell.screens.length : 0
        return count === 1 ? "1 connected" : count + " connected"
    }

    readonly property var shellItems: [
        { icon: "󰋼", label: "Version", value: systemInfo.shellVersion },
        { icon: "󰔛", label: "Running", value: formatUptime(shellUptime) },
        { icon: "󰒓", label: "Runtime", value: systemInfo.quickshellVersion },
        { icon: "󰐱", label: "Modules", value: systemInfo.moduleSummary },
        { icon: "󱄄", label: "Screens", value: screensText },
        { icon: "󰉉", label: "Wallpaper", value: systemInfo.wallpaperName },
        { icon: "󰉋", label: "Config", value: systemInfo.configPath }
    ].filter(function (item) { return item.value !== ""; })

    readonly property int shellRows: Math.max(1, shellItems.length)
    // DashPanel chrome is 60px; the ledger uses compact 38px records.
    readonly property int panelHeight: 60 + shellRows * 38
    readonly property int frameHeight: 20 + 52 + 16 + panelHeight + 20

    function formatUptime(seconds) {
        if (seconds <= 0) return "just started"
        var days = Math.floor(seconds / 86400)
        var hours = Math.floor((seconds % 86400) / 3600)
        var minutes = Math.floor((seconds % 3600) / 60)
        if (days > 0) return days + "d " + hours + "h"
        if (hours > 0) return hours + "h " + minutes + "m"
        if (minutes > 0) return minutes + "m " + (seconds % 60) + "s"
        return seconds + "s"
    }

    function updateUptime() {
        var launched = Quickshell.launchTime
        if (!launched) return
        shellUptime = Math.max(0, Math.floor((Date.now() - launched.getTime()) / 1000))
    }

    onOpenedChanged: if (opened) {
        systemInfo.refreshInfo()
        updateUptime()
    }

    function parseInfo(output) { systemInfo.parseInfo(output) }
    function refreshInfo() { systemInfo.refreshInfo() }

    AboutUi.SystemInfoController { id: systemInfo }

    Timer {
        interval: 1000
        running: aboutWindow.opened
        repeat: true
        onTriggered: aboutWindow.updateUptime()
    }

    visible: opened || content.opacity > 0
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "quickshell.about"
    WlrLayershell.exclusiveZone: -1

    MouseArea { anchors.fill: parent; enabled: opened; onClicked: opened = false }

    Item {
        id: content
        anchors.centerIn: parent
        enabled: opened
        width: Math.min(820, parent.width - 44)
        height: Math.min(aboutWindow.frameHeight, parent.height - 64)
        opacity: opened ? 1 : 0
        scale: opened ? 1 : 0.96
        transform: Translate {
            y: aboutWindow.opened ? 0 : 12
            Behavior on y { NumberAnimation { duration: aboutWindow.opened ? 240 : 120; easing.type: aboutWindow.opened ? Easing.OutQuart : Easing.InQuad } }
        }
        Behavior on opacity { NumberAnimation { duration: aboutWindow.opened ? 160 : 110; easing.type: aboutWindow.opened ? Easing.OutQuart : Easing.InQuad } }
        Behavior on scale { NumberAnimation { duration: aboutWindow.opened ? 260 : 130; easing.type: aboutWindow.opened ? Easing.OutQuart : Easing.InQuad } }

        SharedUi.PopupFrame {
            anchors.fill: parent
            theme: aboutWindow.theme

            MouseArea { anchors.fill: parent; onClicked: (mouse) => mouse.accepted = true }

            SharedUi.PopupHeader {
                id: header

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                anchors.topMargin: 20
                theme: aboutWindow.theme
                title: "About Vellum"
                subtitle: "Shell identity / runtime ledger"
                trailingWidth: 168

                Column {
                    width: parent.width
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 2

                    Text {
                        anchors.right: parent.right
                        text: systemInfo.shellVersion !== "" ? systemInfo.shellVersion : "Vellum Shell"
                        color: panelFg
                        font.family: "monospace"
                        font.pixelSize: 9
                    }

                    Text {
                        anchors.right: parent.right
                        text: aboutWindow.themeName !== "" ? "THEME / " + aboutWindow.themeName.toUpperCase() : "THEME / UNSET"
                        color: panelAccent
                        font.pixelSize: 7
                        font.letterSpacing: 1.4
                        font.bold: true
                    }
                }
            }

            Row {
                id: body
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: header.bottom
                anchors.bottom: parent.bottom
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                anchors.topMargin: 16
                anchors.bottomMargin: 20
                spacing: 16

                Rectangle {
                    id: identityPlate

                    width: 252
                    height: body.height
                    color: inkBg
                    border.color: Qt.rgba(1, 1, 1, 0.09)
                    border.width: 1

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        width: 2
                        height: 82
                        color: panelAccent
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.top: parent.top
                        anchors.topMargin: 14
                        text: "01 / IDENTITY"
                        color: mutedFg
                        font.family: "monospace"
                        font.pixelSize: 7
                        font.letterSpacing: 1.2
                    }

                    SharedUi.ShellLogo {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 48
                        size: 142
                        color: panelAccent
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 18
                        spacing: 5

                        Text {
                            width: parent.width
                            text: "Vellum Shell"
                            color: panelFg
                            font.family: "serif"
                            font.pixelSize: 25
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text {
                            width: parent.width
                            text: "QUICKSHELL / HYPRLAND"
                            color: mutedFg
                            font.pixelSize: 7
                            font.letterSpacing: 1.8
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Rectangle {
                            width: 42
                            height: 1
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: panelAccent
                        }

                        Text {
                            width: parent.width
                            text: systemInfo.userHost !== "" ? systemInfo.userHost : "desktop shell"
                            color: panelFg
                            font.family: "monospace"
                            font.pixelSize: 9
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: aboutWindow.themeName !== "" ? aboutWindow.themeName.toUpperCase() : "NO ACTIVE THEME"
                            color: panelAccent
                            font.pixelSize: 7
                            font.bold: true
                            font.letterSpacing: 1.4
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                }

                AboutUi.InfoSectionCard {
                    width: body.width - identityPlate.width - body.spacing
                    height: body.height
                    theme: aboutWindow.theme
                    title: "RUNTIME LEDGER"
                    kanji: ""
                    trailing: shellItems.length + " RECORDS"
                    entries: aboutWindow.shellItems
                }
            }
        }
    }
}

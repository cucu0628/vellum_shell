import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../ui" as SharedUi

PanelWindow {
    id: aiWindow

    property var theme: null
    property bool opened: false
    property bool refreshing: false
    property var claude: emptyProvider("claude", "Claude Code")
    property var codex: emptyProvider("codex", "Codex")
    readonly property string panelBg: theme ? theme.background : "#15110f"
    readonly property string panelFg: theme ? theme.foreground : "#f1e7d0"
    readonly property string panelAccent: theme ? theme.accent : "#d7472f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#9f8f7c"
    readonly property string inkBg: theme && theme.surface ? theme.surface : "#1b1613"

    function emptyProvider(id, name) {
        return { "id": id, "name": name, "plan": "", "ready": false, "status": "Not loaded", "limits": [] }
    }

    function refresh(force) {
        if (claudeProcess.running || codexProcess.running)
            return
        refreshing = true
        claudeProcess.command = [Quickshell.env("HOME") + "/.config/quickshell/vellum_shell/scripts/ai-usage-claude"]
        codexProcess.command = [Quickshell.env("HOME") + "/.config/quickshell/vellum_shell/scripts/ai-usage-codex"]
        if (force) {
            claudeProcess.command.push("--force")
            codexProcess.command.push("--force")
        }
        claudeProcess.running = true
        codexProcess.running = true
    }

    function parseProvider(text, fallback) {
        try {
            return JSON.parse((text || "").trim())
        } catch (error) {
            return { "id": fallback.id, "name": fallback.name, "plan": "", "ready": false, "status": "Invalid usage response", "limits": [] }
        }
    }

    function processFinished() {
        refreshing = claudeProcess.running || codexProcess.running
    }

    function percent(value) {
        return Math.round(Math.max(0, Math.min(1, Number(value) || 0)) * 100)
    }

    function resetText(value) {
        if (!value)
            return "Reset time unavailable"
        var date = new Date(value)
        if (isNaN(date.getTime()))
            return "Reset " + value
        return "Resets " + Qt.formatDateTime(date, "MMM d, HH:mm")
    }

    function providerHeight(provider) {
        var count = Math.min(2, (provider.limits || []).length)
        return count > 0 ? 58 + count * 63 : 104
    }

    readonly property real panelContentHeight: 126 + providerHeight(claude) + providerHeight(codex)

    onOpenedChanged: if (opened) refresh(false)
    visible: opened || content.opacity > 0
    color: "transparent"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "quickshell.ai-usage"
    WlrLayershell.exclusiveZone: -1

    anchors { top: true; bottom: true; left: true; right: true }

    MouseArea {
        anchors.fill: parent
        enabled: opened
        onClicked: opened = false
    }

    Item {
        id: content
        anchors.right: parent.right
        anchors.rightMargin: 10
        enabled: opened
        y: 32
        width: Math.min(430, parent.width - 20)
        height: opened ? Math.min(panelContentHeight, parent.height - 46) : 0
        clip: true
        opacity: opened ? 1 : 0

        SharedUi.PopupFrame {
            anchors.fill: parent
            theme: aiWindow.theme

            MouseArea { anchors.fill: parent; onClicked: mouse => mouse.accepted = true }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                SharedUi.PopupHeader {
                    width: parent.width
                    theme: aiWindow.theme
                    title: "AI Allowances"
                    subtitle: refreshing ? "Updating provider limits..." : "Subscription windows and reset times"
                    trailingWidth: 70

                    Text {
                        anchors.fill: parent
                        text: refreshing ? "WAIT" : "Refresh"
                        color: refreshMouse.containsMouse && !refreshing ? panelAccent : mutedFg
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        font.family: "monospace"
                        font.pixelSize: 10
                        MouseArea {
                            id: refreshMouse
                            anchors.fill: parent
                            enabled: !refreshing
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: refresh(true)
                        }
                    }
                }

                Repeater {
                    model: 2
                    delegate: Rectangle {
                        id: providerCard

                        required property int index
                        readonly property var provider: index === 0 ? aiWindow.claude : aiWindow.codex
                        width: parent.width
                        height: aiWindow.providerHeight(provider)
                        color: inkBg
                        border.color: Qt.rgba(1, 1, 1, 0.07)

                        Rectangle {
                            anchors.left: parent.left
                            width: 3
                            height: parent.height
                            color: providerCard.provider.ready ? panelAccent : mutedFg
                        }

                        Column {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 14
                            anchors.topMargin: 12
                            anchors.bottomMargin: 12
                            spacing: 9

                            Row {
                                width: parent.width
                                height: 25
                                Text {
                                    width: parent.width - 130
                                    height: parent.height
                                    text: providerCard.provider.name.toUpperCase()
                                    color: panelFg
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.letterSpacing: 2
                                }
                                Text {
                                    width: 130
                                    height: parent.height
                                    text: providerCard.provider.plan ? String(providerCard.provider.plan).toUpperCase() : ""
                                    color: panelAccent
                                    horizontalAlignment: Text.AlignRight
                                    verticalAlignment: Text.AlignVCenter
                                    font.family: "monospace"
                                    font.pixelSize: 9
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: panelAccent
                                opacity: 0.18
                            }

                            Repeater {
                                model: (providerCard.provider.limits || []).slice(0, 2)
                                delegate: Column {
                                    id: usageRow

                                    required property var modelData
                                    property real displayedRemaining: 0
                                    property bool initialized: false
                                    readonly property int segmentCount: 18
                                    readonly property real targetRemaining: Math.max(0, Math.min(1, Number(modelData.remaining) || 0))
                                    width: parent.width
                                    height: 53
                                    spacing: 3

                                    Component.onCompleted: {
                                        initialized = true
                                        fillAnimation.restart()
                                    }
                                    onTargetRemainingChanged: {
                                        if (initialized)
                                            fillAnimation.restart()
                                    }

                                    SequentialAnimation {
                                        id: fillAnimation

                                        PauseAnimation { duration: 100 }
                                        NumberAnimation {
                                            target: usageRow
                                            property: "displayedRemaining"
                                            from: 0
                                            to: usageRow.targetRemaining
                                            duration: 720
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    Row {
                                        width: parent.width
                                        height: 19

                                        Text {
                                            width: parent.width - 92
                                            height: parent.height
                                            text: (modelData.label || "Limit").toUpperCase()
                                            color: panelFg
                                            font.pixelSize: 9
                                            font.letterSpacing: 1.3
                                            font.bold: true
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: 66
                                            height: parent.height
                                            text: percent(modelData.remaining) + "%"
                                            color: panelAccent
                                            horizontalAlignment: Text.AlignRight
                                            verticalAlignment: Text.AlignVCenter
                                            font.family: "serif"
                                            font.pixelSize: 16
                                            font.weight: Font.Medium
                                        }

                                        Text {
                                            width: 26
                                            height: parent.height
                                            text: "LEFT"
                                            color: mutedFg
                                            horizontalAlignment: Text.AlignRight
                                            verticalAlignment: Text.AlignVCenter
                                            font.pixelSize: 7
                                            font.letterSpacing: 1
                                        }
                                    }

                                    Row {
                                        id: usageRuler

                                        width: parent.width
                                        height: 9
                                        spacing: 3

                                        Repeater {
                                            model: usageRow.segmentCount

                                            Rectangle {
                                                required property int index

                                                width: (usageRuler.width - usageRuler.spacing * (usageRow.segmentCount - 1)) / usageRow.segmentCount
                                                height: index % 6 === 5 ? 9 : 6
                                                anchors.bottom: parent.bottom
                                                color: panelAccent
                                                opacity: usageRow.displayedRemaining * usageRow.segmentCount >= index + 1 ? 0.92 : 0.12

                                                Behavior on opacity {
                                                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                                                }
                                            }
                                        }
                                    }

                                    Item {
                                        width: parent.width
                                        height: 13

                                        Text {
                                            anchors.left: parent.left
                                            text: "USED  " + percent(modelData.used) + "%"
                                            color: mutedFg
                                            font.family: "monospace"
                                            font.pixelSize: 8
                                            font.letterSpacing: 0.8
                                        }

                                        Text {
                                            anchors.right: parent.right
                                            width: parent.width - 82
                                            text: resetText(modelData.resetsAt)
                                            color: mutedFg
                                            horizontalAlignment: Text.AlignRight
                                            font.family: "monospace"
                                            font.pixelSize: 8
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                height: 26
                                visible: !providerCard.provider.limits || providerCard.provider.limits.length === 0
                                text: providerCard.provider.status || "No limit data returned"
                                color: mutedFg
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    height: 12
                    text: "Values are reported by Anthropic and the Codex app server."
                    color: mutedFg
                    horizontalAlignment: Text.AlignHCenter
                    font.family: "monospace"
                    font.pixelSize: 8
                    elide: Text.ElideRight
                }
            }
        }

        Behavior on height { NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }

    Process {
        id: claudeProcess
        stdout: StdioCollector { onStreamFinished: aiWindow.claude = aiWindow.parseProvider(text, aiWindow.emptyProvider("claude", "Claude Code")) }
        onExited: aiWindow.processFinished()
    }

    Process {
        id: codexProcess
        stdout: StdioCollector { onStreamFinished: aiWindow.codex = aiWindow.parseProvider(text, aiWindow.emptyProvider("codex", "Codex")) }
        onExited: aiWindow.processFinished()
    }
}

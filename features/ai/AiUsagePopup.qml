import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../ui" as SharedUi

PanelWindow {
    id: aiWindow

    property var theme: null
    required property string shellDir
    property bool opened: false
    property int barHeight: 26
    property bool refreshing: false
    property var claude: emptyProvider("claude", "Claude Code")
    property var codex: emptyProvider("codex", "Codex")
    readonly property string panelFg: theme ? theme.foreground : "#f1e7d0"
    readonly property string panelAccent: theme ? theme.accent : "#d7472f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#9f8f7c"

    function emptyProvider(id, name) {
        return { "id": id, "name": name, "plan": "", "ready": false, "status": "Not loaded", "limits": [] }
    }

    function refresh(force) {
        if (claudeProcess.running || codexProcess.running)
            return
        refreshing = true
        claudeProcess.command = [shellDir + "/scripts/ai-usage-claude"]
        codexProcess.command = [shellDir + "/scripts/ai-usage-codex"]
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

    function planText(plan) {
        var text = plan ? String(plan) : ""
        return text === "" ? "" : text.charAt(0).toUpperCase() + text.slice(1)
    }

    // DashPanel: fejlec es margok (50) + limitenkent 50, koztuk 12.
    function providerHeight(provider) {
        var count = Math.min(2, (provider.limits || []).length)
        return 50 + (count > 0 ? count * 50 + (count - 1) * 12 : 32)
    }

    readonly property real panelContentHeight: 126 + providerHeight(claude) + providerHeight(codex)

    onOpenedChanged: if (opened) refresh(false)
    visible: opened || sheet.reveal > 0
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
        anchors.rightMargin: 0
        enabled: opened
        // A sav aljahoz tapad: a panel a savbol nyilik le, nem lebeg alatta.
        y: aiWindow.barHeight
        width: Math.min(420, parent.width - 20)
        height: Math.min(panelContentHeight, parent.height - aiWindow.barHeight - 12)
        clip: true

        SharedUi.PopupFrame {
            id: sheet
            rightEar: false
            squareRight: true
            shown: aiWindow.opened
            anchors.fill: parent
            theme: aiWindow.theme

            MouseArea { anchors.fill: parent; onClicked: mouse => mouse.accepted = true }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                SharedUi.PopupHeader {
                    width: parent.width
                    theme: aiWindow.theme
                    title: "AI Allowances"
                    subtitle: refreshing ? "Updating provider limits…" : "Subscription windows and reset times"
                    trailingWidth: 76

                    SharedUi.HeaderChip {
                        anchors.fill: parent
                        anchors.bottomMargin: 6
                        theme: aiWindow.theme
                        enabled: !refreshing
                        label: "Refresh"
                        accessibleName: qsTr("Refresh AI usage")
                        onClicked: refresh(true)
                    }
                }

                Repeater {
                    model: 2
                    delegate: SharedUi.DashPanel {
                        id: providerCard

                        required property int index
                        readonly property var provider: index === 0 ? aiWindow.claude : aiWindow.codex
                        width: parent.width
                        height: aiWindow.providerHeight(provider)
                        theme: aiWindow.theme
                        title: providerCard.provider.name.toUpperCase()
                        trailing: aiWindow.planText(providerCard.provider.plan)

                        Column {
                            width: parent.width
                            spacing: 12

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
                                    height: 50
                                    spacing: 4

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

                                    Item {
                                        width: parent.width
                                        height: 20

                                        Text {
                                            anchors.left: parent.left
                                            anchors.right: remainingRow.left
                                            anchors.rightMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: usageRow.modelData.label || "Limit"
                                            textFormat: Text.PlainText
                                            color: panelFg
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                        }

                                        Row {
                                            id: remainingRow

                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 4

                                            Text {
                                                anchors.baseline: leftLabel.baseline
                                                text: percent(usageRow.modelData.remaining) + "%"
                                                color: panelFg
                                                font.family: "serif"
                                                font.pixelSize: 16
                                                font.weight: Font.Medium
                                                font.features: { "tnum": 1 }
                                            }

                                            Text {
                                                id: leftLabel

                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "left"
                                                color: mutedFg
                                                font.pixelSize: 10
                                            }
                                        }
                                    }

                                    Row {
                                        id: usageRuler

                                        width: parent.width
                                        height: 8
                                        spacing: 3

                                        Repeater {
                                            model: usageRow.segmentCount

                                            Rectangle {
                                                required property int index

                                                width: (usageRuler.width - usageRuler.spacing * (usageRow.segmentCount - 1)) / usageRow.segmentCount
                                                height: index % 6 === 5 ? 8 : 6
                                                radius: 1.5
                                                anchors.bottom: parent.bottom
                                                color: panelAccent
                                                opacity: usageRow.displayedRemaining * usageRow.segmentCount >= index + 1 ? 0.92 : 0.14

                                                Behavior on opacity {
                                                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                                                }
                                            }
                                        }
                                    }

                                    Item {
                                        width: parent.width
                                        height: 14

                                        Text {
                                            id: usedText

                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Used " + percent(usageRow.modelData.used) + "%"
                                            color: mutedFg
                                            font.pixelSize: 10
                                        }

                                        Text {
                                            anchors.left: usedText.right
                                            anchors.leftMargin: 12
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: resetText(usageRow.modelData.resetsAt)
                                            color: mutedFg
                                            horizontalAlignment: Text.AlignRight
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                height: 32
                                visible: !providerCard.provider.limits || providerCard.provider.limits.length === 0
                                text: providerCard.provider.status || "No limit data returned"
                                textFormat: Text.PlainText
                                color: mutedFg
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    height: 14
                    text: "Values are reported by Anthropic and the Codex app server."
                    color: mutedFg
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }

        Behavior on height { NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }
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

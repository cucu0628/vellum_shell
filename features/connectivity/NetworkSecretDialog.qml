pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../ui" as SharedUi

// A NetworkManager jelszokerese (lasd NetworkSecretAgent). Teljes kepernyos
// overlay, mint a Polkit dialogus: a kerdes a kapcsolodas kozben, barmikor
// johet, es amig nincs valasz, a kapcsolat var.
PanelWindow {
    id: window

    required property var agent
    property var theme: null
    property var screenProvider: null

    readonly property var request: agent ? agent.request : null
    readonly property bool opened: request !== null
    readonly property var fields: request && request.fields ? request.fields : []
    readonly property string networkName: request ? (request.ssid || request.connection || "this network") : ""
    readonly property string panelBg: theme ? theme.background : "#11130f"
    readonly property string panelFg: theme ? theme.foreground : "#e8ddc7"
    readonly property string panelAccent: theme ? theme.accent : "#b7372f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string inkBg: theme && theme.surface ? theme.surface : "#191b16"
    readonly property string warningFg: theme && theme.warning ? theme.warning : "#c9693f"

    // Mezonev -> beirt ertek; a keres valtasakor uresre all.
    property var values: ({})
    property bool revealed: false
    readonly property bool complete: {
        for (var i = 0; i < fields.length; i++) {
            if (!values[fields[i].key]) return false
        }
        return fields.length > 0
    }

    function titleText() {
        if (!request) return ""
        switch (request.kind) {
        case "8021x":
        case "8021x-tls":
            return "Network sign-in"
        case "pppoe":
            return "PPPoE password"
        default:
            return "Wi-Fi password"
        }
    }

    function messageText() {
        if (!request) return ""
        var name = "“" + networkName + "”"
        if (request.retry) return "The password for " + name + " was not accepted. Enter it again."
        switch (request.kind) {
        case "8021x":
            return request.identity !== ""
                ? "Sign in to " + name + " as " + request.identity + "."
                : "Sign in to " + name + "."
        case "8021x-tls":
            return "Unlock the private key used for " + name + "."
        case "pppoe":
            return name + " needs your PPPoE password."
        default:
            return name + " needs a password to connect."
        }
    }

    function setValue(key, text) {
        var next = {}
        for (var existing in values) next[existing] = values[existing]
        next[key] = text
        values = next
    }

    function submit() {
        if (!complete || !agent || agent.busy) return
        agent.reply(values)
    }

    function cancel() {
        if (agent) agent.cancel()
    }

    function focusFirst() {
        var first = fieldRepeater.itemAt(0)
        if (first) first.focusInput()
    }

    // Enter az utolso mezoben kuld, elotte a kovetkezo mezore lep.
    function advance(index) {
        var next = fieldRepeater.itemAt(index + 1)
        if (next) next.focusInput()
        else submit()
    }

    visible: opened
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "quickshell.network-secrets"
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Connections {
        target: window.agent

        function onRequestIdChanged() {
            window.values = {}
            window.revealed = false
            if (window.agent.requestId !== 0) focusTimer.restart()
        }
    }

    Component.onCompleted: {
        if (screenProvider) screen = screenProvider()
        if (opened) focusTimer.restart()
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: window.focusFirst()
    }

    Rectangle {
        anchors.fill: parent
        color: window.panelBg
        opacity: 0.72
    }

    MouseArea {
        anchors.fill: parent
        enabled: window.opened
        onClicked: window.cancel()
    }

    Item {
        id: content

        anchors.centerIn: parent
        width: Math.min(440, window.width - 32)
        height: Math.min(body.implicitHeight + 32, window.height - 32)

        Keys.onEscapePressed: window.cancel()

        SharedUi.PopupFrame {
            anchors.fill: parent
            theme: window.theme
            attached: false
            edgeColor: window.agent && window.agent.error !== ""
                ? window.warningFg
                : Qt.rgba(1, 1, 1, 0.08)

            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => mouse.accepted = true
            }

            Column {
                id: body

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 12

                SharedUi.PopupHeader {
                    width: parent.width
                    theme: window.theme
                    title: window.titleText()
                }

                Text {
                    width: parent.width
                    text: window.messageText()
                    textFormat: Text.PlainText
                    color: window.panelFg
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                }

                Repeater {
                    id: fieldRepeater

                    model: window.fields

                    Column {
                        id: fieldBlock

                        required property var modelData
                        required property int index

                        function focusInput() {
                            input.forceInputFocus()
                        }

                        width: body.width
                        spacing: 4

                        Text {
                            text: fieldBlock.modelData.label
                            textFormat: Text.PlainText
                            color: window.mutedFg
                            font.pixelSize: 11
                            visible: window.fields.length > 1
                        }

                        Item {
                            width: parent.width
                            height: 40

                            SharedUi.SearchField {
                                id: input

                                anchors.fill: parent
                                indicator: ""
                                inputLeftMargin: 12
                                placeholder: fieldBlock.modelData.label
                                echoMode: window.revealed ? TextInput.Normal : TextInput.Password
                                foreground: window.panelFg
                                accent: window.panelAccent
                                muted: window.mutedFg
                                surface: window.inkBg
                                onTextEdited: (text) => window.setValue(fieldBlock.modelData.key, text)
                                onKeyPressed: (event) => {
                                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        window.advance(fieldBlock.index)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Escape) {
                                        window.cancel()
                                        event.accepted = true
                                    }
                                }

                                Connections {
                                    target: window.agent

                                    function onRequestIdChanged() {
                                        input.text = ""
                                    }
                                }
                            }

                            // A mezo jobb szelen; a talalati felulet 28 px magas.
                            Item {
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                width: revealText.implicitWidth + 16
                                height: 32
                                visible: fieldBlock.index === 0

                                Text {
                                    id: revealText

                                    anchors.centerIn: parent
                                    text: window.revealed ? "Hide" : "Show"
                                    textFormat: Text.PlainText
                                    color: revealMouse.containsMouse ? window.panelFg : window.mutedFg
                                    font.pixelSize: 11
                                }

                                MouseArea {
                                    id: revealMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: window.revealed = !window.revealed
                                }
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: window.agent && window.agent.error !== ""
                    text: window.agent ? window.agent.error : ""
                    textFormat: Text.PlainText
                    color: window.warningFg
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }

                Item {
                    width: parent.width
                    height: 32

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Esc cancel   ↵ connect"
                        textFormat: Text.PlainText
                        color: window.mutedFg
                        font.family: "monospace"
                        font.pixelSize: 9
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        SharedUi.ActionButton {
                            theme: window.theme
                            label: "Cancel"
                            onClicked: window.cancel()
                        }

                        SharedUi.ActionButton {
                            theme: window.theme
                            primary: true
                            enabled: window.complete && !(window.agent && window.agent.busy)
                            label: window.agent && window.agent.busy ? "Connecting…" : "Connect"
                            onClicked: window.submit()
                        }
                    }
                }
            }
        }
    }
}

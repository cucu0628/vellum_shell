import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland
import "../../ui" as SharedUi

PanelWindow {
    id: window

    property var theme: null
    property var screenProvider: null
    property string response: ""

    readonly property var flow: agent.flow
    readonly property bool opened: agent.isActive && flow !== null
    readonly property bool failed: flow !== null && flow.failed
    readonly property string panelBg: theme ? theme.background : "#11130f"
    readonly property string panelFg: theme ? theme.foreground : "#e8ddc7"
    readonly property string panelAccent: theme ? theme.accent : "#b7372f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string inkBg: theme && theme.surface ? theme.surface : "#191b16"
    readonly property string errorColor: "#d7472f"
    readonly property color lineBg: Qt.rgba(1, 1, 1, 0.055)
    readonly property color frameColor: failed ? errorColor : panelAccent

    function focusInput() {
        if (opened && flow && flow.isResponseRequired) responseInput.forceActiveFocus()
    }

    function submit() {
        if (!flow || !flow.isResponseRequired || response === "") return
        var value = response
        response = ""
        flow.submit(value)
    }

    function cancel() {
        if (flow) flow.cancelAuthenticationRequest()
        response = ""
    }

    visible: opened
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "quickshell.polkit-agent"
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: opened ? 1 : 0

    PolkitAgent {
        id: agent

        onAuthenticationRequestStarted: {
            window.response = ""
            if (window.screenProvider) window.screen = window.screenProvider()
            focusTimer.restart()
        }
    }

    Connections {
        target: window.flow
        enabled: window.flow !== null
        ignoreUnknownSignals: true

        function onAuthenticationFailed() {
            window.response = ""
            focusTimer.restart()
        }

        function onIsResponseRequiredChanged() {
            if (window.flow && window.flow.isResponseRequired) focusTimer.restart()
        }
    }

    onOpenedChanged: {
        if (opened) focusTimer.restart()
        else response = ""
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: window.focusInput()
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
        width: Math.min(560, window.width - 36)
        height: Math.min(body.implicitHeight + 32, window.height - 36)
        focus: window.opened

        Keys.onEscapePressed: window.cancel()

        SharedUi.PopupFrame {
            id: card
            anchors.fill: parent
            theme: window.theme
            border.color: window.frameColor

            Behavior on border.color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }

            MouseArea {
                anchors.fill: parent
                onClicked: mouse => mouse.accepted = true
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
                    title: "Authorization"
                    subtitle: window.failed ? "Authentication failed" : "Polkit agent"
                    trailingWidth: 92

                    Rectangle {
                        anchors.fill: parent
                        anchors.bottomMargin: 6
                        color: window.inkBg
                        border.color: window.frameColor
                        border.width: 1

                        Behavior on border.color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }

                        Text {
                            anchors.centerIn: parent
                            text: window.failed ? "DENIED" : "REQUIRED"
                            color: window.frameColor
                            font.family: "monospace"
                            font.pixelSize: 8
                            font.bold: true
                            font.letterSpacing: 1
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: window.flow ? window.flow.message : ""
                    color: window.panelFg
                    font.pixelSize: 14
                    wrapMode: Text.Wrap
                }

                Text {
                    width: parent.width
                    visible: window.flow && window.flow.actionId !== ""
                    text: window.flow ? window.flow.actionId : ""
                    color: window.mutedFg
                    font.family: "monospace"
                    font.pixelSize: 9
                    elide: Text.ElideMiddle
                }

                Column {
                    id: identityBlock
                    width: parent.width
                    visible: window.flow && window.flow.identities.length > 1
                    spacing: 6

                    Text {
                        text: "AUTHENTICATE AS"
                        color: window.panelAccent
                        font.pixelSize: 9
                        font.letterSpacing: 3
                        font.bold: true
                    }

                    Repeater {
                        model: window.flow ? window.flow.identities : []

                        Rectangle {
                            id: identityRow
                            required property var modelData
                            readonly property bool current: window.flow && window.flow.selectedIdentity === modelData

                            width: identityBlock.width
                            height: 40
                            radius: 0
                            color: identityRow.current || identityMouse.containsMouse ? window.inkBg : "transparent"
                            border.color: identityRow.current ? window.panelAccent : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 3
                                color: window.panelAccent
                                opacity: identityRow.current ? 1 : 0.35
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 13
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: identityRow.modelData.displayName
                                    color: identityRow.current ? window.panelAccent : window.panelFg
                                    font.pixelSize: 12
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: identityRow.modelData.string
                                    color: window.mutedFg
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: identityMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    window.response = ""
                                    window.flow.selectedIdentity = identityRow.modelData
                                    focusTimer.restart()
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 50
                    visible: window.flow && window.flow.isResponseRequired
                    radius: 0
                    color: window.inkBg
                    border.color: window.failed
                        ? window.errorColor
                        : (responseInput.activeFocus ? window.panelAccent : window.lineBg)
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 3
                        color: window.frameColor
                        Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰌾"
                        color: window.frameColor
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 15
                        Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    }

                    TextInput {
                        id: responseInput
                        anchors.left: parent.left
                        anchors.leftMargin: 52
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height - 10
                        verticalAlignment: TextInput.AlignVCenter
                        color: window.panelFg
                        font.pixelSize: 14
                        echoMode: window.flow && window.flow.responseVisible ? TextInput.Normal : TextInput.Password
                        inputMethodHints: window.flow && window.flow.responseVisible ? Qt.ImhNone : Qt.ImhSensitiveData
                        text: window.response
                        onTextChanged: window.response = text
                        onAccepted: window.submit()

                        Text {
                            anchors.fill: parent
                            visible: parent.text === ""
                            text: window.flow && window.flow.inputPrompt !== "" ? window.flow.inputPrompt.toUpperCase() : "PASSWORD"
                            color: window.mutedFg
                            opacity: 0.5
                            font.pixelSize: 10
                            font.letterSpacing: 4
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: window.flow && window.flow.supplementaryMessage !== ""
                    text: window.flow ? window.flow.supplementaryMessage : ""
                    color: window.flow && window.flow.supplementaryIsError ? window.errorColor : window.mutedFg
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                }

                Item {
                    width: parent.width
                    height: 30

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "ESC  cancel      ↵  submit"
                        color: window.mutedFg
                        opacity: 0.72
                        font.family: "monospace"
                        font.pixelSize: 9
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Rectangle {
                            width: 96
                            height: 30
                            radius: 0
                            color: cancelMouse.containsMouse ? window.inkBg : "transparent"
                            border.color: window.mutedFg
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "CANCEL"
                                color: window.mutedFg
                                font.family: "monospace"
                                font.pixelSize: 8
                                font.bold: true
                                font.letterSpacing: 1
                            }

                            MouseArea {
                                id: cancelMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.cancel()
                            }
                        }

                        Rectangle {
                            width: 126
                            height: 30
                            radius: 0
                            opacity: window.response !== "" ? 1 : 0.45
                            color: submitMouse.containsMouse && window.response !== ""
                                ? window.panelAccent
                                : window.inkBg
                            border.color: window.panelAccent
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent
                                text: "AUTHENTICATE"
                                color: submitMouse.containsMouse && window.response !== ""
                                    ? window.panelBg
                                    : window.panelAccent
                                font.family: "monospace"
                                font.pixelSize: 8
                                font.bold: true
                                font.letterSpacing: 1
                            }

                            MouseArea {
                                id: submitMouse
                                anchors.fill: parent
                                enabled: window.response !== ""
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.submit()
                            }
                        }
                    }
                }
            }
        }
    }
}

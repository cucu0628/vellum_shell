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
    readonly property string warningFg: theme && theme.warning ? theme.warning : "#c9693f"
    // A Wi-Fi jelszokero parja: alapbol halvany perem, hibanal figyelmezteto.
    readonly property color frameColor: failed ? warningFg : Qt.rgba(1, 1, 1, 0.08)
    // A polkit sajat kerdese ("Password: "), mondatszeruen, kettospont nelkul.
    readonly property string promptText: {
        var prompt = flow && flow.inputPrompt ? flow.inputPrompt.trim().replace(/:$/, "") : ""
        return prompt !== "" ? prompt : qsTr("Password")
    }

    function focusInput() {
        if (opened && flow && flow.isResponseRequired) responseInput.forceInputFocus()
    }

    function clearResponse() {
        response = ""
        responseInput.text = ""
    }

    function submit() {
        if (!flow || !flow.isResponseRequired || response === "") return
        var value = response
        clearResponse()
        flow.submit(value)
    }

    function cancel() {
        if (flow) flow.cancelAuthenticationRequest()
        clearResponse()
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
            window.clearResponse()
            if (window.screenProvider) window.screen = window.screenProvider()
            focusTimer.restart()
        }
    }

    Connections {
        target: window.flow
        enabled: window.flow !== null
        ignoreUnknownSignals: true

        function onAuthenticationFailed() {
            window.clearResponse()
            shakeAnimation.restart()
            focusTimer.restart()
        }

        function onIsResponseRequiredChanged() {
            if (window.flow && window.flow.isResponseRequired) focusTimer.restart()
        }
    }

    onOpenedChanged: {
        if (opened) focusTimer.restart()
        else clearResponse()
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
        width: Math.min(440, window.width - 32)
        height: Math.min(body.implicitHeight + 32, window.height - 32)
        focus: window.opened
        // Rossz jelszonal a lap megrazza magat, mint a zarolo kepernyo mezoje.
        transform: Translate { id: shake; x: 0 }

        Keys.onEscapePressed: window.cancel()

        SequentialAnimation {
            id: shakeAnimation

            NumberAnimation { target: shake; property: "x"; to: -8; duration: 50; easing.type: Easing.OutQuad }
            NumberAnimation { target: shake; property: "x"; to: 8; duration: 75; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shake; property: "x"; to: -5; duration: 65; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shake; property: "x"; to: 0; duration: 90; easing.type: Easing.OutCubic }
        }

        SharedUi.PopupFrame {
            anchors.fill: parent
            theme: window.theme
            attached: false
            edgeColor: window.frameColor

            Behavior on edgeColor { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }

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

                // Kulon "REQUIRED" jelveny nelkul: az alcim a kert polkit
                // muvelet azonositoja, hibanal pedig maga a hiba.
                SharedUi.PopupHeader {
                    width: parent.width
                    theme: window.theme
                    title: qsTr("Authorization")
                    subtitle: window.failed
                        ? qsTr("Wrong password, try again")
                        : (window.flow && window.flow.actionId !== "" ? window.flow.actionId : qsTr("Polkit agent"))
                }

                // Mit akar a rendszer -- a polkit sajat mondata, ez a lenyeg.
                Text {
                    width: parent.width
                    text: window.flow ? window.flow.message : ""
                    textFormat: Text.PlainText
                    color: window.panelFg
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                }

                // Tobb lehetseges fiok eseten (pl. tobb admin): ugyanaz a sor,
                // mint a lenyilo panelek eszkozlistai.
                Column {
                    id: identityBlock

                    width: parent.width
                    visible: window.flow && window.flow.identities.length > 1
                    spacing: 4

                    SharedUi.SectionBar {
                        width: parent.width
                        theme: window.theme
                        sentenceCase: true
                        title: qsTr("Authenticate as")
                    }

                    Repeater {
                        model: window.flow ? window.flow.identities : []

                        SharedUi.ListRow {
                            required property var modelData

                            width: identityBlock.width
                            implicitHeight: 48
                            theme: window.theme
                            glyph: "󰀄"
                            title: modelData.displayName
                            subtitle: modelData.string
                            active: window.flow && window.flow.selectedIdentity === modelData
                            onClicked: {
                                window.clearResponse()
                                window.flow.selectedIdentity = modelData
                                focusTimer.restart()
                            }
                        }
                    }
                }

                SharedUi.SearchField {
                    id: responseInput

                    width: parent.width
                    visible: window.flow && window.flow.isResponseRequired
                    opened: window.opened
                    indicator: "󰌾"
                    placeholder: window.promptText
                    echoMode: window.flow && window.flow.responseVisible ? TextInput.Normal : TextInput.Password
                    foreground: window.panelFg
                    accent: window.failed ? window.warningFg : window.panelAccent
                    muted: window.mutedFg
                    surface: window.inkBg
                    onTextEdited: (text) => window.response = text
                    onKeyPressed: (event) => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            window.submit()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            window.cancel()
                            event.accepted = true
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: window.flow && window.flow.supplementaryMessage !== ""
                    text: window.flow ? window.flow.supplementaryMessage : ""
                    textFormat: Text.PlainText
                    color: window.flow && window.flow.supplementaryIsError ? window.warningFg : window.mutedFg
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                }

                Item {
                    width: parent.width
                    height: 32

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Esc cancel   ↵ authenticate"
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
                            label: qsTr("Cancel")
                            onClicked: window.cancel()
                        }

                        SharedUi.ActionButton {
                            theme: window.theme
                            primary: true
                            enabled: window.response !== ""
                            label: qsTr("Authenticate")
                            onClicked: window.submit()
                        }
                    }
                }
            }
        }
    }
}

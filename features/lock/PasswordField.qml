import QtQuick

// Jelszomezo a shell mezoinek nyelven (ui/SearchField rokona): lekerekitett,
// egy hajszalnyi keret, ami fokuszban akcentes lesz, de nem vastagodik. A
// karakterek kerek pontok; hibanal a mezo megrazkodik es pirosra valt.
Rectangle {
    id: field

    required property var lockRoot
    property string placeholder: "Password"
    // A kitoltes: a hatterkepen kozvetlenul allo mezonek a temaszinbol.
    property color fill: Qt.rgba(0, 0, 0, 0.2)

    readonly property int charCount: lockRoot.password.length
    readonly property int dotCount: Math.min(charCount, 24)
    readonly property color accentColor: lockRoot.accent
    readonly property color mutedColor: lockRoot.muted
    readonly property color alertColor: lockRoot.alertColor
    readonly property color stateColor: lockRoot.failed
        ? alertColor
        : (input.activeFocus ? accentColor : mutedColor)

    function forceInputFocus() {
        input.forceActiveFocus()
    }

    implicitHeight: 44
    radius: 8
    color: fill
    border.width: 1
    border.color: lockRoot.failed
        ? Qt.rgba(alertColor.r, alertColor.g, alertColor.b, 0.7)
        : (input.activeFocus
            ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.55)
            : Qt.rgba(mutedColor.r, mutedColor.g, mutedColor.b, 0.22))
    transform: Translate { id: shake; x: 0 }

    Behavior on border.color { ColorAnimation { duration: 140 } }

    Connections {
        target: field.lockRoot

        function onFailedChanged() {
            if (field.lockRoot.failed) shakeAnimation.restart()
        }
    }

    SequentialAnimation {
        id: shakeAnimation

        NumberAnimation { target: shake; property: "x"; to: -8; duration: 50; easing.type: Easing.OutQuad }
        NumberAnimation { target: shake; property: "x"; to: 8; duration: 75; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shake; property: "x"; to: -5; duration: 65; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shake; property: "x"; to: 0; duration: 90; easing.type: Easing.OutCubic }
    }

    Text {
        id: glyph

        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: "󰌾"
        color: field.stateColor
        font.family: "Symbols Nerd Font Mono"
        font.pixelSize: 15

        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 40
        anchors.verticalCenter: parent.verticalCenter
        visible: field.charCount === 0 && !field.lockRoot.unlockInProgress
        text: field.placeholder
        color: field.lockRoot.muted
        font.pixelSize: 13
    }

    Row {
        id: dots

        anchors.left: parent.left
        anchors.leftMargin: 42
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Repeater {
            model: field.dotCount

            Rectangle {
                width: 7
                height: 7
                radius: 3.5
                color: field.lockRoot.failed ? field.alertColor : field.lockRoot.foreground
                anchors.verticalCenter: parent.verticalCenter

                NumberAnimation on scale { from: 0.2; to: 1; duration: 180; easing.type: Easing.OutBack }
            }
        }
    }

    Rectangle {
        width: 2
        height: 16
        radius: 1
        x: 42 + (field.dotCount > 0 ? dots.width + 6 : 0)
        anchors.verticalCenter: parent.verticalCenter
        color: field.accentColor
        visible: input.activeFocus && !field.lockRoot.unlockInProgress && field.charCount > 0

        Behavior on x { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

        SequentialAnimation on opacity {
            running: true
            loops: Animation.Infinite
            NumberAnimation { to: 0.15; duration: 560; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 560; easing.type: Easing.InOutSine }
        }
    }

    // Jobb szelen: Enter-jel, ha van mit bekuldeni; hitelesites alatt harom
    // lelegzo pont.
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        radius: 6
        visible: !field.lockRoot.unlockInProgress
        color: field.charCount > 0
            ? Qt.rgba(field.accentColor.r, field.accentColor.g, field.accentColor.b, 0.16)
            : "transparent"

        Behavior on color { ColorAnimation { duration: 140 } }

        Text {
            anchors.centerIn: parent
            text: "󰁔"
            color: field.charCount > 0 ? field.accentColor : field.mutedColor
            opacity: field.charCount > 0 ? 1 : 0.4
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 14
        }
    }

    Row {
        id: busy

        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5
        visible: field.lockRoot.unlockInProgress

        Repeater {
            model: 3

            Rectangle {
                required property int index

                width: 5
                height: 5
                radius: 2.5
                color: field.accentColor
                opacity: 0.25

                SequentialAnimation on opacity {
                    running: busy.visible
                    loops: Animation.Infinite
                    PauseAnimation { duration: index * 150 }
                    NumberAnimation { to: 1; duration: 220; easing.type: Easing.OutCubic }
                    NumberAnimation { to: 0.25; duration: 340; easing.type: Easing.InOutSine }
                    PauseAnimation { duration: (2 - index) * 150 }
                }
            }
        }
    }

    TextInput {
        id: input

        anchors.fill: parent
        opacity: 0
        focus: true
        echoMode: TextInput.Password
        inputMethodHints: Qt.ImhSensitiveData
        enabled: !field.lockRoot.unlockInProgress
        text: field.lockRoot.password
        onTextChanged: field.lockRoot.password = text
        onAccepted: field.lockRoot.tryUnlock()
    }
}

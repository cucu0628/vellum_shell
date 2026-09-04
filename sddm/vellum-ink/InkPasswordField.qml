import QtQuick

// Jelszomezo a shell mezoinek nyelven: eles sarkok, egy hajszalnyi keret, ami
// fokuszban akcentesre valt, balra tomor akcentcsik. A karakterek negyzet
// pontokkent jelennek meg. A zarolokepernyo `PasswordField`-jenek parja.
Rectangle {
    id: passwordBox

    required property var greeter

    readonly property int charCount: greeter.password.length
    readonly property int dotCount: Math.min(charCount, 24)
    readonly property color edgeColor: greeter.failed
        ? greeter.alertColor
        : (passwordInput.activeFocus ? greeter.accent : greeter.outline)

    function forceInputFocus() {
        passwordInput.forceActiveFocus()
    }

    height: 48
    radius: 0
    color: Qt.rgba(0, 0, 0, 0.22)
    border.color: edgeColor
    border.width: greeter.failed || passwordInput.activeFocus ? 2 : 1
    transform: Translate { id: failedShake; x: 0 }

    onCharCountChanged: keyPulse.restart()

    Behavior on border.color { ColorAnimation { duration: 140 } }
    Behavior on border.width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Connections {
        target: passwordBox.greeter

        function onFailedChanged() {
            if (passwordBox.greeter.failed) shakeAnimation.restart()
        }
    }

    SequentialAnimation {
        id: shakeAnimation

        NumberAnimation { target: failedShake; property: "x"; to: -9; duration: 50; easing.type: Easing.OutQuad }
        NumberAnimation { target: failedShake; property: "x"; to: 9; duration: 75; easing.type: Easing.InOutQuad }
        NumberAnimation { target: failedShake; property: "x"; to: -6; duration: 65; easing.type: Easing.InOutQuad }
        NumberAnimation { target: failedShake; property: "x"; to: 4; duration: 60; easing.type: Easing.InOutQuad }
        NumberAnimation { target: failedShake; property: "x"; to: 0; duration: 90; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: pulseOverlay

        anchors.fill: parent
        anchors.margins: 1
        color: passwordBox.greeter.accent
        opacity: 0
    }

    NumberAnimation {
        id: keyPulse

        target: pulseOverlay
        property: "opacity"
        from: 0.08
        to: 0
        duration: 280
        easing.type: Easing.OutCubic
    }

    Rectangle {
        width: 2
        height: parent.height
        anchors.left: parent.left
        color: passwordBox.edgeColor

        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Text {
        text: "󰌾"
        color: passwordBox.edgeColor
        font.family: "Symbols Nerd Font Mono"
        font.pixelSize: 15
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter

        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Row {
        id: dots

        anchors.left: parent.left
        anchors.leftMargin: 46
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7

        Repeater {
            model: passwordBox.dotCount

            Rectangle {
                width: 6
                height: 6
                color: passwordBox.edgeColor
                anchors.verticalCenter: parent.verticalCenter

                NumberAnimation on scale {
                    from: 0.3
                    to: 1
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    Rectangle {
        width: 2
        height: 18
        x: 46 + (passwordBox.dotCount > 0 ? dots.width + 6 : 0)
        anchors.verticalCenter: parent.verticalCenter
        color: passwordBox.edgeColor
        visible: !passwordBox.greeter.busy && passwordInput.activeFocus

        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        SequentialAnimation on opacity {
            running: true
            loops: Animation.Infinite
            NumberAnimation { to: 0.1; duration: 620; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 620; easing.type: Easing.InOutSine }
        }
    }

    Text {
        // Jelszo nelkuli fioknal nincs mit begepelni, ezt mondjuk is.
        text: passwordBox.greeter.userNeedsPassword ? "PASSWORD" : "NO PASSWORD NEEDED"
        visible: passwordBox.charCount === 0 && !passwordBox.greeter.busy
        color: passwordBox.greeter.muted
        opacity: 0.5
        font.pixelSize: 9
        font.letterSpacing: 4
        x: 60
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        text: "󰌑"
        visible: !passwordBox.greeter.busy
        color: passwordBox.greeter.muted
        opacity: passwordBox.charCount > 0 || !passwordBox.greeter.userNeedsPassword ? 0.8 : 0.3
        font.family: "Symbols Nerd Font Mono"
        font.pixelSize: 13
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter

        Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    Row {
        id: busyMarks

        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5
        visible: passwordBox.greeter.busy

        Repeater {
            model: 3

            Rectangle {
                required property int index

                width: 4
                height: 4
                color: passwordBox.greeter.accent

                SequentialAnimation on opacity {
                    running: busyMarks.visible
                    loops: Animation.Infinite
                    PauseAnimation { duration: index * 160 }
                    NumberAnimation { to: 1; duration: 220; easing.type: Easing.OutCubic }
                    NumberAnimation { to: 0.2; duration: 340; easing.type: Easing.InOutSine }
                    PauseAnimation { duration: (2 - index) * 160 }
                }
            }
        }
    }

    TextInput {
        id: passwordInput

        anchors.fill: parent
        opacity: 0
        echoMode: TextInput.Password
        inputMethodHints: Qt.ImhSensitiveData
        enabled: !passwordBox.greeter.busy
        focus: true
        text: passwordBox.greeter.password
        onTextChanged: passwordBox.greeter.password = text
        onAccepted: passwordBox.greeter.tryLogin()
    }
}

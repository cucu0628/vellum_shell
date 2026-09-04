import QtQuick
import "." as Ink

// Masodlagos kijelzok: ugyanaz az ora es ugyanaz a jegy, kartya nelkul.
// A greeter minden kepernyore kulon ablakot nyit, es a billentyuzet fokusz nem
// feltetlenul a kartyat mutato ablake -- ezert itt is fogadjuk a gepelest.
Item {
    id: ambient

    required property var greeter

    readonly property bool clockShown: greeter.revealStep >= 2 && !greeter.closing
    readonly property bool bodyShown: greeter.revealStep >= 3 && !greeter.closing
    readonly property int blockWidth: Math.round(Math.min(ambient.width * 0.5, 460))
    readonly property string stateText: greeter.failed
        ? "ACCESS DENIED"
        : (greeter.busy ? "AUTHENTICATING" : "AWAITING SIGN IN")

    focus: true

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Math.round(ambient.height * 0.03)
        width: ambient.blockWidth
        spacing: 44

        Ink.InkClock {
            anchors.horizontalCenter: parent.horizontalCenter
            greeter: ambient.greeter
            centered: true
            timeSize: Math.round(Math.max(88, Math.min(146, ambient.height * 0.14)))
            barWidth: ambient.blockWidth
            opacity: ambient.clockShown ? 1 : 0

            transform: Translate {
                y: ambient.clockShown ? 0 : 14
                Behavior on y {
                    NumberAnimation { duration: ambient.greeter.closing ? 160 : 520; easing.type: Easing.OutCubic }
                }
            }

            Behavior on opacity {
                NumberAnimation { duration: ambient.greeter.closing ? 130 : 460; easing.type: Easing.OutCubic }
            }
        }

        Column {
            width: parent.width
            spacing: 14
            opacity: ambient.bodyShown ? 1 : 0

            transform: Translate {
                y: ambient.bodyShown ? 0 : 12
                Behavior on y {
                    NumberAnimation { duration: ambient.greeter.closing ? 160 : 520; easing.type: Easing.OutCubic }
                }
            }

            Behavior on opacity {
                NumberAnimation { duration: ambient.greeter.closing ? 130 : 460; easing.type: Easing.OutCubic }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Ink.InkLogo {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 24
                    color: ambient.greeter.failed ? ambient.greeter.alertColor : ambient.greeter.accent
                    opacity: ambient.greeter.busy ? 0.5 : 1

                    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutSine } }

                    SequentialAnimation on rotation {
                        running: ambient.greeter.busy
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                        NumberAnimation { from: 0; to: 360; duration: 2600; easing.type: Easing.InOutSine }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ambient.stateText
                    color: ambient.greeter.failed ? ambient.greeter.alertColor : ambient.greeter.foreground
                    font.pixelSize: 12
                    font.letterSpacing: 4
                    font.weight: Font.DemiBold

                    Behavior on color { ColorAnimation { duration: 160 } }
                }
            }

            // A begepelt karakterek a tobbi kijelzon is latszanak.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                height: 8
                spacing: 7
                visible: ambient.greeter.password.length > 0

                Repeater {
                    model: Math.min(ambient.greeter.password.length, 24)

                    Rectangle {
                        width: 6
                        height: 6
                        color: ambient.greeter.failed ? ambient.greeter.alertColor : ambient.greeter.accent
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

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    var parts = [ambient.greeter.userLabel]
                    if (ambient.greeter.sessionLabel !== "") parts.push(ambient.greeter.sessionLabel)
                    return parts.join(" · ").toUpperCase()
                }
                color: ambient.greeter.muted
                font.pixelSize: 9
                font.letterSpacing: 1.6
                opacity: 0.7
            }
        }
    }

    TextInput {
        id: ambientPasswordInput

        width: 1
        height: 1
        opacity: 0
        focus: true
        enabled: !ambient.greeter.busy
        echoMode: TextInput.Password
        inputMethodHints: Qt.ImhSensitiveData
        text: ambient.greeter.password
        onTextChanged: ambient.greeter.password = text
        onAccepted: ambient.greeter.tryLogin()

        Keys.onEscapePressed: ambient.greeter.clearPassword()
    }

    Component.onCompleted: Qt.callLater(ambientPasswordInput.forceActiveFocus)
}

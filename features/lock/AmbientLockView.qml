import QtQuick
import "." as LockUi
import "../../ui" as SharedUi

// A tobbi monitor nezete: ugyanaz az ora es ugyanaz a jegy, panel nelkul. A
// gepeles itt is elszall a jelszohoz, es a beirt karaktereket visszajelezzuk,
// hogy latszodjon, melyik kepernyore erkezik a bevitel.
Item {
    id: ambientView

    required property var lockRoot
    property string screenName: ""

    readonly property bool clockShown: lockRoot.revealStep >= 2 && !lockRoot.closing
    readonly property bool bodyShown: lockRoot.revealStep >= 3 && !lockRoot.closing
    readonly property int blockWidth: Math.round(Math.min(ambientView.width * 0.5, 460))
    readonly property string stateText: lockRoot.failed
        ? "ACCESS DENIED"
        : (lockRoot.unlockInProgress ? "AUTHENTICATING" : "SESSION LOCKED")

    focus: true

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Math.round(ambientView.height * 0.03)
        width: ambientView.blockWidth
        spacing: 44

        LockUi.LockClock {
            anchors.horizontalCenter: parent.horizontalCenter
            lockRoot: ambientView.lockRoot
            centered: true
            timeSize: Math.round(Math.max(88, Math.min(146, ambientView.height * 0.14)))
            barWidth: ambientView.blockWidth
            opacity: ambientView.clockShown ? 1 : 0

            transform: Translate {
                y: ambientView.clockShown ? 0 : 14
                Behavior on y {
                    NumberAnimation { duration: ambientView.lockRoot.closing ? 160 : 520; easing.type: Easing.OutCubic }
                }
            }

            Behavior on opacity {
                NumberAnimation { duration: ambientView.lockRoot.closing ? 130 : 460; easing.type: Easing.OutCubic }
            }
        }

        Column {
            width: parent.width
            spacing: 14
            opacity: ambientView.bodyShown ? 1 : 0

            transform: Translate {
                y: ambientView.bodyShown ? 0 : 12
                Behavior on y {
                    NumberAnimation { duration: ambientView.lockRoot.closing ? 160 : 520; easing.type: Easing.OutCubic }
                }
            }

            Behavior on opacity {
                NumberAnimation { duration: ambientView.lockRoot.closing ? 130 : 460; easing.type: Easing.OutCubic }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                SharedUi.ShellLogo {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 24
                    color: ambientView.lockRoot.failed
                        ? ambientView.lockRoot.alertColor
                        : ambientView.lockRoot.accent
                    opacity: ambientView.lockRoot.unlockInProgress ? 0.5 : 1

                    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutSine } }

                    SequentialAnimation on rotation {
                        running: ambientView.lockRoot.unlockInProgress
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                        NumberAnimation { from: 0; to: 360; duration: 2600; easing.type: Easing.InOutSine }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ambientView.stateText
                    color: ambientView.lockRoot.failed
                        ? ambientView.lockRoot.alertColor
                        : ambientView.lockRoot.foreground
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
                visible: ambientView.lockRoot.password.length > 0

                Repeater {
                    model: Math.min(ambientView.lockRoot.password.length, 24)

                    Rectangle {
                        width: 6
                        height: 6
                        color: ambientView.lockRoot.failed
                            ? ambientView.lockRoot.alertColor
                            : ambientView.lockRoot.accent
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
                text: "UNLOCK ON " + ambientView.lockRoot.effectiveInputMonitorName.toUpperCase()
                color: ambientView.lockRoot.muted
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
        enabled: !ambientView.lockRoot.unlockInProgress
        echoMode: TextInput.Password
        inputMethodHints: Qt.ImhSensitiveData
        text: ambientView.lockRoot.password
        onTextChanged: ambientView.lockRoot.password = text
        onAccepted: ambientView.lockRoot.tryUnlock()

        Keys.onEscapePressed: ambientView.lockRoot.clearPassword()
    }

    Component.onCompleted: Qt.callLater(ambientPasswordInput.forceActiveFocus)
}

import QtQuick
import "." as LockUi
import "../../ui" as SharedUi

// A tobbi monitor nezete: ugyanaz az ora ugyanott, mezo nelkul. A gepeles itt
// is elszall a jelszohoz, es a beirt karaktereket visszajelezzuk, hogy
// latszodjon, melyik kepernyore erkezik a bevitel.
Item {
    id: ambientView

    required property var lockRoot
    property string screenName: ""
    // A greeter ugyanezt a nezetet hasznalja, a sajat szovegeivel.
    property string idleText: "Session locked"
    property string inputHint: "Unlock on " + lockRoot.effectiveInputMonitorName

    readonly property bool clockShown: lockRoot.revealStep >= 2 && !lockRoot.closing
    readonly property bool bodyShown: lockRoot.revealStep >= 3 && !lockRoot.closing
    readonly property int sideMargin: Math.round(Math.max(48, Math.min(96, ambientView.width * 0.06)))
    readonly property color stateColor: lockRoot.failed ? lockRoot.alertColor : lockRoot.foreground
    readonly property string stateText: lockRoot.failed || lockRoot.unlockInProgress || lockRoot.closing
        ? lockRoot.statusText
        : ambientView.idleText

    focus: true

    SharedUi.ShellLogo {
        x: ambientView.sideMargin
        y: Math.round(ambientView.sideMargin * 0.75)
        size: 22
        color: ambientView.lockRoot.accent
        opacity: ambientView.clockShown ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: ambientView.lockRoot.closing ? 130 : 460; easing.type: Easing.OutCubic }
        }
    }

    Column {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: ambientView.sideMargin
        anchors.bottomMargin: Math.round(ambientView.sideMargin * 1.1)
        spacing: 32

        LockUi.LockReveal {
            lockRoot: ambientView.lockRoot
            shown: ambientView.clockShown
            width: clock.implicitWidth
            height: clock.implicitHeight

            LockUi.LockClock {
                id: clock

                lockRoot: ambientView.lockRoot
                timeSize: Math.round(Math.max(120, Math.min(200, ambientView.height * 0.2)))
            }
        }

        LockUi.LockReveal {
            lockRoot: ambientView.lockRoot
            shown: ambientView.bodyShown
            offset: 10
            width: Math.min(360, ambientView.width - ambientView.sideMargin * 2)
            height: stateColumn.implicitHeight

            Column {
                id: stateColumn

                width: parent.width
                spacing: 8

                Row {
                    spacing: 12
                    height: 20

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ambientView.stateText
                        color: ambientView.stateColor
                        font.pixelSize: 13
                        font.weight: Font.DemiBold

                        Behavior on color { ColorAnimation { duration: 160 } }
                    }

                    // A begepelt karakterek a tobbi kijelzon is latszanak.
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Repeater {
                            model: Math.min(ambientView.lockRoot.password.length, 24)

                            Rectangle {
                                width: 7
                                height: 7
                                radius: 3.5
                                color: ambientView.lockRoot.accent
                                anchors.verticalCenter: parent.verticalCenter

                                NumberAnimation on scale { from: 0.2; to: 1; duration: 180; easing.type: Easing.OutBack }
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: ambientView.inputHint
                    color: ambientView.lockRoot.muted
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
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

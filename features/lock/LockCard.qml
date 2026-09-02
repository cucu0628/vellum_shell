import QtQuick
import "." as LockUi
import "../../ui" as SharedUi

// A beviteli monitor nezete: nagy ora a lap felett, alatta a shell panel-
// nyelven megirt kartya (eles sarkok, akcentcsik felul, ensō vizjel).
FocusScope {
    id: focusScope

    required property var lockRoot
    property string screenName: ""

    readonly property bool clockShown: lockRoot.revealStep >= 2 && !lockRoot.closing
    readonly property bool cardShown: lockRoot.revealStep >= 3 && !lockRoot.closing
    readonly property bool bodyShown: lockRoot.revealStep >= 4 && !lockRoot.closing
    readonly property int cardWidth: Math.round(Math.max(340, Math.min(focusScope.width - 96, 440)))
    readonly property color surfaceColor: lockRoot.surface

    focus: true

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            focusScope.lockRoot.clearPassword()
            event.accepted = true
        }
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Math.round(focusScope.height * 0.03)
        width: focusScope.cardWidth
        spacing: 52

        LockUi.LockClock {
            anchors.horizontalCenter: parent.horizontalCenter
            lockRoot: focusScope.lockRoot
            centered: true
            timeSize: Math.round(Math.max(76, Math.min(118, focusScope.height * 0.11)))
            barWidth: focusScope.cardWidth
            opacity: focusScope.clockShown ? 1 : 0

            transform: Translate {
                y: focusScope.clockShown ? 0 : 14
                Behavior on y {
                    NumberAnimation { duration: focusScope.lockRoot.closing ? 160 : 520; easing.type: Easing.OutCubic }
                }
            }

            Behavior on opacity {
                NumberAnimation { duration: focusScope.lockRoot.closing ? 130 : 460; easing.type: Easing.OutCubic }
            }
        }

        Rectangle {
            id: card

            width: parent.width
            height: cardBody.height + 44
            radius: 0
            clip: true
            color: Qt.rgba(focusScope.surfaceColor.r, focusScope.surfaceColor.g, focusScope.surfaceColor.b, 0.93)
            border.color: focusScope.lockRoot.failed
                ? focusScope.lockRoot.alertColor
                : Qt.rgba(1, 1, 1, 0.12)
            border.width: 1
            opacity: focusScope.cardShown ? 1 : 0

            transform: Translate {
                y: focusScope.cardShown ? 0 : 16
                Behavior on y {
                    NumberAnimation { duration: focusScope.lockRoot.closing ? 160 : 520; easing.type: Easing.OutCubic }
                }
            }

            Behavior on opacity {
                NumberAnimation { duration: focusScope.lockRoot.closing ? 130 : 460; easing.type: Easing.OutCubic }
            }

            Behavior on border.color { ColorAnimation { duration: 160 } }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 1
                height: 2
                color: focusScope.lockRoot.failed
                    ? focusScope.lockRoot.alertColor
                    : focusScope.lockRoot.accent

                Behavior on color { ColorAnimation { duration: 160 } }
            }

            SharedUi.ShellLogo {
                anchors.right: parent.right
                anchors.rightMargin: -26
                anchors.top: parent.top
                anchors.topMargin: -42
                size: 150
                color: focusScope.lockRoot.foreground
                opacity: 0.022
            }

            Column {
                id: cardBody

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                anchors.topMargin: 24
                spacing: 16

                Row {
                    width: parent.width
                    spacing: 12

                    SharedUi.ShellLogo {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 28
                        color: focusScope.lockRoot.accent
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 40
                        spacing: 2

                        Text {
                            width: parent.width
                            text: focusScope.lockRoot.userName
                            color: focusScope.lockRoot.foreground
                            font.family: "serif"
                            font.pixelSize: 18
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: (focusScope.screenName !== "" ? focusScope.screenName + " · " : "")
                                + focusScope.lockRoot.powerText.toUpperCase()
                            color: focusScope.lockRoot.muted
                            font.pixelSize: 8
                            font.letterSpacing: 1.3
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: focusScope.lockRoot.muted
                    opacity: 0.2
                }

                Item {
                    width: parent.width
                    height: inputColumn.height
                    opacity: focusScope.bodyShown ? 1 : 0

                    transform: Translate {
                        y: focusScope.bodyShown ? 0 : 8
                        Behavior on y {
                            NumberAnimation { duration: focusScope.lockRoot.closing ? 130 : 460; easing.type: Easing.OutCubic }
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: focusScope.lockRoot.closing ? 110 : 420; easing.type: Easing.OutCubic }
                    }

                    Column {
                        id: inputColumn

                        width: parent.width
                        spacing: 12

                        LockUi.PasswordField {
                            id: passwordField

                            width: parent.width
                            lockRoot: focusScope.lockRoot
                        }

                        Item {
                            width: parent.width
                            height: statusText.implicitHeight

                            Text {
                                id: statusText

                                anchors.left: parent.left
                                anchors.right: hintText.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: focusScope.lockRoot.statusText.toUpperCase()
                                color: focusScope.lockRoot.failed
                                    ? focusScope.lockRoot.alertColor
                                    : focusScope.lockRoot.muted
                                font.pixelSize: 9
                                font.letterSpacing: 1.6
                                elide: Text.ElideRight

                                Behavior on color { ColorAnimation { duration: 140 } }
                            }

                            Text {
                                id: hintText

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "ESC CLEARS"
                                color: focusScope.lockRoot.muted
                                opacity: focusScope.lockRoot.password.length > 0 ? 0.6 : 0
                                font.pixelSize: 9
                                font.letterSpacing: 1.6

                                Behavior on opacity { NumberAnimation { duration: 160 } }
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: Qt.callLater(passwordField.forceInputFocus)
}

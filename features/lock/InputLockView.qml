import QtQuick
import "." as LockUi
import "../../ui" as SharedUi

// A beviteli monitor nezete. Nyomdai kompozicio a bal also sarokban: ora,
// alatta a felhasznalo es a jelszomezo. A kep tobbi resze szabad; a bal oldali
// temaszinu atmenetet a LockBackground adja.
FocusScope {
    id: view

    required property var lockRoot
    property string screenName: ""

    readonly property bool clockShown: lockRoot.revealStep >= 2 && !lockRoot.closing
    readonly property bool bodyShown: lockRoot.revealStep >= 3 && !lockRoot.closing
    readonly property int sideMargin: Math.round(Math.max(48, Math.min(96, view.width * 0.06)))
    readonly property color paper: lockRoot.background

    focus: true

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            view.lockRoot.clearPassword()
            event.accepted = true
        }
    }

    SharedUi.ShellLogo {
        x: view.sideMargin
        y: Math.round(view.sideMargin * 0.75)
        size: 22
        color: view.lockRoot.accent
        opacity: view.clockShown ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: view.lockRoot.closing ? 130 : 460; easing.type: Easing.OutCubic }
        }
    }

    Column {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: view.sideMargin
        anchors.bottomMargin: Math.round(view.sideMargin * 1.1)
        spacing: 32

        LockUi.LockReveal {
            lockRoot: view.lockRoot
            shown: view.clockShown
            width: clock.implicitWidth
            height: clock.implicitHeight

            LockUi.LockClock {
                id: clock

                lockRoot: view.lockRoot
                timeSize: Math.round(Math.max(120, Math.min(200, view.height * 0.2)))
            }
        }

        LockUi.LockReveal {
            lockRoot: view.lockRoot
            shown: view.bodyShown
            offset: 10
            width: Math.min(360, view.width - view.sideMargin * 2)
            height: loginColumn.implicitHeight

            Column {
                id: loginColumn

                width: parent.width
                spacing: 12

                Text {
                    width: parent.width
                    text: view.lockRoot.userName
                    color: view.lockRoot.foreground
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: parent.contentWidth + 8
                        anchors.right: parent.right
                        anchors.baseline: parent.baseline
                        text: "·  " + view.lockRoot.powerText
                        color: view.lockRoot.muted
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                LockUi.PasswordField {
                    id: passwordField

                    width: parent.width
                    lockRoot: view.lockRoot
                    fill: Qt.rgba(view.paper.r, view.paper.g, view.paper.b, 0.6)
                }

                LockUi.LockStatusLine {
                    width: parent.width
                    lockRoot: view.lockRoot
                }
            }
        }
    }

    Component.onCompleted: Qt.callLater(passwordField.forceInputFocus)
}

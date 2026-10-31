import QtQuick
import "." as LockUi
import "../../ui" as SharedUi

// A greeter beviteli monitora. Ugyanaz a nyomdai kompozicio, mint a zarolo
// InputLockView-ban: ora es jelszomezo a bal also sarokban. A greeter tobblete
// ugyanabban az oszlopban ul -- felhasznalo a cimben, munkamenet es kiosztas a
// mezo alatt --, a rendszermuveletek pedig a jobb also sarokban.
FocusScope {
    id: view

    required property var lockRoot
    property string screenName: ""

    // Egyszerre csak egy lista lehet nyitva: "" | "user" | "session"
    property string openChoice: ""

    readonly property bool clockShown: lockRoot.revealStep >= 2 && !lockRoot.closing
    readonly property bool bodyShown: lockRoot.revealStep >= 3 && !lockRoot.closing
    readonly property int sideMargin: Math.round(Math.max(48, Math.min(96, view.width * 0.06)))
    readonly property int bottomMargin: Math.round(view.sideMargin * 1.1)
    readonly property color paper: lockRoot.background

    function toggleChoice(name) {
        view.openChoice = view.openChoice === name ? "" : name
        if (view.openChoice === "") passwordField.forceInputFocus()
    }

    function closeChoice() {
        view.openChoice = ""
        passwordField.forceInputFocus()
    }

    focus: true

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            if (view.openChoice !== "") view.closeChoice()
            else view.lockRoot.clearPassword()
            event.accepted = true
        }
    }

    // Kattintas a lap barmely ures pontjara bezarja a nyitott listat.
    MouseArea {
        anchors.fill: parent
        enabled: view.openChoice !== ""
        onClicked: view.closeChoice()
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
        anchors.bottomMargin: view.bottomMargin
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

                LockUi.GreeterChoice {
                    width: parent.width
                    lockRoot: view.lockRoot
                    title: true
                    label: view.lockRoot.userLabel !== "" ? view.lockRoot.userLabel : "No user account"
                    detail: view.lockRoot.hostName
                    accessibleName: "User"
                    entries: view.lockRoot.users
                    currentIndex: view.lockRoot.userIndex
                    open: view.openChoice === "user"
                    onToggled: view.toggleChoice("user")
                    onDismissed: view.closeChoice()
                    onPicked: (index) => {
                        view.lockRoot.selectUser(index)
                        view.closeChoice()
                    }
                }

                LockUi.PasswordField {
                    id: passwordField

                    width: parent.width
                    lockRoot: view.lockRoot
                    placeholder: view.lockRoot.prompt !== "" ? view.lockRoot.prompt : "Password"
                    fill: Qt.rgba(view.paper.r, view.paper.g, view.paper.b, 0.6)
                }

                LockUi.LockStatusLine {
                    width: parent.width
                    lockRoot: view.lockRoot
                }

                Row {
                    spacing: 8

                    LockUi.GreeterChoice {
                        lockRoot: view.lockRoot
                        glyph: "󰍹"
                        label: view.lockRoot.sessionLabel !== "" ? view.lockRoot.sessionLabel : "No session"
                        accessibleName: "Session"
                        entries: view.lockRoot.sessions
                        currentIndex: view.lockRoot.sessionIndex
                        open: view.openChoice === "session"
                        onToggled: view.toggleChoice("session")
                        onDismissed: view.closeChoice()
                        onPicked: (index) => {
                            view.lockRoot.selectSession(index)
                            view.closeChoice()
                        }
                    }

                    LockUi.GreeterActionButton {
                        lockRoot: view.lockRoot
                        visible: view.lockRoot.keyboardLayouts.length > 1
                        height: 28
                        glyph: "󰌌"
                        label: view.lockRoot.keyboardLabel
                        accessibleName: "Keyboard layout"
                        onActivated: {
                            view.lockRoot.nextKeyboardLayout()
                            passwordField.forceInputFocus()
                        }
                    }
                }
            }
        }
    }

    // Rendszermuveletek: a bejelentkezes oszlopan kivul, mert nem annak reszei.
    LockUi.LockReveal {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: view.sideMargin
        anchors.bottomMargin: view.bottomMargin - 2
        lockRoot: view.lockRoot
        shown: view.bodyShown
        offset: 10
        width: actions.implicitWidth
        height: actions.implicitHeight

        Row {
            id: actions

            spacing: 4

            LockUi.GreeterActionButton {
                lockRoot: view.lockRoot
                glyph: "󰤄"
                accessibleName: "Sleep"
                enabled: view.lockRoot.powerActionsEnabled
                onActivated: view.lockRoot.power("suspend")
            }

            LockUi.GreeterActionButton {
                lockRoot: view.lockRoot
                glyph: "󰜉"
                accessibleName: "Restart"
                enabled: view.lockRoot.powerActionsEnabled
                onActivated: view.lockRoot.power("reboot")
            }

            LockUi.GreeterActionButton {
                lockRoot: view.lockRoot
                glyph: "󰐥"
                accessibleName: "Shut down"
                danger: true
                enabled: view.lockRoot.powerActionsEnabled
                onActivated: view.lockRoot.power("poweroff")
            }
        }
    }

    Component.onCompleted: Qt.callLater(passwordField.forceInputFocus)
}

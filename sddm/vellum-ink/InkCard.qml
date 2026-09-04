import QtQuick
import "." as Ink

// A bejelentkezo kepernyo: nagy ora a lap felett, alatta a shell panel-
// nyelven megirt kartya (eles sarkok, akcentcsik felul, ensō vizjel), majd a
// greeterre jellemzo rendszermuveletek. A zarolokepernyo `LockCard`-janak
// parja -- ott csak a jelszo kell, itt a felhasznalo, a munkamenet, a
// billentyuzetkiosztas es az energia is.
FocusScope {
    id: card

    required property var greeter

    readonly property bool clockShown: greeter.revealStep >= 2 && !greeter.closing
    readonly property bool cardShown: greeter.revealStep >= 3 && !greeter.closing
    readonly property bool bodyShown: greeter.revealStep >= 4 && !greeter.closing
    readonly property int cardWidth: Math.round(Math.max(400, Math.min(card.width - 96, 520)))
    readonly property color surfaceColor: greeter.surface

    readonly property bool hasKeyboard: (typeof keyboard !== "undefined") && keyboard.enabled && keyboard.layouts.length > 0
    readonly property string layoutText: hasKeyboard ? keyboard.layouts[keyboard.currentLayout].shortName.toUpperCase() : ""

    // Az eppen nyitott lista tipusa -- zaraskor is megmarad, hogy a
    // kihalvanyodo legordulo tartalma ne valtson at menet kozben.
    property string activePicker: ""

    focus: true

    function positionDropdown() {
        var source = card.activePicker === "user"
            ? userPicker
            : (card.activePicker === "session" ? sessionPicker : null)
        if (!source) return

        // A lista a valasztoval azonos szeles: igy a ketto egy elemnek latszik.
        dropdown.width = source.width
        var point = source.mapToItem(card, 0, source.height)
        dropdown.x = Math.max(12, Math.min(card.width - dropdown.width - 12, point.x))
        dropdown.y = point.y + 6
    }

    Connections {
        target: card.greeter

        function onOpenPickerChanged() {
            if (card.greeter.openPicker !== "") {
                card.activePicker = card.greeter.openPicker
                card.positionDropdown()
            }
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            if (card.greeter.openPicker !== "") card.greeter.openPicker = ""
            else card.greeter.clearPassword()
            event.accepted = true
        }
    }

    // Kattintas a felulet barmely mas pontjara bezarja a nyitott listat.
    MouseArea {
        anchors.fill: parent
        z: 40
        enabled: card.greeter.openPicker !== ""
        onClicked: card.greeter.openPicker = ""
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Math.round(card.height * 0.02)
        width: card.cardWidth
        spacing: 44

        Ink.InkClock {
            anchors.horizontalCenter: parent.horizontalCenter
            greeter: card.greeter
            centered: true
            timeSize: Math.round(Math.max(74, Math.min(112, card.height * 0.1)))
            barWidth: card.cardWidth
            opacity: card.clockShown ? 1 : 0

            transform: Translate {
                y: card.clockShown ? 0 : 14
                Behavior on y {
                    NumberAnimation { duration: card.greeter.closing ? 160 : 520; easing.type: Easing.OutCubic }
                }
            }

            Behavior on opacity {
                NumberAnimation { duration: card.greeter.closing ? 130 : 460; easing.type: Easing.OutCubic }
            }
        }

        Rectangle {
            id: panel

            width: parent.width
            height: panelBody.height + 44
            radius: 0
            clip: true
            color: Qt.rgba(card.surfaceColor.r, card.surfaceColor.g, card.surfaceColor.b, 0.93)
            border.color: card.greeter.failed ? card.greeter.alertColor : Qt.rgba(1, 1, 1, 0.12)
            border.width: 1
            opacity: card.cardShown ? 1 : 0

            transform: Translate {
                y: card.cardShown ? 0 : 16
                Behavior on y {
                    NumberAnimation { duration: card.greeter.closing ? 160 : 520; easing.type: Easing.OutCubic }
                }
            }

            Behavior on opacity {
                NumberAnimation { duration: card.greeter.closing ? 130 : 460; easing.type: Easing.OutCubic }
            }

            Behavior on border.color { ColorAnimation { duration: 160 } }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 1
                height: 2
                color: card.greeter.failed ? card.greeter.alertColor : card.greeter.accent

                Behavior on color { ColorAnimation { duration: 160 } }
            }

            Ink.InkLogo {
                anchors.right: parent.right
                anchors.rightMargin: -26
                anchors.top: parent.top
                anchors.topMargin: -42
                size: 150
                color: card.greeter.foreground
                opacity: 0.022
            }

            Column {
                id: panelBody

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

                    Ink.InkLogo {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 28
                        color: card.greeter.accent
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 40
                        spacing: 2

                        Text {
                            width: parent.width
                            text: card.greeter.userLabel
                            color: card.greeter.foreground
                            font.family: "serif"
                            font.pixelSize: 18
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: {
                                var parts = []
                                if (card.greeter.hostText !== "") parts.push(card.greeter.hostText)
                                if (card.greeter.themeName !== "") parts.push(card.greeter.themeName)
                                return parts.join(" · ").toUpperCase()
                            }
                            color: card.greeter.muted
                            font.pixelSize: 8
                            font.letterSpacing: 1.3
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: card.greeter.muted
                    opacity: 0.2
                }

                Item {
                    width: parent.width
                    height: inputColumn.height
                    opacity: card.bodyShown ? 1 : 0

                    transform: Translate {
                        y: card.bodyShown ? 0 : 8
                        Behavior on y {
                            NumberAnimation { duration: card.greeter.closing ? 130 : 460; easing.type: Easing.OutCubic }
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: card.greeter.closing ? 110 : 420; easing.type: Easing.OutCubic }
                    }

                    Column {
                        id: inputColumn

                        width: parent.width
                        spacing: 12

                        Ink.InkPasswordField {
                            id: passwordField

                            width: parent.width
                            greeter: card.greeter
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
                                text: card.greeter.statusText.toUpperCase()
                                color: card.greeter.failed ? card.greeter.alertColor : card.greeter.muted
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
                                color: card.greeter.muted
                                opacity: card.greeter.password.length > 0 ? 0.6 : 0
                                font.pixelSize: 9
                                font.letterSpacing: 1.6

                                Behavior on opacity { NumberAnimation { duration: 160 } }
                            }
                        }

                        // A greeter tobblete a zarolokepernyohoz kepest: itt meg
                        // az sem eldontott, ki lep be es mibe.
                        Row {
                            width: parent.width
                            spacing: 10

                            Ink.InkPicker {
                                id: userPicker

                                greeter: card.greeter
                                pickerId: "user"
                                label: "USER"
                                entries: card.greeter.users
                                currentIndex: card.greeter.userIndex
                                width: (parent.width - parent.spacing) / 2
                            }

                            Ink.InkPicker {
                                id: sessionPicker

                                greeter: card.greeter
                                pickerId: "session"
                                label: "SESSION"
                                entries: card.greeter.sessions
                                currentIndex: card.greeter.sessionIndex
                                width: (parent.width - parent.spacing) / 2
                            }
                        }
                    }
                }
            }
        }

        // Rendszermuveletek: a kartyan kivul, mert nem a bejelentkezes reszei.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            opacity: card.bodyShown ? 1 : 0

            transform: Translate {
                y: card.bodyShown ? 0 : 10
                Behavior on y {
                    NumberAnimation { duration: card.greeter.closing ? 160 : 520; easing.type: Easing.OutCubic }
                }
            }

            Behavior on opacity {
                NumberAnimation { duration: card.greeter.closing ? 130 : 460; easing.type: Easing.OutCubic }
            }

            // Billentyuzetkiosztas -- kattintasra korbe lepteti a kiosztasokat.
            Ink.InkPowerButton {
                greeter: card.greeter
                visible: card.hasKeyboard
                glyph: "󰌌"
                label: card.layoutText
                onActivated: {
                    if (keyboard.layouts.length > 1)
                        keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
                    passwordField.forceInputFocus()
                }
            }

            Rectangle {
                width: 1
                height: 22
                color: card.greeter.muted
                opacity: 0.2
                visible: card.hasKeyboard
                anchors.verticalCenter: parent.verticalCenter
            }

            Ink.InkPowerButton {
                greeter: card.greeter
                glyph: "󰤄"
                label: "SLEEP"
                enabled: sddm.canSuspend
                onActivated: sddm.suspend()
            }

            Ink.InkPowerButton {
                greeter: card.greeter
                glyph: "󰜉"
                label: "RESTART"
                enabled: sddm.canReboot
                onActivated: sddm.reboot()
            }

            Ink.InkPowerButton {
                greeter: card.greeter
                glyph: "󰐥"
                label: "SHUTDOWN"
                danger: true
                enabled: sddm.canPowerOff
                onActivated: sddm.powerOff()
            }
        }
    }

    // A legordulo lista a kartya kozvetlen gyereke: igy semmilyen szuloi hatar
    // vagy alatta fekvo kattintasfogo nem nyeli el az egereseményeket.
    Ink.InkPickerList {
        id: dropdown

        z: 60
        greeter: card.greeter
        open: card.greeter.openPicker !== ""
        entries: card.activePicker === "user" ? card.greeter.users : card.greeter.sessions
        currentIndex: card.activePicker === "user" ? card.greeter.userIndex : card.greeter.sessionIndex

        onPicked: (index) => {
            if (card.activePicker === "user") card.greeter.selectUser(index)
            else card.greeter.selectSession(index)
            card.greeter.openPicker = ""
            passwordField.forceInputFocus()
        }
    }

    Component.onCompleted: Qt.callLater(passwordField.forceInputFocus)
}

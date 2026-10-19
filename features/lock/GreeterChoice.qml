pragma ComponentBehavior: Bound

import QtQuick
import "../../ui" as SharedUi

// Valaszto a greeter beviteli oszlopaban: kattintasra felfele nyilo listat
// mutat (a nezet a lap aljan ul, lefele nincs hely). Ket alakja van: `title`
// a felhasznalo neve az oszlop cimekent, a chip pedig a munkamenet -- igy a
// ketto nem versenyez egymassal. Egyetlen lehetoseg eseten nem nyithato.
Item {
    id: choice

    required property var lockRoot
    property string glyph: ""
    property string label: ""
    // Halvany kiegeszites a cim mogott (pl. a gep neve). Chip alakban nincs.
    property string detail: ""
    // [{ label }]
    property var entries: []
    property int currentIndex: 0
    property bool title: false
    property bool open: false
    property string accessibleName: label

    readonly property bool selectable: entries.length > 1
    readonly property bool lit: open || pressable.containsMouse || pressable.activeFocus
    readonly property color paper: lockRoot.background
    readonly property color accentColor: lockRoot.accent
    readonly property color mutedColor: lockRoot.muted
    readonly property color surfaceColor: lockRoot.surface
    readonly property color foregroundColor: lockRoot.foreground

    signal toggled()
    signal picked(int index)
    signal dismissed()

    implicitWidth: title ? titleRow.implicitWidth : chipRow.implicitWidth + 20
    implicitHeight: 28

    onOpenChanged: {
        if (open) {
            list.highlighted = Math.max(0, currentIndex)
            list.forceActiveFocus()
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: !choice.title
        radius: 6
        color: Qt.rgba(choice.paper.r, choice.paper.g, choice.paper.b, 0.6)
        border.width: 1
        border.color: choice.lit && choice.selectable
            ? Qt.rgba(choice.accentColor.r, choice.accentColor.g, choice.accentColor.b, 0.55)
            : Qt.rgba(choice.mutedColor.r, choice.mutedColor.g, choice.mutedColor.b, 0.22)

        Behavior on border.color { ColorAnimation { duration: 140 } }
    }

    Row {
        id: chipRow

        visible: !choice.title
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: choice.glyph !== ""
            text: choice.glyph
            color: choice.lit && choice.selectable ? choice.lockRoot.accent : choice.lockRoot.muted
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 13

            Behavior on color { ColorAnimation { duration: 140 } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: choice.label
            color: choice.lockRoot.foreground
            font.pixelSize: 12
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 220)
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: choice.selectable
            text: "󰅃"
            color: choice.lockRoot.muted
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 11
            rotation: choice.open ? 0 : 180

            Behavior on rotation { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
    }

    Row {
        id: titleRow

        visible: choice.title
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: choice.label
            color: choice.lit && choice.selectable ? choice.lockRoot.accent : choice.lockRoot.foreground
            font.pixelSize: 13
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 240)

            Behavior on color { ColorAnimation { duration: 140 } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: choice.selectable
            text: "󰅃"
            color: choice.lockRoot.muted
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 11
            rotation: choice.open ? 0 : 180

            Behavior on rotation { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: choice.detail !== ""
            text: "·  " + choice.detail
            color: choice.lockRoot.muted
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    SharedUi.Pressable {
        id: pressable

        anchors.fill: parent
        theme: choice.lockRoot.theme
        enabled: choice.selectable
        accessibleName: choice.accessibleName
        accessibleDescription: choice.label
        onClicked: choice.toggled()
    }

    // Felfele nyilo lista. A beviteli oszlop utolso elemei folott jelenik meg,
    // ezert a kesobbi testverek nem takarhatjak ki.
    Rectangle {
        id: popup

        anchors.left: parent.left
        anchors.bottom: parent.top
        anchors.bottomMargin: 8
        width: Math.max(220, choice.width)
        height: list.implicitHeight + 8
        z: 10
        radius: 8
        color: Qt.rgba(choice.surfaceColor.r, choice.surfaceColor.g, choice.surfaceColor.b, 0.96)
        border.width: 1
        border.color: Qt.rgba(choice.mutedColor.r, choice.mutedColor.g, choice.mutedColor.b, 0.22)
        opacity: choice.open ? 1 : 0
        visible: opacity > 0
        transform: Translate {
            y: choice.open ? 0 : 6
            Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        FocusScope {
            id: list

            property int highlighted: 0

            anchors.fill: parent
            anchors.margins: 4
            implicitHeight: rows.implicitHeight

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Up) {
                    list.highlighted = Math.max(0, list.highlighted - 1)
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                    list.highlighted = Math.min(choice.entries.length - 1, list.highlighted + 1)
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    choice.picked(list.highlighted)
                } else if (event.key === Qt.Key_Escape) {
                    choice.dismissed()
                } else {
                    return
                }
                event.accepted = true
            }

            Column {
                id: rows

                width: parent.width

                Repeater {
                    model: choice.entries

                    Rectangle {
                        id: row

                        required property var modelData
                        required property int index

                        readonly property bool current: index === choice.currentIndex
                        readonly property bool highlighted: index === list.highlighted

                        width: rows.width
                        height: 36
                        radius: 6
                        color: highlighted
                            ? Qt.rgba(choice.foregroundColor.r, choice.foregroundColor.g, choice.foregroundColor.b, 0.07)
                            : "transparent"

                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6
                            height: 6
                            radius: 3
                            color: choice.lockRoot.accent
                            visible: row.current
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 24
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.label
                            textFormat: Text.PlainText
                            color: row.current ? choice.lockRoot.accent : choice.lockRoot.foreground
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: list.highlighted = row.index
                            onClicked: choice.picked(row.index)
                        }
                    }
                }
            }
        }
    }
}

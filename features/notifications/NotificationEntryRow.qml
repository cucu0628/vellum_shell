import QtQuick
import Quickshell.Widgets
import "../../ui" as SharedUi

// Egy ertesites az ertesitesi kozpontban: ikon, alkalmazas es ido, cim,
// szoveg, alatta a muveletek. A torles hoverre jelenik meg.
Rectangle {
    id: row

    property var theme: null
    property var entry: null
    property int rowHeight: 62
    property bool grouped: false
    readonly property string panelFg: theme ? theme.foreground : "#f1e7d0"
    readonly property string panelAccent: theme ? theme.accent : "#d7472f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#9f8f7c"
    readonly property string inkBg: theme && theme.surface ? theme.surface : "#1b1613"
    readonly property color accentColor: panelAccent
    readonly property var entryActions: entry && entry.actions ? entry.actions : []
    readonly property var visibleActions: {
        var result = []
        for (var i = 0; i < entryActions.length; i++) {
            var action = entryActions[i]
            if (action && action.text && action.text.toString().trim() !== "") result.push(action)
        }
        return result
    }
    readonly property bool critical: entry ? entry.critical === true : false
    readonly property bool hovered: itemMouse.containsMouse || deleteMouse.containsMouse

    signal activated()
    signal deleteRequested()
    signal actionRequested(var action)

    height: rowHeight + (actionFlow.visible ? actionFlow.implicitHeight + 6 : 0)
    radius: 8
    color: row.critical
        ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, row.hovered ? 0.14 : 0.08)
        : (row.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent")

    Behavior on color { ColorAnimation { duration: 110 } }

    MouseArea {
        id: itemMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: row.entry && row.entry.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (row.entry && row.entry.defaultAction) row.activated()
        }
    }

    ClippingRectangle {
        id: iconBox

        anchors.left: parent.left
        anchors.leftMargin: 10
        y: (row.rowHeight - height) / 2
        width: 36
        height: 36
        radius: 8
        color: row.inkBg

        Image {
            id: entryImage

            anchors.fill: parent
            anchors.margins: 6
            source: row.entry ? row.entry.icon : ""
            sourceSize: Qt.size(72, 72)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
            smooth: true
            visible: source !== ""
        }

        Text {
            anchors.centerIn: parent
            text: row.critical ? "󰀦" : "󰂚"
            color: row.critical ? row.panelAccent : row.mutedFg
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 14
            visible: entryImage.source.toString() === ""
        }
    }

    Column {
        anchors.left: iconBox.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 44
        y: (row.rowHeight - height) / 2
        spacing: 2

        Item {
            width: parent.width
            height: 14

            Text {
                anchors.left: parent.left
                anchors.right: timeText.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: row.grouped
                    ? (row.entry && row.entry.summary ? row.entry.summary : qsTr("Notification"))
                    : (row.entry ? row.entry.appName : "")
                textFormat: Text.PlainText
                color: row.grouped ? row.panelFg : row.mutedFg
                font.pixelSize: row.grouped ? 12 : 10
                font.weight: row.grouped ? Font.Medium : Font.Normal
                elide: Text.ElideRight
            }

            Text {
                id: timeText

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: row.entry ? row.entry.time : ""
                textFormat: Text.PlainText
                color: row.mutedFg
                font.pixelSize: 10
            }
        }

        Text {
            width: parent.width
            text: row.entry && row.entry.summary ? row.entry.summary : qsTr("Notification")
            textFormat: Text.PlainText
            color: row.panelFg
            font.pixelSize: 12
            font.weight: Font.Medium
            elide: Text.ElideRight
            visible: !row.grouped
        }

        Text {
            width: parent.width
            text: row.entry ? row.entry.body : ""
            textFormat: Text.PlainText
            color: row.mutedFg
            font.pixelSize: 11
            elide: Text.ElideRight
            visible: text !== ""
        }
    }

    // Torles: csak hoverre latszik, de mindig kattinthato (billentyuzettel is).
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 8
        y: (row.rowHeight - height) / 2
        width: 28
        height: 28
        radius: 6
        opacity: row.hovered || deleteMouse.activeFocus ? 1 : 0
        color: deleteMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

        Behavior on opacity { NumberAnimation { duration: 110 } }

        Text {
            anchors.centerIn: parent
            text: "󰅖"
            color: deleteMouse.containsMouse ? row.panelFg : row.mutedFg
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: 12
        }

        SharedUi.Pressable {
            id: deleteMouse

            anchors.fill: parent
            theme: row.theme
            accessibleName: qsTr("Remove notification")
            onClicked: row.deleteRequested()
        }
    }

    Flow {
        id: actionFlow

        anchors.left: parent.left
        anchors.leftMargin: 58
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        spacing: 6
        visible: row.visibleActions.length > 0

        Repeater {
            model: row.visibleActions

            SharedUi.HeaderChip {
                required property var modelData

                width: Math.min(150, implicitWidth)
                theme: row.theme
                label: modelData.text.toString().trim()
                onClicked: row.actionRequested(modelData)
            }
        }
    }
}

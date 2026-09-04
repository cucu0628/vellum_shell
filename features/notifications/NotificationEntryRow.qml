import QtQuick

Rectangle {
    id: row

    property var theme: null
    property var entry: null
    property int rowHeight: 62
    property bool grouped: false
    readonly property string panelBg: theme ? theme.background : "#15110f"
    readonly property string panelFg: theme ? theme.foreground : "#f1e7d0"
    readonly property string panelAccent: theme ? theme.accent : "#d7472f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#9f8f7c"
    readonly property string inkBg: theme && theme.surface ? theme.surface : "#1b1613"
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

    signal activated()
    signal deleteRequested()
    signal actionRequested(var action)

    height: rowHeight + (actionFlow.visible ? actionFlow.implicitHeight + 8 : 0)
    color: itemMouse.containsMouse ? inkBg : "transparent"
    border.color: row.critical ? row.panelAccent : "transparent"
    border.width: 1

    Rectangle {
        width: 3
        height: parent.height
        color: row.panelAccent
        opacity: row.critical || itemMouse.containsMouse ? 1 : (row.grouped ? 0.25 : 0)
    }

    MouseArea {
        id: itemMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: row.entry && row.entry.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (row.entry && row.entry.defaultAction) row.activated()
        }
    }

    Row {
        anchors.fill: parent
        anchors.margins: 9
        anchors.leftMargin: 11
        anchors.bottomMargin: actionFlow.visible ? actionFlow.implicitHeight + 9 : 9
        spacing: 9

        Rectangle {
            width: 36
            height: 36
            anchors.verticalCenter: parent.verticalCenter
            color: row.inkBg
            border.color: row.mutedFg
            border.width: 1
            clip: true

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
                color: row.panelAccent
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 13
                visible: entryImage.source === ""
            }

        }

        Column {
            width: parent.width - 82
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Row {
                width: parent.width

                Text {
                    width: parent.width - 42
                    text: row.grouped
                        ? (row.entry && row.entry.summary ? row.entry.summary : "Notification")
                        : (row.entry ? row.entry.appName.toUpperCase() : "")
                    color: row.grouped ? row.panelFg : row.panelAccent
                    font.pixelSize: row.grouped ? 12 : 7
                    font.bold: true
                    font.letterSpacing: row.grouped ? 0 : 2
                    elide: Text.ElideRight
                }

                Text {
                    width: 42
                    text: row.entry ? row.entry.time : ""
                    color: row.mutedFg
                    font.pixelSize: 8
                    horizontalAlignment: Text.AlignRight
                }

            }

            Text {
                width: parent.width
                text: row.entry && row.entry.summary ? row.entry.summary : "Notification"
                color: row.panelFg
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                visible: !row.grouped
            }

            Text {
                width: parent.width
                text: row.entry ? row.entry.body : ""
                color: row.mutedFg
                font.pixelSize: 9
                elide: Text.ElideRight
                visible: text !== ""
            }

        }

        Rectangle {
            width: 28
            height: 28
            anchors.verticalCenter: parent.verticalCenter
            color: deleteMouse.containsMouse ? row.panelAccent : "transparent"
            border.color: deleteMouse.containsMouse ? row.panelAccent : row.mutedFg
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "󰅖"
                color: deleteMouse.containsMouse ? row.panelBg : row.mutedFg
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 12
            }

            MouseArea {
                id: deleteMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: row.deleteRequested()
            }

        }

    }

    Flow {
        id: actionFlow

        anchors.left: parent.left
        anchors.leftMargin: 56
        anchors.right: parent.right
        anchors.rightMargin: 9
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 7
        spacing: 5
        visible: row.visibleActions.length > 0

        Repeater {
            model: row.visibleActions

            Rectangle {
                property var action: modelData

                width: Math.min(130, Math.max(54, entryActionText.implicitWidth + 16))
                height: 21
                color: entryActionMouse.containsMouse ? row.panelAccent : row.inkBg
                border.color: row.panelAccent
                border.width: 1

                Text {
                    id: entryActionText

                    anchors.centerIn: parent
                    width: parent.width - 10
                    text: parent.action ? parent.action.text.toString().trim().toUpperCase() : ""
                    color: entryActionMouse.containsMouse ? row.panelBg : row.panelAccent
                    font.pixelSize: 8
                    font.bold: true
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }

                MouseArea {
                    id: entryActionMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        mouse.accepted = true
                        row.actionRequested(parent.action)
                    }
                }

            }

        }

    }

}

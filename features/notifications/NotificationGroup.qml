import QtQuick
import "." as NotificationUi

Item {
    id: group

    property var theme: null
    property var groupData: null
    property int rowHeight: 62
    property int rowGap: 6
    property bool animateTransitions: true
    readonly property string panelBg: theme ? theme.background : "#15110f"
    readonly property string panelFg: theme ? theme.foreground : "#f1e7d0"
    readonly property string panelAccent: theme ? theme.accent : "#d7472f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#9f8f7c"
    readonly property string inkBg: theme && theme.surface ? theme.surface : "#1b1613"
    readonly property var entries: groupData && groupData.entries ? groupData.entries : []
    readonly property bool grouped: entries.length > 1
    readonly property bool expanded: groupData ? groupData.expanded === true : false
    readonly property var visibleEntries: grouped && !expanded ? [entries[0]] : entries
    readonly property int hiddenCount: entries.length - visibleEntries.length

    signal toggleRequested()
    signal clearGroupRequested()
    signal itemActivated(int entryId)
    signal itemDeleteRequested(int entryId)
    signal itemActionRequested(int entryId, var action)

    implicitHeight: content.implicitHeight
    height: implicitHeight
    clip: true

    Column {
        id: content

        width: parent.width
        spacing: group.grouped ? 4 : 0

        Rectangle {
            id: header

            width: parent.width
            height: group.grouped ? 24 : 0
            visible: group.grouped
            color: headerMouse.containsMouse ? group.inkBg : "transparent"
            border.color: group.groupData && group.groupData.critical ? group.panelAccent : "transparent"
            border.width: 1

            MouseArea {
                id: headerMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: group.toggleRequested()
            }

            Text {
                textFormat: Text.PlainText
                id: chevron

                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: group.expanded ? "󰅀" : "󰅂"
                color: group.panelAccent
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 12
            }

            Text {
                textFormat: Text.PlainText
                anchors.left: chevron.right
                anchors.leftMargin: 6
                anchors.right: groupUnread.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: (group.groupData ? group.groupData.appName.toUpperCase() : "") + "  ×" + group.entries.length
                color: group.panelAccent
                font.pixelSize: 8
                font.bold: true
                font.letterSpacing: 2
                elide: Text.ElideRight
            }

            Text {
                textFormat: Text.PlainText
                id: groupUnread

                anchors.right: groupClear.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: group.groupData && group.groupData.unread > 0 ? group.groupData.unread + " NEW" : group.groupData ? group.groupData.time : ""
                color: group.groupData && group.groupData.unread > 0 ? group.panelFg : group.mutedFg
                font.family: "monospace"
                font.pixelSize: 8
                font.bold: true
            }

            Text {
                textFormat: Text.PlainText
                id: groupClear

                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: "CLEAR"
                color: groupClearMouse.containsMouse ? group.panelAccent : group.mutedFg
                font.family: "monospace"
                font.pixelSize: 8
                font.bold: true

                MouseArea {
                    id: groupClearMouse

                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        mouse.accepted = true
                        group.clearGroupRequested()
                    }
                }

            }

        }

        Repeater {
            model: group.visibleEntries

            NotificationUi.NotificationEntryRow {
                required property var modelData

                width: content.width
                theme: group.theme
                entry: modelData
                rowHeight: group.rowHeight
                grouped: group.grouped
                onActivated: group.itemActivated(modelData.id)
                onDeleteRequested: group.itemDeleteRequested(modelData.id)
                onActionRequested: action => group.itemActionRequested(modelData.id, action)
            }

        }

        Item {
            width: parent.width
            height: group.hiddenCount > 0 ? 16 : 0
            visible: group.hiddenCount > 0

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: parent.width - 16
                height: 1
                color: group.mutedFg
                opacity: 0.3
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 4
                width: parent.width - 34
                height: 1
                color: group.mutedFg
                opacity: 0.16
            }

            Text {
                textFormat: Text.PlainText
                anchors.left: parent.left
                anchors.leftMargin: 11
                anchors.bottom: parent.bottom
                text: "+" + group.hiddenCount + " MORE"
                color: stackMouse.containsMouse ? group.panelAccent : group.mutedFg
                font.family: "monospace"
                font.pixelSize: 8
                font.bold: true
            }

            MouseArea {
                id: stackMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: group.toggleRequested()
            }

        }

    }

    Behavior on height {
        enabled: group.animateTransitions

        NumberAnimation {
            duration: 170
            easing.type: Easing.OutCubic
        }

    }

}

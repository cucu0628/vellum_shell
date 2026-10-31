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
            height: group.grouped ? 28 : 0
            visible: group.grouped
            radius: 6
            color: headerMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"

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
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: group.expanded ? "󰅀" : "󰅂"
                color: group.mutedFg
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
                text: (group.groupData ? group.groupData.appName : "") + "  ·  " + group.entries.length
                color: group.panelFg
                font.pixelSize: 11
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                textFormat: Text.PlainText
                id: groupUnread

                anchors.right: groupClear.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: group.groupData && group.groupData.unread > 0 ? group.groupData.unread + " new" : group.groupData ? group.groupData.time : ""
                color: group.groupData && group.groupData.unread > 0 ? group.panelAccent : group.mutedFg
                font.pixelSize: 10
            }

            Text {
                textFormat: Text.PlainText
                id: groupClear

                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Clear")
                color: groupClearMouse.containsMouse ? group.panelFg : group.mutedFg
                font.pixelSize: 10

                MouseArea {
                    id: groupClearMouse

                    anchors.fill: parent
                    anchors.margins: -8
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
            height: group.hiddenCount > 0 ? 24 : 0
            visible: group.hiddenCount > 0

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 58
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Show %1 more").arg(group.hiddenCount)
                textFormat: Text.PlainText
                color: stackMouse.containsMouse ? group.panelFg : group.mutedFg
                font.pixelSize: 10
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

import QtQuick
import "." as NotificationUi
import "../../ui" as SharedUi

Item {
    id: center

    property var theme: null
    property bool opened: false
    property bool dnd: false
    property var history: []
    property var groups: []
    readonly property bool transitionActive: opened || menuContent.opacity > 0
    readonly property string panelBg: theme ? theme.background : "#15110f"
    readonly property string panelFg: theme ? theme.foreground : "#f1e7d0"
    readonly property string panelAccent: theme ? theme.accent : "#d7472f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#9f8f7c"
    readonly property string inkBg: theme && theme.surface ? theme.surface : "#1b1613"
    readonly property int visibleNotificationCount: 6
    readonly property int notificationRowHeight: 62
    readonly property int notificationGap: 6
    readonly property int notificationViewportHeight: visibleNotificationCount * notificationRowHeight
        + (visibleNotificationCount - 1) * notificationGap
    readonly property bool hasGroupedApps: {
        for (var i = 0; i < groups.length; i++) {
            if (groups[i].count > 1) return true
        }
        return false
    }
    readonly property bool allGroupsExpanded: {
        for (var i = 0; i < groups.length; i++) {
            if (groups[i].count > 1 && groups[i].expanded !== true) return false
        }
        return true
    }

    signal closeRequested()
    signal dndToggleRequested()
    signal clearRequested()
    signal itemDeleteRequested(int entryId)
    signal itemActivated(int entryId)
    signal itemActionRequested(int entryId, var action)
    signal groupToggleRequested(string groupKey)
    signal groupClearRequested(string groupKey)
    signal groupsExpandRequested(bool expanded)

    visible: transitionActive

    MouseArea {
        anchors.fill: parent
        enabled: center.opened
        onClicked: center.closeRequested()
    }

    Item {
        id: menuContent

        anchors.right: parent.right
        anchors.rightMargin: 10
        y: 32
        width: Math.min(380, parent.width - 20)
        height: center.opened ? Math.min(parent.height - 46, menuPanelColumn.implicitHeight + 32) : 0
        opacity: center.opened ? 1 : 0
        enabled: center.opened
        clip: true

        SharedUi.PopupFrame {
            anchors.fill: parent
            theme: center.theme

            MouseArea {
                anchors.fill: parent
                enabled: center.opened
                onClicked: (mouse) => {
                    return mouse.accepted = true;
                }
            }

            Flickable {
                anchors.fill: parent
                anchors.margins: 16
                contentWidth: width
                contentHeight: menuPanelColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: false

                Column {
                    id: menuPanelColumn

                    width: parent.width
                    spacing: 10

                    SharedUi.PopupHeader {
                        width: parent.width
                        theme: center.theme
                        title: "Notifications"
                        subtitle: center.history.length + (center.history.length === 1 ? " recent item" : " recent items")
                        trailingWidth: 80

                        Rectangle {
                            anchors.fill: parent
                            anchors.bottomMargin: 6
                            color: center.dnd ? center.panelAccent : center.inkBg
                            border.color: center.panelAccent
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: center.dnd ? "DND ON" : "DND"
                                color: center.dnd ? center.panelBg : center.panelAccent
                                font.family: "monospace"
                                font.pixelSize: 8
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: center.dndToggleRequested()
                            }

                        }

                    }

                    Row {
                        width: parent.width
                        height: 18
                        spacing: 8

                        Text {
                            width: parent.width - 136
                            text: "RECENT  /  " + center.history.length
                                + (center.groups.length > 0 && center.groups.length !== center.history.length ? "  ·  " + center.groups.length + " APPS" : "")
                            color: center.panelAccent
                            font.family: "monospace"
                            font.pixelSize: 8
                            font.letterSpacing: 2
                            font.bold: true
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            width: 64
                            height: parent.height
                            text: center.hasGroupedApps ? (center.allGroupsExpanded ? "COLLAPSE" : "EXPAND") : ""
                            color: expandAllMouse.containsMouse ? center.panelAccent : center.mutedFg
                            font.family: "monospace"
                            font.pixelSize: 9
                            font.bold: true
                            horizontalAlignment: Text.AlignRight
                            verticalAlignment: Text.AlignVCenter

                            MouseArea {
                                id: expandAllMouse

                                anchors.fill: parent
                                enabled: center.hasGroupedApps
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: center.groupsExpandRequested(!center.allGroupsExpanded)
                            }

                        }

                        Text {
                            width: 56
                            height: parent.height
                            text: center.history.length > 0 ? "CLEAR" : ""
                            color: center.mutedFg
                            font.family: "monospace"
                            font.pixelSize: 9
                            font.bold: true
                            horizontalAlignment: Text.AlignRight
                            verticalAlignment: Text.AlignVCenter

                            MouseArea {
                                anchors.fill: parent
                                enabled: center.history.length > 0
                                cursorShape: Qt.PointingHandCursor
                                onClicked: center.clearRequested()
                            }

                        }

                    }

                    Rectangle {
                        width: parent.width
                        height: center.history.length === 0 ? 52 : 0
                        visible: center.history.length === 0
                        color: "transparent"
                        border.color: "transparent"
                        border.width: 0

                        Row {
                            anchors.centerIn: parent
                            spacing: 9

                            Text {
                                text: "󰂜"
                                color: center.panelAccent
                                opacity: 0.55
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 17
                            }

                            Text {
                                text: "All quiet"
                                color: center.mutedFg
                                font.pixelSize: 11
                            }

                        }

                    }

                    Item {
                        width: parent.width
                        height: Math.min(historyList.contentHeight, center.notificationViewportHeight)
                        visible: center.history.length > 0

                        ListView {
                            id: historyList

                            anchors.fill: parent
                            anchors.rightMargin: interactive ? 6 : 0
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            interactive: contentHeight > height
                            model: center.opened ? center.groups : []
                            spacing: center.notificationGap
                            cacheBuffer: center.notificationRowHeight

                            delegate: NotificationUi.NotificationGroup {
                                required property var modelData

                                width: ListView.view.width
                                theme: center.theme
                                groupData: modelData
                                rowHeight: center.notificationRowHeight
                                rowGap: center.notificationGap
                                animateTransitions: center.opened
                                onToggleRequested: center.groupToggleRequested(modelData.key)
                                onClearGroupRequested: center.groupClearRequested(modelData.key)
                                onItemActivated: entryId => center.itemActivated(entryId)
                                onItemDeleteRequested: entryId => center.itemDeleteRequested(entryId)
                                onItemActionRequested: (entryId, action) => center.itemActionRequested(entryId, action)
                            }

                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            width: 2
                            color: center.mutedFg
                            opacity: historyList.interactive ? 0.18 : 0
                        }

                        Rectangle {
                            anchors.right: parent.right
                            width: 2
                            height: historyList.contentHeight > 0
                                ? Math.max(24, parent.height * historyList.visibleArea.heightRatio)
                                : 0
                            y: historyList.visibleArea.yPosition * parent.height
                            color: center.panelAccent
                            opacity: historyList.interactive ? 0.9 : 0
                        }

                    }

                }

            }

        }

        Behavior on height {
            NumberAnimation {
                duration: 210
                easing.type: Easing.OutCubic
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }

        }

    }

}

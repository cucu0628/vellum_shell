pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: lane

    required property var controller
    required property string zone
    required property string title
    required property var dragLayer
    required property var dragController
    property var theme: null

    readonly property var zoneItems: controller.items(zone)
    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string surface: theme && theme.surface ? theme.surface : "#1b1613"

    Item {
        id: heading

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 34

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: lane.title.toUpperCase()
            color: lane.accent
            font.pixelSize: 9
            font.bold: true
            font.letterSpacing: 1.3
        }

        Text {
            id: count

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: lane.zoneItems.length
            color: lane.muted
            font.family: "monospace"
            font.pixelSize: 9
        }
    }

    Rectangle {
        id: frame

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: heading.bottom
        anchors.bottom: parent.bottom
        color: Qt.rgba(1, 1, 1, 0.018)
        border.color: lane.targeted ? lane.accent : lane.muted
        border.width: 1

        Flickable {
            id: laneScroll

            anchors.fill: parent
            anchors.margins: 1
            contentWidth: width
            contentHeight: dropSurface.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Item {
                id: dropSurface

                width: laneScroll.width
                height: Math.max(laneScroll.height, cards.implicitHeight + 14)

                Column {
                    id: cards

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 7
                    spacing: 6

                    Repeater {
                        model: lane.zoneItems

                        BarModuleCard {
                            required property string modelData
                            required property int index

                            width: cards.width
                            controller: lane.controller
                            moduleId: modelData
                            zone: lane.zone
                            moduleIndex: index
                            dragLayer: lane.dragLayer
                            dragController: lane.dragController
                            theme: lane.theme
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    y: 7 + lane.dragController.targetIndex * 48 - 2
                    height: 3
                    visible: lane.targeted
                    color: lane.accent
                    z: 20
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 20
                    visible: lane.zoneItems.length === 0 && !lane.targeted
                    text: lane.zone === "hidden" ? "Drop here to hide" : "Drop modules here"
                    color: lane.muted
                    opacity: 0.7
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    readonly property bool targeted: dragController.draggedModuleId !== ""
        && dragController.targetZone === zone

    function containsPoint(sourceItem, x, y) {
        var point = sourceItem.mapToItem(frame, x, y);
        return point.x >= 0 && point.x <= frame.width
            && point.y >= 0 && point.y <= frame.height;
    }

    function indexForPoint(sourceItem, x, y) {
        var point = sourceItem.mapToItem(dropSurface, x, y);
        return indexAt(point.y);
    }

    function indexAt(y) {
        return Math.max(0, Math.min(zoneItems.length, Math.round((y - 7) / 48)));
    }
}

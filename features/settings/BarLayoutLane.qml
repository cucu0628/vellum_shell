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

        // Ugyanaz a csendes, nagybetus szakaszcimke, mint a lenyilo panelek
        // SectionBar-jan; mellette a darabszam.
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: lane.title.toUpperCase()
                color: lane.targeted ? lane.accent : lane.muted
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.letterSpacing: 1
            }

            Text {
                id: count

                anchors.verticalCenter: parent.verticalCenter
                text: lane.zoneItems.length
                color: lane.muted
                font.pixelSize: 10
                font.features: { "tnum": 1 }
            }
        }
    }

    Rectangle {
        id: frame

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: heading.bottom
        anchors.bottom: parent.bottom
        readonly property color accentColor: lane.accent

        radius: 12
        color: lane.targeted
            ? Qt.rgba(frame.accentColor.r, frame.accentColor.g, frame.accentColor.b, 0.08)
            : (lane.zone === "hidden" ? Qt.rgba(0, 0, 0, 0.16) : lane.surface)
        border.color: lane.targeted ? Qt.rgba(frame.accentColor.r, frame.accentColor.g, frame.accentColor.b, 0.55) : "transparent"
        border.width: 1

        Behavior on color { ColorAnimation { duration: 140 } }

        Flickable {
            id: laneScroll

            anchors.fill: parent
            anchors.margins: 2
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
                    radius: 1.5
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
                    font.pixelSize: 11
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

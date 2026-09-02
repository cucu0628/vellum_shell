import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Item {
    id: root

    required property var theme
    property bool expanded: false
    property bool contextMenuOpen: false
    property bool hasItems: trayRepeater.count > 0

    signal contextMenuRequested(var menu, real globalX)

    height: parent.height
    visible: hasItems
    width: hasItems && expanded ? (18 + trayExpander.implicitWidth + 10) : 18
    clip: true
    onHasItemsChanged: if (!hasItems) expanded = false
    onContextMenuOpenChanged: {
        if (contextMenuOpen) expanded = true
        else if (!trayMouse.containsMouse) expanded = false
    }
    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    MouseArea {
        id: trayMouse
        anchors.fill: parent
        hoverEnabled: true
        onEntered: if (root.hasItems) root.expanded = true
        onExited: if (!root.contextMenuOpen) root.expanded = false
        acceptedButtons: Qt.NoButton
    }

    Row {
        height: parent.height
        spacing: 10

        Item {
            width: 18
            height: parent.height
            opacity: root.hasItems ? 1 : 0.45

            Canvas {
                id: trayArrow
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                width: 14
                height: 14
                property color iconColor: trayMouse.containsMouse && root.hasItems ? root.theme.accent : (root.hasItems ? root.theme.foreground : "#9f8f7c")
                onIconColorChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = iconColor
                    ctx.lineWidth = 2
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    ctx.moveTo(root.expanded ? 3 : 11, 2)
                    ctx.lineTo(root.expanded ? 11 : 3, 7)
                    ctx.lineTo(root.expanded ? 3 : 11, 12)
                    ctx.stroke()
                }
                Connections {
                    target: root
                    function onExpandedChanged() { trayArrow.requestPaint() }
                }
                Behavior on iconColor { ColorAnimation { duration: 120 } }
            }
        }

        Row {
            id: trayExpander
            height: parent.height
            spacing: 10
            opacity: root.expanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

            Repeater {
                id: trayRepeater
                model: SystemTray.items

                Item {
                    id: trayItem
                    required property var modelData
                    width: 18
                    height: parent.height

                    Image {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -1
                        width: 14
                        height: 14
                        source: trayItem.modelData.icon || ""
                        sourceSize: Qt.size(14, 14)
                        visible: source !== ""
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -1
                        text: "󰀻"
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 12
                        color: root.theme.foreground
                        visible: !trayItem.modelData.icon || trayItem.modelData.icon === ""
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                trayItem.modelData.activate()
                            } else {
                                var pos = trayItem.mapToGlobal(0, 0)
                                root.contextMenuRequested(trayItem.modelData.menu, pos.x)
                            }
                        }
                    }
                }
            }
        }
    }
}

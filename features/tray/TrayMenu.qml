import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import "../../ui" as SharedUi

PanelWindow {
    id: trayMenu

    property var theme: null
    property int barHeight: 26
    property var menu: null
    property int menuX: 0

    visible: false
    color: "transparent"

    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "quickshell.menu"
    WlrLayershell.exclusiveZone: -1

    readonly property string panelBg: theme ? theme.background : "#15110f"
    readonly property string panelFg: theme ? theme.foreground : "#f1e7d0"
    readonly property string panelAccent: theme ? theme.accent : "#d7472f"
    readonly property string mutedFg: theme && theme.muted ? theme.muted : "#9f8f7c"
    readonly property string inkBg: theme && theme.surface ? theme.surface : "#1b1613"

    function openFor(targetScreen, targetMenu, globalX) {
        screen = targetScreen
        menu = targetMenu
        menuX = globalX
        visible = true
    }

    function close() {
        visible = false
        menu = null
    }

    QsMenuOpener {
        id: menuOpener
        menu: trayMenu.menu
    }

    MouseArea { anchors.fill: parent; onClicked: trayMenu.close() }

    Item {
        x: Math.max(10, Math.min(trayMenu.width - width - 10, trayMenu.menuX - width / 2 + 8))
        y: trayMenu.barHeight
        width: 260
        height: menuColumn.implicitHeight + 18
        clip: true

        SharedUi.PopupFrame {
            anchors.fill: parent
            anchors.topMargin: -2
            theme: trayMenu.theme

            MouseArea { anchors.fill: parent; onClicked: (mouse) => mouse.accepted = true }

            Column {
                id: menuColumn
                anchors { fill: parent; margins: 9; topMargin: 12 }
                spacing: 3

                Repeater {
                    model: trayMenu.visible ? menuOpener.children : null

                    Rectangle {
                        width: parent.width
                        height: modelData.isSeparator ? 9 : 31
                        color: !modelData.isSeparator && itemMouse.containsMouse ? inkBg : "transparent"
                        radius: 0
                        opacity: modelData.enabled === false ? 0.45 : 1

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            visible: !modelData.isSeparator
                            width: 3
                            height: parent.height
                            anchors.left: parent.left
                            color: panelAccent
                            opacity: itemMouse.containsMouse ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        }

                        Rectangle {
                            visible: modelData.isSeparator
                            width: parent.width - 10
                            height: 1
                            color: mutedFg
                            opacity: 0.2
                            anchors.centerIn: parent
                        }

                        Text {
                            visible: !modelData.isSeparator
                            text: modelData.text ? modelData.text.replace(/&/g, "") : ""
                            color: itemMouse.containsMouse ? panelAccent : panelFg
                            font.pixelSize: 12
                            font.weight: itemMouse.containsMouse ? Font.DemiBold : Font.Normal
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            elide: Text.ElideRight
                            width: parent.width - 24
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: modelData.isSeparator || modelData.enabled === false ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: {
                                if (!modelData.isSeparator && modelData.enabled !== false) {
                                    modelData.triggered()
                                    trayMenu.close()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

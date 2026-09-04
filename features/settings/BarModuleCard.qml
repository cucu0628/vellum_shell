pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: card

    required property var controller
    required property string moduleId
    required property string zone
    required property int moduleIndex
    required property var dragLayer
    required property var dragController
    property var theme: null
    property bool dragOccurred: false

    readonly property var moduleInfo: controller.moduleInfo(moduleId)
    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string surface: theme && theme.surface ? theme.surface : "#1b1613"
    readonly property bool dragging: dragArea.drag.active

    height: 42
    color: dragArea.containsMouse || activeFocus ? Qt.rgba(1, 1, 1, 0.065) : surface
    border.color: dragging || activeFocus ? accent : Qt.rgba(1, 1, 1, 0.1)
    border.width: 1
    opacity: dragging ? 0.35 : 1
    activeFocusOnTab: true

    function adjacentZone(delta) {
        var at = controller.zoneNames.indexOf(zone);
        return controller.zoneNames[Math.max(0, Math.min(controller.zoneNames.length - 1, at + delta))];
    }

    function restoreDragProxy() {
        dragProxy.parent = card;
        dragProxy.x = 0;
        dragProxy.y = 0;
    }

    Keys.onUpPressed: (event) => {
        controller.moveModule(moduleId, zone, moduleIndex - 1);
        event.accepted = true;
    }
    Keys.onDownPressed: (event) => {
        controller.moveModule(moduleId, zone, moduleIndex + 2);
        event.accepted = true;
    }
    Keys.onLeftPressed: (event) => {
        var target = adjacentZone(-1);
        if (target !== zone)
            controller.moveModule(moduleId, target, controller.items(target).length);
        event.accepted = true;
    }
    Keys.onRightPressed: (event) => {
        var target = adjacentZone(1);
        if (target !== zone)
            controller.moveModule(moduleId, target, controller.items(target).length);
        event.accepted = true;
    }
    Keys.onDeletePressed: (event) => {
        controller.moveModule(moduleId, "hidden", controller.hiddenModules.length);
        event.accepted = true;
    }

    Accessible.role: Accessible.ListItem
    Accessible.name: moduleInfo.label
    Accessible.description: "Drag to move. Arrow keys move between positions and zones; Delete hides."

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        text: card.moduleInfo.icon
        color: card.accent
        font.family: "Symbols Nerd Font Mono"
        font.pixelSize: 13
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 36
        anchors.right: grip.left
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: card.moduleInfo.label
        color: card.foreground
        font.pixelSize: 11
        elide: Text.ElideRight
    }

    Text {
        id: grip

        anchors.right: parent.right
        anchors.rightMargin: 9
        anchors.verticalCenter: parent.verticalCenter
        text: "⠿"
        color: dragArea.containsMouse || card.activeFocus ? card.accent : card.muted
        font.pixelSize: 15
    }

    // A proxy mozog, maga a Column altal pozicionalt kartya a helyen marad.
    // Igy a drag nem rangatja szet a celzonak hasznalt listat.
    Rectangle {
        id: dragProxy

        width: card.width
        height: card.height
        visible: card.dragging
        z: 1000
        color: card.surface
        border.color: card.accent
        border.width: 1
        opacity: 0.92

        Text {
            anchors.centerIn: parent
            width: parent.width - 16
            text: card.moduleInfo.label
            color: card.foreground
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: dragArea

        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: dragProxy
        drag.threshold: 5
        onPressed: {
            card.forceActiveFocus();
            card.dragOccurred = false;
            card.dragController.cancelDrag();
            if (card.dragLayer) {
                var position = card.mapToItem(card.dragLayer, 0, 0);
                dragProxy.parent = card.dragLayer;
                dragProxy.x = position.x;
                dragProxy.y = position.y;
            }
        }
        onPositionChanged: {
            if (!drag.active)
                return;
            card.dragOccurred = true;
            card.dragController.updateDrag(card.moduleId, dragProxy,
                dragProxy.width / 2, dragProxy.height / 2);
        }
        onReleased: {
            if (card.dragOccurred)
                card.dragController.finishDrag();
            else
                card.dragController.cancelDrag();
            card.restoreDragProxy();
            card.dragOccurred = false;
        }
        onCanceled: {
            card.dragController.cancelDrag();
            card.restoreDragProxy();
            card.dragOccurred = false;
        }
    }
}

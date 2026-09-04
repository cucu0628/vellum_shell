import QtQuick
import "../../ui" as SharedUi

Item {
    id: page

    required property var controller
    property var theme: null

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    property string draggedModuleId: ""
    property string targetZone: ""
    property int targetIndex: -1

    function updateDrag(moduleId, sourceItem, x, y) {
        var candidates = [leftLane, centerLane, rightLane, hiddenLane];
        draggedModuleId = moduleId;
        targetZone = "";
        targetIndex = -1;

        for (var i = 0; i < candidates.length; i++) {
            var lane = candidates[i];
            if (!lane.containsPoint(sourceItem, x, y))
                continue;
            targetZone = lane.zone;
            targetIndex = lane.indexForPoint(sourceItem, x, y);
            return;
        }
    }

    function finishDrag() {
        var moduleId = draggedModuleId;
        var zone = targetZone;
        var index = targetIndex;
        cancelDrag();
        if (moduleId === "" || zone === "" || index < 0)
            return;

        // Az eredeti delegate csak az egerevent vege utan epuljon ujra.
        Qt.callLater(function() {
            page.controller.moveModule(moduleId, zone, index);
        });
    }

    function cancelDrag() {
        draggedModuleId = "";
        targetZone = "";
        targetIndex = -1;
    }

    SettingsSection {
        id: section

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        theme: page.theme
        title: "Top bar layout"
        description: "Drag modules between zones or move them to Hidden"
    }

    Item {
        id: toolbar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: section.bottom
        height: 42

        Text {
            anchors.left: parent.left
            anchors.right: resetButton.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: page.controller.errorMessage !== ""
                ? page.controller.errorMessage
                : "Changes apply live. Arrow keys move a focused card; Delete hides it."
            color: page.controller.errorMessage !== "" ? page.accent : page.muted
            font.pixelSize: 10
            elide: Text.ElideRight
        }

        SharedUi.ActionButton {
            id: resetButton

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 28
            theme: page.theme
            label: "Reset layout"
            onClicked: page.controller.reset()
        }
    }

    Row {
        id: lanes

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: toolbar.bottom
        anchors.bottom: parent.bottom
        spacing: 10

        BarLayoutLane {
            id: leftLane

            width: (lanes.width - lanes.spacing * 3) / 4
            height: lanes.height
            controller: page.controller
            dragLayer: dragOverlay
            dragController: page
            zone: "left"
            title: "Left"
            theme: page.theme
        }

        BarLayoutLane {
            id: centerLane

            width: (lanes.width - lanes.spacing * 3) / 4
            height: lanes.height
            controller: page.controller
            dragLayer: dragOverlay
            dragController: page
            zone: "center"
            title: "Center"
            theme: page.theme
        }

        BarLayoutLane {
            id: rightLane

            width: (lanes.width - lanes.spacing * 3) / 4
            height: lanes.height
            controller: page.controller
            dragLayer: dragOverlay
            dragController: page
            zone: "right"
            title: "Right"
            theme: page.theme
        }

        BarLayoutLane {
            id: hiddenLane

            width: (lanes.width - lanes.spacing * 3) / 4
            height: lanes.height
            controller: page.controller
            dragLayer: dragOverlay
            dragController: page
            zone: "hidden"
            title: "Hidden"
            theme: page.theme
        }
    }

    // A huzott kartya ide kerul atmenetileg, hogy egyik gorgetheto lane se
    // vagja le, amikor a mutato atlep a kovetkezo zonaba.
    Item {
        id: dragOverlay

        anchors.fill: parent
        z: 1000
    }
}

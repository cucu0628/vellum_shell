import QtQuick
import Quickshell.Services.Mpris
import "../../ui" as SharedUi

Item {
    id: page

    required property var controller
    // core/MprisController: a lejatszo-kivetelek kezelese.
    property var mpris: null
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

    // Az oldal cimet es leirasat a fejlec adja; itt csak a teendo es a
    // visszaallitas all.
    Item {
        id: toolbar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 44

        Text {
            anchors.left: parent.left
            anchors.right: resetButton.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: page.controller.errorMessage !== ""
                ? page.controller.errorMessage
                : "Changes apply live. Arrow keys move a focused card; Delete hides it."
            textFormat: Text.PlainText
            color: page.controller.errorMessage !== "" ? page.accent : page.muted
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        SharedUi.ActionButton {
            id: resetButton

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
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
        anchors.topMargin: 4
        anchors.bottom: mediaSection.visible ? mediaSection.top : parent.bottom
        anchors.bottomMargin: mediaSection.visible ? 24 : 0
        spacing: 12

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

    // -- lejatszo-kivetelek ---------------------------------------------------
    // A sav jelzoje es a dashboard nem mutatja az itt kihagyott lejatszokat.
    Item {
        id: mediaSection

        // A futo lejatszok es a mar felvett kivetelek, nev szerint egyszer.
        readonly property var entries: {
            var names = []
            var seen = {}
            var running = Mpris.players.values
            for (var i = 0; i < running.length; i++) {
                var name = running[i].identity || running[i].dbusName || ""
                if (name !== "" && !seen[name.toLowerCase()]) {
                    seen[name.toLowerCase()] = true
                    names.push({ "name": name, "running": true })
                }
            }
            var ignored = page.mpris ? page.mpris.ignoredPlayers : []
            for (var j = 0; j < ignored.length; j++) {
                if (!seen[ignored[j].toLowerCase()]) {
                    seen[ignored[j].toLowerCase()] = true
                    names.push({ "name": ignored[j], "running": false })
                }
            }
            return names
        }

        function isIgnored(name) {
            var ignored = page.mpris ? page.mpris.ignoredPlayers : []
            for (var i = 0; i < ignored.length; i++) {
                if (ignored[i].toLowerCase() === name.toLowerCase()) return true
            }
            return false
        }

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: mediaColumn.height
        visible: page.mpris !== null

        SettingsSection {
            id: mediaColumn

            width: parent.width
            theme: page.theme
            title: "Media players"
            description: "Ignored players never show up in the top bar or the dashboard. Click a player to switch it."

            Flow {
                width: parent.width
                topPadding: 12
                bottomPadding: 12
                spacing: 8

                Repeater {
                    model: mediaSection.entries

                    Rectangle {
                        id: playerChip

                        required property var modelData
                        readonly property bool ignored: mediaSection.isIgnored(modelData.name)

                        width: chipRow.implicitWidth + 24
                        height: 32
                        radius: 8
                        color: chipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)

                        Row {
                            id: chipRow

                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: playerChip.ignored ? "󰈉" : "󰈈"
                                color: playerChip.ignored ? page.muted : page.accent
                                font.family: "Symbols Nerd Font Mono"
                                font.pixelSize: 14
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: playerChip.modelData.name
                                textFormat: Text.PlainText
                                color: playerChip.ignored ? page.muted : page.foreground
                                font.pixelSize: 12
                                font.strikeout: playerChip.ignored
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: playerChip.ignored ? "Ignored" : (playerChip.modelData.running ? "Shown" : "")
                                color: page.muted
                                font.pixelSize: 10
                                visible: text !== ""
                            }
                        }

                        SharedUi.Pressable {
                            id: chipMouse

                            anchors.fill: parent
                            theme: page.theme
                            focusRadius: playerChip.radius
                            accessibleName: (playerChip.ignored ? "Show " : "Ignore ") + playerChip.modelData.name
                            onClicked: page.mpris.setIgnored(playerChip.modelData.name, !playerChip.ignored)
                        }
                    }
                }

                // Nev szerint is felveheto (pl. ha a lejatszo most nem fut).
                TextSetting {
                    id: addPlayerField

                    width: 240
                    height: 32
                    theme: page.theme
                    placeholder: "Add a player name to ignore"
                    onCommitted: (value) => {
                        if (value.trim() !== "") page.mpris.setIgnored(value, true)
                        addPlayerField.clear()
                    }
                }
            }
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

pragma ComponentBehavior: Bound

import QtQuick
import "../../ui" as SharedUi

Item {
    id: page

    required property var controller
    property var theme: null
    property string mode: "autostart"
    property string query: ""

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string surface: theme && theme.surface ? theme.surface : "#1b1613"
    readonly property var sourceItems: mode === "autostart" ? controller.autostartEntries : controller.services
    readonly property bool loading: mode === "autostart" ? controller.autostartLoading : controller.servicesLoading
    readonly property string errorMessage: mode === "autostart" ? controller.autostartError : controller.servicesError
    readonly property var filteredItems: {
        var needle = query.trim().toLowerCase();
        if (needle === "")
            return sourceItems;

        var result = [];
        for (var i = 0; i < sourceItems.length; i++) {
            var item = sourceItems[i];
            var haystack = mode === "autostart"
                ? (item.name + " " + item.id + " " + item.command)
                : (item.unit + " " + item.description + " " + item.unitState);
            if (haystack.toLowerCase().indexOf(needle) >= 0)
                result.push(item);
        }
        return result;
    }

    // Az oldal cime a fejlecben all. Itt: nezetvalto es frissites, kereso, egy
    // rovid osszesito sor, alatta a lista egy kerek kartyaban.
    Item {
        id: toolbar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 36

        SegmentedTabs {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            theme: page.theme
            model: [{
                "label": "Login apps",
                "value": "autostart"
            }, {
                "label": "User services",
                "value": "services"
            }]
            value: page.mode
            onActivated: (value) => {
                page.mode = value;
                searchField.text = "";
            }
        }

        SharedUi.ActionButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            enabled: !page.loading
            theme: page.theme
            label: "Refresh"
            onClicked: page.controller.reload()
        }
    }

    SharedUi.SearchField {
        id: searchField

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: toolbar.bottom
        anchors.topMargin: 16
        height: 40
        opened: true
        indicator: "⌕"
        placeholder: page.mode === "autostart" ? "Search login applications…" : "Search user services…"
        foreground: page.foreground
        accent: page.accent
        muted: page.muted
        surface: page.surface
        inputVerticalPadding: 10
        onTextEdited: (text) => page.query = text
        onKeyPressed: (event) => {
            if (event.key === Qt.Key_Escape && searchField.text !== "") {
                searchField.text = "";
                event.accepted = true;
            }
        }
    }

    Item {
        id: summary

        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.top: searchField.bottom
        height: 36

        Text {
            anchors.left: parent.left
            anchors.right: columnHint.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: page.loading
                ? "Reading settings…"
                : (page.errorMessage !== ""
                    ? page.errorMessage
                    : (page.query.trim() === ""
                        ? page.sourceItems.length + (page.mode === "autostart" ? " login applications" : " user services")
                        : page.filteredItems.length + " of " + page.sourceItems.length))
            textFormat: Text.PlainText
            color: page.errorMessage !== "" ? page.accent : page.muted
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        // A kapcsolok oszlopanak jelentese, a kapcsolok folott.
        Text {
            id: columnHint

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Start at login"
            color: page.muted
            font.pixelSize: 10
        }
    }

    Rectangle {
        id: listCard

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: summary.bottom
        anchors.bottom: parent.bottom
        radius: 12
        color: page.surface

        ListView {
            id: entryList

            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            clip: true
            model: page.filteredItems
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: entryRow

                required property var modelData
                required property int index

                width: ListView.view.width
                height: 60

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 1
                    visible: entryRow.index > 0
                    color: page.muted
                    opacity: 0.12
                }

                Column {
                    anchors.left: parent.left
                    anchors.right: controls.left
                    anchors.rightMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: page.mode === "autostart" ? entryRow.modelData.name : entryRow.modelData.unit
                        textFormat: Text.PlainText
                        color: page.foreground
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: page.mode === "autostart"
                            ? ((entryRow.modelData.command || "No command shown") + "  ·  " + entryRow.modelData.source)
                            : ((entryRow.modelData.description || "User service") + "  ·  " + entryRow.modelData.unitState)
                        textFormat: Text.PlainText
                        color: page.muted
                        font.family: page.mode === "autostart" ? "monospace" : "sans-serif"
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }

                Row {
                    id: controls

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    StatusBadge {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: page.mode === "services"
                        theme: page.theme
                        active: entryRow.modelData.active === true
                        text: entryRow.modelData.active ? entryRow.modelData.substate : "stopped"
                    }

                    SharedUi.ActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: page.mode === "services"
                        enabled: page.controller.busyTarget === ""
                        implicitWidth: 64
                        theme: page.theme
                        label: entryRow.modelData.active ? "Stop" : "Start"
                        accessibleName: (entryRow.modelData.active ? "Stop " : "Start ") + entryRow.modelData.unit
                        onClicked: page.controller.setServiceRunning(entryRow.modelData.unit, !entryRow.modelData.active)
                    }

                    SharedUi.SettingToggle {
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: page.controller.busyTarget === ""
                            && (page.mode === "autostart" || entryRow.modelData.enableAllowed)
                        opacity: enabled ? 1 : 0.45
                        theme: page.theme
                        checked: entryRow.modelData.enabled
                        accessibleName: page.mode === "autostart"
                            ? "Start " + entryRow.modelData.name + " at login"
                            : "Enable " + entryRow.modelData.unit + " at login"
                        onToggled: (value) => {
                            if (page.mode === "autostart")
                                page.controller.setAutostart(entryRow.modelData.id, value);
                            else
                                page.controller.setServiceEnabled(entryRow.modelData.unit, value);
                        }
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            width: parent.width - 48
            visible: !page.loading && page.filteredItems.length === 0
            text: page.errorMessage !== ""
                ? page.errorMessage
                : (page.query.trim() !== "" ? "No matching entries." : (page.mode === "autostart" ? "No login applications found." : "No user services found."))
            textFormat: Text.PlainText
            color: page.muted
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }
}

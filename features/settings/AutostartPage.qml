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

    SettingsSection {
        id: section

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        theme: page.theme
        title: "Autostart / Services"
        description: "Login applications and systemd user services"
    }

    Item {
        id: toolbar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: section.bottom
        height: 42

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            SharedUi.ActionButton {
                height: 28
                theme: page.theme
                label: "Login apps"
                primary: page.mode === "autostart"
                onClicked: page.mode = "autostart"
            }

            SharedUi.ActionButton {
                height: 28
                theme: page.theme
                label: "User services"
                primary: page.mode === "services"
                onClicked: page.mode = "services"
            }
        }

        SharedUi.ActionButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 28
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
        height: 40
        opened: true
        indicator: "⌕"
        placeholder: page.mode === "autostart" ? "Search login applications..." : "Search user services..."
        foreground: page.foreground
        accent: page.accent
        muted: page.muted
        surface: page.surface
        inputVerticalPadding: 10
        onTextEdited: (text) => page.query = text
    }

    Item {
        id: summary

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: searchField.bottom
        height: 34

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: page.loading ? "Reading settings..." : (page.errorMessage !== "" ? page.errorMessage : page.filteredItems.length + " entries")
            color: page.errorMessage !== "" ? page.accent : page.muted
            font.pixelSize: 10
        }
    }

    Rectangle {
        id: tableHeader

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: summary.bottom
        height: 30
        color: page.surface

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: page.mode === "autostart" ? "LOGIN APPLICATION" : "USER SERVICE"
            color: page.accent
            font.pixelSize: 9
            font.bold: true
            font.letterSpacing: 1.4
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: page.mode === "autostart" ? "START AT LOGIN" : "STATE / LOGIN"
            color: page.accent
            font.pixelSize: 9
            font.bold: true
            font.letterSpacing: 1.4
        }
    }

    ListView {
        id: entryList

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: tableHeader.bottom
        anchors.bottom: parent.bottom
        clip: true
        model: page.filteredItems
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: entryRow

            required property var modelData
            required property int index

            width: ListView.view.width
            height: 58
            color: index % 2 === 0 ? "transparent" : Qt.rgba(1, 1, 1, 0.025)

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: controls.left
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    width: parent.width
                    text: page.mode === "autostart" ? entryRow.modelData.name : entryRow.modelData.unit
                    color: page.foreground
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: page.mode === "autostart"
                        ? ((entryRow.modelData.command || "No command shown") + "  ·  " + entryRow.modelData.source)
                        : ((entryRow.modelData.description || "User service") + "  ·  " + entryRow.modelData.unitState)
                    color: page.muted
                    font.family: "monospace"
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }
            }

            Row {
                id: controls

                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle {
                    visible: page.mode === "services"
                    width: 68
                    height: 24
                    color: "transparent"
                    border.color: entryRow.modelData.active ? page.accent : page.muted
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: entryRow.modelData.active ? entryRow.modelData.substate : "stopped"
                        color: entryRow.modelData.active ? page.accent : page.muted
                        font.pixelSize: 9
                    }
                }

                SharedUi.ActionButton {
                    visible: page.mode === "services"
                    enabled: page.controller.busyTarget === ""
                    width: 66
                    height: 26
                    theme: page.theme
                    label: entryRow.modelData.active ? "Stop" : "Start"
                    onClicked: page.controller.setServiceRunning(entryRow.modelData.unit, !entryRow.modelData.active)
                }

                SharedUi.SettingToggle {
                    enabled: page.controller.busyTarget === ""
                        && (page.mode === "autostart" || entryRow.modelData.enableAllowed)
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

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: page.muted
                opacity: 0.1
            }
        }
    }

    Text {
        anchors.centerIn: entryList
        visible: !page.loading && page.filteredItems.length === 0
        text: page.errorMessage !== "" ? page.errorMessage : "No matching entries."
        color: page.muted
        font.pixelSize: 11
    }
}

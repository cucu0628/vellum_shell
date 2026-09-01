pragma ComponentBehavior: Bound

import QtQuick
import "../../ui" as SharedUi

// Keresheto gyorsbillentyu-jegyzek. A forras tovabbra is a kozos
// KeybindingsController, ez az oldal csak szur es megjelenit.
Item {
    id: page

    required property var controller
    property var theme: null
    property string query: ""

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string surface: theme && theme.surface ? theme.surface : "#1b1613"
    readonly property var filteredBindings: {
        var needle = query.trim().toLowerCase();
        if (needle === "")
            return controller.bindings;

        var terms = needle.split(/\s+/);
        var result = [];
        for (var i = 0; i < controller.bindings.length; i++) {
            var binding = controller.bindings[i];
            var haystack = (binding.shortcut + " " + binding.action).toLowerCase();
            var matches = true;
            for (var j = 0; j < terms.length; j++) {
                if (haystack.indexOf(terms[j]) < 0) {
                    matches = false;
                    break;
                }
            }
            if (matches)
                result.push(binding);
        }
        return result;
    }

    SettingsSection {
        id: section

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        theme: page.theme
        title: "Shortcut index"
        description: "Filter the bindings currently reported by Hyprland"
    }

    SharedUi.SearchField {
        id: searchField

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: section.bottom
        height: 42
        opened: true
        indicator: "⌕"
        placeholder: "Search shortcuts or actions..."
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
        anchors.right: parent.right
        anchors.top: searchField.bottom
        height: 38

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: page.controller.loading
                ? "Reading shortcuts..."
                : page.filteredBindings.length + (page.query === "" ? " shortcuts" : " of " + page.controller.bindings.length + " shortcuts")
            color: page.muted
            font.pixelSize: 10
        }

        ActionButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 26
            theme: page.theme
            label: "Refresh"
            onClicked: page.controller.reload()
        }
    }

    Rectangle {
        id: tableHeader

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: summary.bottom
        height: 32
        color: page.surface

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 270
            text: "SHORTCUT"
            color: page.accent
            font.pixelSize: 9
            font.bold: true
            font.letterSpacing: 1.5
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 294
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "ACTION"
            color: page.accent
            font.pixelSize: 9
            font.bold: true
            font.letterSpacing: 1.5
        }
    }

    ListView {
        id: bindingList

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: tableHeader.bottom
        anchors.bottom: parent.bottom
        clip: true
        model: page.filteredBindings
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: bindingRow

            required property var modelData
            required property int index

            width: ListView.view.width
            height: 40
            color: index % 2 === 0 ? "transparent" : Qt.rgba(1, 1, 1, 0.025)

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 270
                text: bindingRow.modelData.shortcut
                color: page.foreground
                font.family: "monospace"
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 294
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: bindingRow.modelData.action
                color: page.muted
                font.pixelSize: 11
                elide: Text.ElideRight
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
        anchors.centerIn: bindingList
        visible: !page.controller.loading && page.filteredBindings.length === 0
        text: page.query === "" ? "No shortcuts reported by Hyprland." : "No matching shortcuts."
        color: page.muted
        font.pixelSize: 11
    }
}

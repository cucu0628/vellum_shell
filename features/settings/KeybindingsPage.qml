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

    // Az oldal cime a fejlecben all. Itt: kereso a frissitessel, egy rovid
    // osszesito sor, alatta a lista egy kerek kartyaban. Balra a muvelet, jobbra
    // a kombinacio billentyusapkakkent -- igy a lista a muvelet neve szerint
    // olvashato vegig.
    SharedUi.SearchField {
        id: searchField

        anchors.left: parent.left
        anchors.right: refreshButton.left
        anchors.rightMargin: 8
        anchors.top: parent.top
        height: 40
        opened: true
        indicator: "⌕"
        placeholder: "Search shortcuts or actions…"
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

    SharedUi.ActionButton {
        id: refreshButton

        anchors.right: parent.right
        anchors.verticalCenter: searchField.verticalCenter
        enabled: !page.controller.loading
        theme: page.theme
        label: "Refresh"
        onClicked: page.controller.reload()
    }

    Text {
        id: summary

        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.right: parent.right
        anchors.top: searchField.bottom
        height: 36
        verticalAlignment: Text.AlignVCenter
        text: page.controller.loading
            ? "Reading shortcuts…"
            : page.filteredBindings.length + (page.query.trim() === "" ? " shortcuts" : " of " + page.controller.bindings.length + " shortcuts")
        color: page.muted
        font.pixelSize: 11
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
            id: bindingList

            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            clip: true
            model: page.filteredBindings
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: bindingRow

                required property var modelData
                required property int index

                readonly property var keys: (modelData.shortcut || "").split(" + ")

                width: ListView.view.width
                height: 44

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 1
                    visible: bindingRow.index > 0
                    color: page.muted
                    opacity: 0.12
                }

                Text {
                    anchors.left: parent.left
                    anchors.right: keycaps.left
                    anchors.rightMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    text: bindingRow.modelData.action
                    textFormat: Text.PlainText
                    color: page.foreground
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Row {
                    id: keycaps

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Repeater {
                        model: bindingRow.keys

                        Rectangle {
                            id: keycap

                            required property string modelData

                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(24, keyLabel.implicitWidth + 14)
                            height: 24
                            radius: 6
                            color: Qt.rgba(1, 1, 1, 0.06)
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1

                            Text {
                                id: keyLabel

                                anchors.centerIn: parent
                                text: keycap.modelData
                                textFormat: Text.PlainText
                                color: page.foreground
                                font.family: "monospace"
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            width: parent.width - 48
            visible: !page.controller.loading && page.filteredBindings.length === 0
            text: page.query.trim() === "" ? "No shortcuts reported by Hyprland." : "No matching shortcuts."
            color: page.muted
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }
}

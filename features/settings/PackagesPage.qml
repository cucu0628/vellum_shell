pragma ComponentBehavior: Bound

import QtQuick
import "../../ui" as SharedUi

// A menu "Install" es "Remove" almenui. Ezek interaktiv TUI-k, ezert tovabbra
// is a `floating-terminal` inditja oket -- egy csomagkezelo urlap ujrairasa nem
// tartozik a settings app dolgahoz.
Flickable {
    id: page

    required property var controller
    property var theme: null

    readonly property string scriptsPath: "~/.config/quickshell/vellum_shell/scripts"

    readonly property var installers: [{
        "label": "Pacman package",
        "description": "Search and install from the official repositories.",
        "script": "pkg-install",
        "action": "Install"
    }, {
        "label": "AUR package",
        "description": "Search and install from the Arch User Repository.",
        "script": "aur-install",
        "action": "Install"
    }, {
        "label": "Web app",
        "description": "Wrap a website as a desktop application.",
        "script": "webapp-install",
        "action": "Install"
    }, {
        "label": "Terminal app",
        "description": "Install a curated terminal tool.",
        "script": "tui-install",
        "action": "Install"
    }]

    readonly property var removers: [{
        "label": "Package",
        "description": "Remove an installed package, from the repositories or the AUR.",
        "script": "pkg-remove",
        "action": "Remove"
    }, {
        "label": "Web app",
        "description": "Remove a web app wrapper.",
        "script": "webapp-remove",
        "action": "Remove"
    }, {
        "label": "Terminal app",
        "description": "Remove a terminal tool.",
        "script": "tui-remove",
        "action": "Remove"
    }]

    function launch(script) {
        controller.run(scriptsPath + "/floating-terminal " + scriptsPath + "/" + script);
    }

    contentWidth: width
    contentHeight: column.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: column

        width: page.width
        spacing: 0

        SettingsSection {
            width: parent.width
            theme: page.theme
            title: "Install"
        }

        Repeater {
            model: page.installers

            SharedUi.SettingRow {
                id: installRow

                required property var modelData

                theme: page.theme
                label: installRow.modelData.label
                description: installRow.modelData.description

                ActionButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    theme: page.theme
                    label: installRow.modelData.action
                    onClicked: page.launch(installRow.modelData.script)
                }

            }

        }

        SettingsSection {
            width: parent.width
            theme: page.theme
            title: "Remove"
        }

        Repeater {
            model: page.removers

            SharedUi.SettingRow {
                id: removeRow

                required property var modelData

                theme: page.theme
                label: removeRow.modelData.label
                description: removeRow.modelData.description

                ActionButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    theme: page.theme
                    label: removeRow.modelData.action
                    onClicked: page.launch(removeRow.modelData.script)
                }

            }

        }

    }

}

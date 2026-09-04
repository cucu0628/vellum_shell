pragma ComponentBehavior: Bound

import QtQuick
import "../../ui" as SharedUi

// A megszunt menu "Setup" almenuje urlappa alakitva. A billentyukombinaciok
// kulon, keresheto oldalon vannak.
Flickable {
    id: page

    required property var controller
    required property var systemController
    property var theme: null

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"

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
            title: "Shell services"
            description: "Location, power and lock-screen behaviour"
        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Weather location"
            description: "City used by the weather card. Press Enter to save."

            TextSetting {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                theme: page.theme
                placeholder: "Budapest"
                value: page.systemController.weatherLocation
                onCommitted: (value) => page.systemController.setWeatherLocation(value)
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            enabled: page.systemController.powerProfilesAvailable
            label: "Power profile"
            description: page.systemController.powerProfilesAvailable ? "Balances performance against battery life." : "power-profiles-daemon is not installed."
            showDescription: !page.systemController.powerProfilesAvailable

            SharedUi.SettingSelect {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                theme: page.theme
                model: page.systemController.powerProfiles
                value: page.systemController.powerProfile
                onActivated: (value) => page.systemController.setPowerProfile(value)
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            enabled: page.systemController.lockscreenMonitors.length > 1
            label: "Lock screen input display"
            description: "Which display shows the password prompt. Only matters with more than one display."

            SharedUi.SettingSelect {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                theme: page.theme
                model: page.systemController.lockscreenMonitors
                value: page.systemController.lockscreenMonitor
                onActivated: (value) => page.systemController.setLockscreenMonitor(value)
            }

        }

        SettingsSection {
            width: parent.width
            theme: page.theme
            title: "System diagnostics"
            description: "A current snapshot of the session and Vellum backend"
        }

        Item {
            width: parent.width
            height: 36

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: page.systemController.diagnosticsLoading ? "Collecting diagnostics..." : page.systemController.diagnosticsMessage
                color: page.systemController.diagnosticsMessage.indexOf("could not") >= 0 ? page.accent : page.muted
                font.pixelSize: 10
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                SharedUi.ActionButton {
                    enabled: page.systemController.clipboardAvailable
                    height: 26
                    theme: page.theme
                    label: "Copy report"
                    onClicked: page.systemController.copyDiagnostics()
                }

                SharedUi.ActionButton {
                    height: 26
                    theme: page.theme
                    label: "Refresh"
                    onClicked: page.systemController.reloadDiagnostics()
                }
            }
        }

        Repeater {
            model: page.systemController.diagnosticFacts

            SharedUi.SettingRow {
                id: factRow

                required property var modelData

                theme: page.theme
                label: modelData.label

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    text: factRow.modelData.value
                    color: factRow.modelData.label === "Failed user services" && factRow.modelData.value !== "None" ? page.accent : page.foreground
                    font.family: "monospace"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                }
            }
        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Vellum backend"
            description: page.systemController.backendSummary

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 82
                height: 24
                color: "transparent"
                border.color: page.systemController.backendHealthy ? page.accent : page.muted
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: page.systemController.backendHealthy ? "healthy" : "offline"
                    color: page.systemController.backendHealthy ? page.accent : page.muted
                    font.pixelSize: 9
                    font.bold: true
                }
            }
        }

        Repeater {
            model: page.systemController.backendModules

            SharedUi.SettingRow {
                id: moduleRow

                required property var modelData

                theme: page.theme
                label: "Backend module · " + modelData.name
                description: modelData.error
                showDescription: modelData.error !== ""

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: moduleRow.modelData.state
                    color: moduleRow.modelData.state === "restarting" ? page.accent : page.muted
                    font.family: "monospace"
                    font.pixelSize: 10
                }
            }
        }

        SettingsSection {
            width: parent.width
            theme: page.theme
            title: "External tools"
            description: "Open specialised configuration outside Vellum"
        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Network connections"
            description: "Opens nm-connection-editor for VPN and enterprise Wi-Fi setup."

            SharedUi.ActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                theme: page.theme
                label: "Open editor"
                onClicked: page.controller.run("nm-connection-editor")
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Hyprland configuration"
            description: "Opens ~/.config/hypr. Vellum only writes its own generated modules there."

            SharedUi.ActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                theme: page.theme
                label: "Open folder"
                onClicked: page.controller.run("xdg-open ~/.config/hypr")
            }

        }

        SettingsSection {
            width: parent.width
            theme: page.theme
            title: "Maintenance"
            description: "Remove settings generated by this application"
        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Reset Hyprland settings"
            description: "Discards everything this app wrote and falls back to your own config."
            showDescription: true

            SharedUi.ActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                theme: page.theme
                label: "Reset"
                onClicked: page.controller.resetScope("all")
            }

        }

    }

}

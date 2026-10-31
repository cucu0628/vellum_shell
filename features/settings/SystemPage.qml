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

    property bool confirmingReset: false

    contentWidth: width
    contentHeight: column.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Timer {
        id: resetDisarm

        interval: 4000
        onTriggered: page.confirmingReset = false
    }

    Column {
        id: column

        width: page.width
        spacing: 24

        SettingsSection {
            width: parent.width
            theme: page.theme
            title: "Shell services"
            description: "Location, power and lock-screen behaviour"

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
                description: page.systemController.powerProfilesAvailable ? "Balances performance against battery life." : "No compatible power-profile service is available."

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

            SharedUi.SettingRow {
                theme: page.theme
                label: "Lock after inactivity"
                description: "Locks the screen when the session has been idle this long. Fullscreen video keeps it awake."

                SharedUi.SettingSelect {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    theme: page.theme
                    model: [{
                        "label": "Never",
                        "value": "0"
                    }, {
                        "label": "1 minute",
                        "value": "1"
                    }, {
                        "label": "5 minutes",
                        "value": "5"
                    }, {
                        "label": "10 minutes",
                        "value": "10"
                    }, {
                        "label": "15 minutes",
                        "value": "15"
                    }, {
                        "label": "30 minutes",
                        "value": "30"
                    }]
                    value: page.systemController.lockIdleMinutes
                    onActivated: (value) => page.systemController.setLockIdleMinutes(value)
                }

            }
        }

        SettingsSection {
            width: parent.width
            theme: page.theme
            title: "System diagnostics"
            description: page.systemController.diagnosticsLoading
                ? "Collecting diagnostics…"
                : (page.systemController.diagnosticsMessage !== ""
                    ? page.systemController.diagnosticsMessage
                    : "A current snapshot of the session and Vellum backend")
            actions: [
                SharedUi.ActionButton {
                    enabled: page.systemController.clipboardAvailable
                    theme: page.theme
                    label: "Copy report"
                    onClicked: page.systemController.copyDiagnostics()
                },
                SharedUi.ActionButton {
                    enabled: !page.systemController.diagnosticsLoading
                    theme: page.theme
                    label: "Refresh"
                    onClicked: page.systemController.reloadDiagnostics()
                }
            ]

            Repeater {
                model: page.systemController.diagnosticFacts

                SharedUi.SettingRow {
                    id: factRow

                    required property var modelData

                    theme: page.theme
                    label: modelData.label
                    minimumHeight: 44
                    controlWidth: 320

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        text: factRow.modelData.value
                        textFormat: Text.PlainText
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

                StatusBadge {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    theme: page.theme
                    active: page.systemController.backendHealthy
                    text: page.systemController.backendHealthy ? "Healthy" : "Offline"
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
                    minimumHeight: modelData.error !== "" ? 60 : 44

                    StatusBadge {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        theme: page.theme
                        active: moduleRow.modelData.state === "restarting"
                        text: moduleRow.modelData.state
                    }
                }
            }
        }

        SettingsSection {
            width: parent.width
            theme: page.theme
            title: "External tools"
            description: "Open specialised configuration outside Vellum"

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
        }

        SettingsSection {
            width: parent.width
            theme: page.theme
            title: "Maintenance"
            description: "Remove settings generated by this application"

            SharedUi.SettingRow {
                theme: page.theme
                label: "Reset Hyprland settings"
                description: page.confirmingReset
                    ? "Press again to discard everything this app wrote to Hyprland."
                    : "Discards everything this app wrote and falls back to your own config."

                // Ket lepcsos: az elso kattintas csak elesiti, a masodik torol.
                // Par masodperc utan magatol visszaall.
                SharedUi.ActionButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    theme: page.theme
                    label: page.confirmingReset ? "Confirm reset" : "Reset"
                    destructive: true
                    onClicked: {
                        if (!page.confirmingReset) {
                            page.confirmingReset = true;
                            resetDisarm.restart();
                            return;
                        }
                        page.confirmingReset = false;
                        resetDisarm.stop();
                        page.controller.resetScope("all");
                    }
                }

            }
        }
    }

}

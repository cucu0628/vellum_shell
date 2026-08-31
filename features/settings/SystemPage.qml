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
            title: "Desktop"
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
            label: "Network connections"
            description: "Opens nm-connection-editor for VPN and enterprise Wi-Fi setup."

            ActionButton {
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

            ActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                theme: page.theme
                label: "Open folder"
                onClicked: page.controller.run("xdg-open ~/.config/hypr")
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Reset Hyprland settings"
            description: "Discards everything this app wrote and falls back to your own config."

            ActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                theme: page.theme
                label: "Reset"
                onClicked: page.controller.resetScope("all")
            }

        }

    }

}

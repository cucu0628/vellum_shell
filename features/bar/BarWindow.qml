pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var targetScreen
    required property var theme
    required property int barHeight
    required property var visibleWorkspaceIds
    required property var occupiedWorkspaceIds
    required property var layoutController
    property var activePlayer: null
    property bool hasMediaSource: false
    property var cavaValues: [0, 0, 0, 0, 0, 0]
    property bool settingsOpen: false
    property bool centerPopupOpen: false
    property bool audioPopupOpen: false
    property int audioVolumePercent: 0
    property bool vpnActive: false
    property string vpnName: ""
    property string networkType: "offline"
    property bool connectivityPopupOpen: false
    property bool bluetoothAvailable: false
    property bool bluetoothEnabled: false
    property bool bluetoothConnected: false
    property bool bluetoothPopupOpen: false
    property bool batteryAvailable: false
    property int batteryPercentage: 0
    property bool batteryCharging: false
    property bool notificationsDnd: false
    property bool notificationsHasToast: false
    property int notificationsUnreadCount: 0
    property bool notificationsMenuOpened: false
    property bool aiPopupOpen: false
    property bool trayMenuOpen: false
    property bool micActive: false
    property bool cameraActive: false
    property bool privacyPopupOpen: false
    property int removableDeviceCount: 0
    property int mountedRemovableCount: 0
    property bool removablePopupOpen: false

    signal settingsToggleRequested()
    signal centerToggleRequested()
    signal audioToggleRequested()
    signal privacyToggleRequested()
    signal connectivityToggleRequested()
    signal connectivityVpnRequested()
    signal bluetoothToggleRequested()
    signal notificationsToggleRequested()
    signal aiToggleRequested()
    signal removableToggleRequested()
    signal launchCommand(var command)
    signal audioVolumeStepRequested(bool increase)
    signal trayMenuRequested(var model, real globalX)

    screen: targetScreen
    anchors { top: true; left: true; right: true }
    implicitHeight: barHeight
    color: theme.background
    WlrLayershell.exclusiveZone: barHeight

    Item {
        anchors.fill: parent

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: root.theme.accent
            opacity: 0.55
        }

        Row {
            id: leftZone

            anchors.left: parent.left
            height: parent.height
            spacing: 10

            Repeater {
                model: root.layoutController.leftModules

                Loader {
                    required property string modelData

                    height: leftZone.height
                    sourceComponent: root.componentFor(modelData)
                }
            }
        }

        Row {
            id: centerZone

            anchors.centerIn: parent
            height: parent.height
            spacing: 10

            Repeater {
                model: root.layoutController.centerModules

                Loader {
                    required property string modelData

                    height: centerZone.height
                    sourceComponent: root.componentFor(modelData)
                }
            }
        }

        Row {
            id: rightZone

            anchors.right: parent.right
            anchors.rightMargin: 10
            height: parent.height
            spacing: 10

            Repeater {
                model: root.layoutController.rightModules

                Loader {
                    required property string modelData

                    height: rightZone.height
                    sourceComponent: root.componentFor(modelData)
                }
            }
        }
    }

    function componentFor(moduleId) {
        switch (moduleId) {
        case "workspaces": return workspacesComponent;
        case "privacy": return privacyComponent;
        case "clock": return clockComponent;
        case "tray": return trayComponent;
        case "connectivity": return connectivityComponent;
        case "bluetooth": return bluetoothComponent;
        case "removable": return removableComponent;
        case "audio": return audioComponent;
        case "notifications": return notificationsComponent;
        case "ai": return aiComponent;
        case "system-monitor": return systemMonitorComponent;
        case "battery": return batteryComponent;
        default: return null;
        }
    }

    Component {
        id: workspacesComponent

        WorkspaceGroup {
            theme: root.theme
            visibleWorkspaceIds: root.visibleWorkspaceIds
            occupiedWorkspaceIds: root.occupiedWorkspaceIds
            settingsOpen: root.settingsOpen
            onSettingsClicked: root.settingsToggleRequested()
        }
    }

    Component {
        id: privacyComponent

        PrivacyStatusItem {
            theme: root.theme
            barHeight: root.barHeight
            micActive: root.micActive
            cameraActive: root.cameraActive
            popupOpen: root.privacyPopupOpen
            onClicked: root.privacyToggleRequested()
        }
    }

    Component {
        id: clockComponent

        CenterClock {
            theme: root.theme
            activePlayer: root.activePlayer
            hasMediaSource: root.hasMediaSource
            cavaValues: root.cavaValues
            popupOpen: root.centerPopupOpen
            onClicked: root.centerToggleRequested()
        }
    }

    Component {
        id: trayComponent

        TrayGroup {
            theme: root.theme
            contextMenuOpen: root.trayMenuOpen
            onContextMenuRequested: (model, globalX) => root.trayMenuRequested(model, globalX)
        }
    }

    Component {
        id: connectivityComponent

        ConnectivityStatusItem {
            theme: root.theme
            barHeight: root.barHeight
            connectionType: root.networkType
            vpnActive: root.vpnActive
            vpnName: root.vpnName
            popupOpen: root.connectivityPopupOpen
            onClicked: root.connectivityToggleRequested()
            onVpnRequested: root.connectivityVpnRequested()
        }
    }

    Component {
        id: bluetoothComponent

        BluetoothStatusItem {
            theme: root.theme
            available: root.bluetoothAvailable
            adapterEnabled: root.bluetoothEnabled
            connected: root.bluetoothConnected
            popupOpen: root.bluetoothPopupOpen
            onClicked: root.bluetoothToggleRequested()
        }
    }

    Component {
        id: removableComponent

        RemovableDeviceStatusItem {
            theme: root.theme
            deviceCount: root.removableDeviceCount
            mountedCount: root.mountedRemovableCount
            popupOpen: root.removablePopupOpen
            onClicked: root.removableToggleRequested()
        }
    }

    Component {
        id: audioComponent

        AudioStatusItem {
            theme: root.theme
            barHeight: root.barHeight
            popupOpen: root.audioPopupOpen
            volumePercent: root.audioVolumePercent
            onClicked: root.audioToggleRequested()
            onVolumeStepRequested: increase => root.audioVolumeStepRequested(increase)
        }
    }

    Component {
        id: notificationsComponent

        NotificationStatusItem {
            theme: root.theme
            dnd: root.notificationsDnd
            hasToast: root.notificationsHasToast
            unreadCount: root.notificationsUnreadCount
            menuOpened: root.notificationsMenuOpened
            onClicked: root.notificationsToggleRequested()
        }
    }

    Component {
        id: aiComponent

        AiStatusItem {
            theme: root.theme
            popupOpen: root.aiPopupOpen
            onClicked: root.aiToggleRequested()
        }
    }

    Component {
        id: systemMonitorComponent

        BtopStatusItem {
            theme: root.theme
            onClicked: root.launchCommand(["sh", "-c", "exec \"$HOME/.config/quickshell/vellum_shell/scripts/floating-terminal\" btop"])
        }
    }

    Component {
        id: batteryComponent

        BatteryStatusItem {
            theme: root.theme
            available: root.batteryAvailable
            percentage: root.batteryPercentage
            charging: root.batteryCharging
        }
    }

}

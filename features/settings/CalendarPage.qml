pragma ComponentBehavior: Bound

import QtQuick
import "../../core" as Core
import "../../ui" as SharedUi

// Google Naptar bekotese. A bejelentkezes a bongeszoben tortenik, a tokent a
// daemon tarolja; ez az oldal csak a gombokat es az allapotot mutatja.
Flickable {
    id: page

    required property var backend
    property var theme: null

    // A Google minden asztali alkalmazastol sajat OAuth klienst ker. Ezt
    // egyszer kell megadni; utana a bejelentkezes egyetlen gomb.
    property bool editingClient: false
    property string clientId: ""
    property string clientSecret: ""

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property bool showClientForm: calendar.available && (!calendar.configured || editingClient)
    readonly property string problem: calendar.callError !== "" ? calendar.callError : calendar.error
    readonly property string statusText: {
        if (!calendar.available) return "The Vellum daemon is not reachable, so the calendar cannot be connected."
        if (problem !== "") return problem
        if (calendar.authorizing) return "Approve access in the browser window that just opened."
        if (calendar.syncing) return "Syncing with Google Calendar..."
        if (calendar.connected && calendar.updatedAt > 0)
            return "Last synced at " + Qt.formatTime(new Date(calendar.updatedAt), "HH:mm") + "."
        if (!calendar.configured) return "Google needs a one-time OAuth client before you can sign in."
        return ""
    }

    function saveClient() {
        clientIdField.commit()
        clientSecretField.commit()
        calendar.setClient(clientId.trim(), clientSecret.trim(), function(ok) {
            if (!ok) return
            page.editingClient = false
            page.clientId = ""
            page.clientSecret = ""
            clientIdField.clear()
            clientSecretField.clear()
        })
    }

    contentWidth: width
    contentHeight: column.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Core.CalendarController {
        id: calendar

        backend: page.backend
        active: true
    }

    Column {
        id: column

        width: page.width
        spacing: 0

        SettingsSection {
            width: parent.width
            theme: page.theme
            title: "Google Calendar"
            description: "Show your events in the calendar panel. Access is read-only."
            showDescription: true
        }

        Item {
            width: parent.width
            height: page.statusText !== "" ? statusLabel.implicitHeight + 16 : 0
            visible: page.statusText !== ""

            Text {
                id: statusLabel

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: page.statusText
                textFormat: Text.PlainText
                color: page.problem !== "" || !calendar.available ? page.accent : page.muted
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }

        SharedUi.SettingRow {
            visible: calendar.available && calendar.configured && !page.editingClient
            theme: page.theme
            label: "Google account"
            description: calendar.connected ? (calendar.account !== "" ? calendar.account : "Signed in") : "Not signed in"
            showDescription: true
            controlWidth: 320

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                SharedUi.ActionButton {
                    visible: calendar.authorizing
                    theme: page.theme
                    label: "Open again"
                    onClicked: calendar.reopenLogin()
                }

                SharedUi.ActionButton {
                    visible: calendar.authorizing
                    theme: page.theme
                    label: "Cancel"
                    onClicked: calendar.cancelLogin()
                }

                SharedUi.ActionButton {
                    visible: calendar.connected && !calendar.authorizing
                    enabled: !calendar.syncing
                    theme: page.theme
                    label: calendar.locked ? "Unlock" : "Sync now"
                    primary: calendar.locked
                    onClicked: calendar.refresh()
                }

                SharedUi.ActionButton {
                    visible: calendar.connected && !calendar.authorizing
                    theme: page.theme
                    label: "Sign out"
                    onClicked: calendar.logout()
                }

                SharedUi.ActionButton {
                    visible: !calendar.connected && !calendar.authorizing
                    theme: page.theme
                    label: "Sign in with Google"
                    primary: true
                    onClicked: calendar.login()
                }
            }
        }

        SharedUi.SettingRow {
            visible: calendar.available && calendar.configured && !calendar.connected
                && !calendar.authorizing && !page.editingClient
            theme: page.theme
            label: "OAuth client"
            description: "Replace the Google Cloud client used for sign-in"

            SharedUi.ActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                theme: page.theme
                label: "Change"
                onClicked: page.editingClient = true
            }
        }

        // -- naptarak ---------------------------------------------------------
        SettingsSection {
            width: parent.width
            visible: calendar.connected && calendar.calendars.length > 0
            theme: page.theme
            title: "Calendars"
            description: "Choose which calendars appear in the panel"
            showDescription: true
        }

        Repeater {
            model: calendar.connected ? calendar.calendars : []

            SharedUi.SettingRow {
                id: calendarRow

                required property var modelData

                theme: page.theme
                label: modelData.name
                description: modelData.primary ? "Primary calendar" : ""
                showDescription: modelData.primary
                controlWidth: 80

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12
                        height: 12
                        radius: 6
                        color: calendarRow.modelData.color || page.accent
                    }

                    SharedUi.SettingToggle {
                        theme: page.theme
                        accessibleName: calendarRow.modelData.name
                        checked: calendarRow.modelData.enabled
                        onToggled: (value) => calendar.setCalendar(calendarRow.modelData.id, value)
                    }
                }
            }
        }

        // -- OAuth kliens (egyszeri beallitas) ------------------------------
        SettingsSection {
            width: parent.width
            visible: page.showClientForm
            theme: page.theme
            title: "OAuth client"
            description: "One-time setup in Google Cloud Console"
            showDescription: true
        }

        Text {
            width: parent.width
            visible: page.showClientForm
            bottomPadding: 12
            text: "1. Create a project and enable the Google Calendar API.\n"
                + "2. In Google Auth Platform, fill in Branding, then under Audience publish the app "
                + "(In production) so the sign-in does not expire after 7 days.\n"
                + "3. Under Clients, create a client of type Desktop app and paste its ID and secret below."
            textFormat: Text.PlainText
            color: page.muted
            font.pixelSize: 11
            lineHeight: 1.25
            wrapMode: Text.WordWrap
        }

        SharedUi.SettingRow {
            visible: page.showClientForm
            theme: page.theme
            label: "Client ID"
            controlWidth: Math.min(420, parent.width * 0.6)

            TextSetting {
                id: clientIdField

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                theme: page.theme
                placeholder: "1234-abc.apps.googleusercontent.com"
                onCommitted: (value) => page.clientId = value
            }
        }

        SharedUi.SettingRow {
            visible: page.showClientForm
            theme: page.theme
            label: "Client secret"
            controlWidth: Math.min(420, parent.width * 0.6)

            TextSetting {
                id: clientSecretField

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                theme: page.theme
                placeholder: "GOCSPX-..."
                onCommitted: (value) => page.clientSecret = value
            }
        }

        Item {
            width: parent.width
            height: 52
            visible: page.showClientForm

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                SharedUi.ActionButton {
                    theme: page.theme
                    label: "Open Cloud Console"
                    onClicked: Qt.openUrlExternally("https://console.cloud.google.com/auth/clients")
                }

                SharedUi.ActionButton {
                    visible: page.editingClient
                    theme: page.theme
                    label: "Cancel"
                    onClicked: page.editingClient = false
                }

                SharedUi.ActionButton {
                    theme: page.theme
                    label: "Save"
                    primary: true
                    onClicked: page.saveClient()
                }
            }
        }
    }
}

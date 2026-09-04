pragma ComponentBehavior: Bound

import QtQuick
import "../../ui" as SharedUi

Flickable {
    id: page

    required property var controller
    property var theme: null

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
            title: "Default applications"
            description: "Choose which installed app opens each kind of content"
        }

        Item {
            width: parent.width
            height: 34

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: page.controller.loading ? "Reading MIME associations..." : page.controller.message
                color: page.controller.message.indexOf("could not") >= 0 || page.controller.message.indexOf("not installed") >= 0 ? page.accent : page.muted
                font.pixelSize: 10
            }

            SharedUi.ActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 26
                theme: page.theme
                label: "Refresh"
                onClicked: page.controller.reload()
            }
        }

        Repeater {
            model: page.controller.categories

            SharedUi.SettingRow {
                id: categoryRow

                required property var modelData
                required property int index

                theme: page.theme
                enabled: page.controller.available && page.controller.busyCategory === ""
                label: modelData.label
                description: modelData.description

                SharedUi.SettingSelect {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    theme: page.theme
                    model: page.controller.applicationsFor(page.controller.valueFor(categoryRow.modelData.id))
                    value: page.controller.valueFor(categoryRow.modelData.id)
                    placeholder: "No default"
                    maxVisibleRows: 9
                    searchable: true
                    dropUp: categoryRow.index >= 4
                    onActivated: (value) => page.controller.setDefault(categoryRow.modelData, value)
                }
            }
        }
    }
}

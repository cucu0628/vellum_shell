pragma ComponentBehavior: Bound

import QtQuick
import "../../ui" as SharedUi

Flickable {
    id: page

    required property var controller
    property var theme: null

    contentWidth: width
    contentHeight: column.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: column

        width: page.width
        spacing: 24

        // Az oldal cime a fejlecben all; a szakasz csak az allapotot es a
        // frissitest viszi, a sorok egy kartyaban vannak.
        SettingsSection {
            theme: page.theme
            title: "File and link types"
            description: page.controller.loading
                ? "Reading MIME associations…"
                : (page.controller.message !== "" ? page.controller.message : "Search inside a list to find an installed application.")
            actions: [
                SharedUi.ActionButton {
                    theme: page.theme
                    label: "Refresh"
                    enabled: !page.controller.loading
                    onClicked: page.controller.reload()
                }
            ]

            Repeater {
                model: page.controller.categories

                SharedUi.SettingRow {
                    id: categoryRow

                    required property var modelData
                    required property int index

                    theme: page.theme
                    enabled: page.controller.canChange(categoryRow.modelData)
                    label: modelData.label
                    description: page.controller.descriptionFor(categoryRow.modelData)

                    SharedUi.SettingSelect {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        theme: page.theme
                        model: page.controller.applicationsFor(categoryRow.modelData)
                        value: page.controller.valueFor(categoryRow.modelData.id)
                        placeholder: "No default"
                        maxVisibleRows: 9
                        searchable: true
                        searchPlaceholder: "Search applications..."
                        emptyText: "No matching applications."
                        onActivated: (value) => page.controller.setDefault(categoryRow.modelData, value)
                    }
                }
            }
        }
    }
}

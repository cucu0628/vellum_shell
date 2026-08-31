import QtQuick
import "../../ui" as SharedUi

// Tiling es dekoracio. Minden sor egy `general:` vagy `decoration:` kulcsot
// allit; a kulcsneveket a backend `hypr` modulja zart listaban ismeri.
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
        spacing: 0

        SettingsSection {
            width: parent.width
            theme: page.theme
            title: "Layout"
        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Inner gaps"
            description: "Space between tiled windows."

            SharedUi.SettingSlider {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                theme: page.theme
                from: 0
                to: 40
                stepSize: 1
                value: page.controller.optionNumber("general:gaps_in", 5)
                onMoved: (value) => page.controller.previewOption("general:gaps_in", value)
                onCommitted: (value) => page.controller.setOption("general:gaps_in", value)
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Outer gaps"
            description: "Space between windows and the screen edge."

            SharedUi.SettingSlider {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                theme: page.theme
                from: 0
                to: 60
                stepSize: 1
                value: page.controller.optionNumber("general:gaps_out", 10)
                onMoved: (value) => page.controller.previewOption("general:gaps_out", value)
                onCommitted: (value) => page.controller.setOption("general:gaps_out", value)
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Border width"
            description: "Thickness of the window border."

            SharedUi.SettingSlider {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                theme: page.theme
                from: 0
                to: 10
                stepSize: 1
                value: page.controller.optionNumber("general:border_size", 2)
                onMoved: (value) => page.controller.previewOption("general:border_size", value)
                onCommitted: (value) => page.controller.setOption("general:border_size", value)
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Tiling layout"
            description: "Dwindle splits the focused window; master keeps one primary area."

            SharedUi.SettingSelect {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                theme: page.theme
                model: [{
                    "label": "Dwindle",
                    "value": "dwindle"
                }, {
                    "label": "Master",
                    "value": "master"
                }]
                value: page.controller.optionText("general:layout", "dwindle")
                onActivated: (value) => page.controller.setOption("general:layout", value)
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Resize on border"
            description: "Drag a window border to resize it."

            SharedUi.SettingToggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                theme: page.theme
                checked: page.controller.optionBool("general:resize_on_border", false)
                onToggled: (value) => page.controller.setOption("general:resize_on_border", value)
            }

        }

        SettingsSection {
            width: parent.width
            theme: page.theme
            title: "Decoration"
        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Corner rounding"
            description: "Radius of the window corners, in pixels."

            SharedUi.SettingSlider {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                theme: page.theme
                from: 0
                to: 24
                stepSize: 1
                value: page.controller.optionNumber("decoration:rounding", 0)
                onMoved: (value) => page.controller.previewOption("decoration:rounding", value)
                onCommitted: (value) => page.controller.setOption("decoration:rounding", value)
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Active opacity"
            description: "Transparency of the focused window."

            SharedUi.SettingSlider {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                theme: page.theme
                from: 0.4
                to: 1
                stepSize: 0.05
                value: page.controller.optionNumber("decoration:active_opacity", 1)
                onMoved: (value) => page.controller.previewOption("decoration:active_opacity", value)
                onCommitted: (value) => page.controller.setOption("decoration:active_opacity", value)
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Inactive opacity"
            description: "Transparency of windows that do not have focus."

            SharedUi.SettingSlider {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                theme: page.theme
                from: 0.4
                to: 1
                stepSize: 0.05
                value: page.controller.optionNumber("decoration:inactive_opacity", 1)
                onMoved: (value) => page.controller.previewOption("decoration:inactive_opacity", value)
                onCommitted: (value) => page.controller.setOption("decoration:inactive_opacity", value)
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Blur"
            description: "Blur what is behind translucent surfaces. Costs GPU time."

            SharedUi.SettingToggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                theme: page.theme
                checked: page.controller.optionBool("decoration:blur:enabled", false)
                onToggled: (value) => page.controller.setOption("decoration:blur:enabled", value)
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            enabled: page.controller.optionBool("decoration:blur:enabled", false)
            label: "Blur strength"
            description: "Larger values blur more but cost more."

            SharedUi.SettingSlider {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                theme: page.theme
                from: 1
                to: 20
                stepSize: 1
                value: page.controller.optionNumber("decoration:blur:size", 3)
                onMoved: (value) => page.controller.previewOption("decoration:blur:size", value)
                onCommitted: (value) => page.controller.setOption("decoration:blur:size", value)
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            enabled: page.controller.optionBool("decoration:blur:enabled", false)
            label: "Blur passes"
            description: "Extra passes smooth the blur but increase GPU cost."

            SharedUi.SettingSlider {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                theme: page.theme
                from: 1
                to: 10
                stepSize: 1
                value: page.controller.optionNumber("decoration:blur:passes", 1)
                onMoved: (value) => page.controller.previewOption("decoration:blur:passes", value)
                onCommitted: (value) => page.controller.setOption("decoration:blur:passes", value)
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Shadow"
            description: "Drop a shadow behind windows."

            SharedUi.SettingToggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                theme: page.theme
                checked: page.controller.optionBool("decoration:shadow:enabled", false)
                onToggled: (value) => page.controller.setOption("decoration:shadow:enabled", value)
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Animations"
            description: "Window, workspace and layer transitions."

            SharedUi.SettingToggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                theme: page.theme
                checked: page.controller.optionBool("animations:enabled", true)
                onToggled: (value) => page.controller.setOption("animations:enabled", value)
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            enabled: page.controller.optionBool("decoration:shadow:enabled", false)
            label: "Shadow range"
            description: "How far the window shadow extends."

            SharedUi.SettingSlider {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                theme: page.theme
                from: 0
                to: 50
                stepSize: 1
                value: page.controller.optionNumber("decoration:shadow:range", 4)
                onMoved: (value) => page.controller.previewOption("decoration:shadow:range", value)
                onCommitted: (value) => page.controller.setOption("decoration:shadow:range", value)
            }

        }

    }

}

import QtQuick
import "../../ui" as SharedUi

// Billentyuzet, eger es touchpad. A kiosztaslista szandekosan rovid: a teljes
// xkb keszlet szaz feletti, es a settings app nem akar xkb bongeszo lenni --
// aki mast akar, az `input.lua`-ban allitja.
Flickable {
    id: page

    required property var controller
    property var theme: null

    readonly property var layouts: [{
        "label": "Hungarian (hu)",
        "value": "hu"
    }, {
        "label": "English US (us)",
        "value": "us"
    }, {
        "label": "English UK (gb)",
        "value": "gb"
    }, {
        "label": "German (de)",
        "value": "de"
    }, {
        "label": "French (fr)",
        "value": "fr"
    }, {
        "label": "Spanish (es)",
        "value": "es"
    }]

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
            title: "Keyboard"
            description: "Layout and held-key response"
        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Layout"
            description: "The xkb layout Hyprland loads at startup."

            SharedUi.SettingSelect {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                theme: page.theme
                model: page.layouts
                value: page.controller.optionText("input:kb_layout", "us")
                onActivated: (value) => page.controller.setOption("input:kb_layout", value)
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Layout variant"
            description: "Optional xkb variant, such as nodeadkeys. Leave empty for the default."
            showDescription: true

            TextSetting {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                theme: page.theme
                value: page.controller.optionText("input:kb_variant", "")
                placeholder: "default"
                onCommitted: (value) => page.controller.setOption("input:kb_variant", value.trim())
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Repeat rate"
            description: "Repeats per second while a key is held."

            SharedUi.SettingSlider {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                theme: page.theme
                from: 10
                to: 60
                stepSize: 1
                value: page.controller.optionNumber("input:repeat_rate", 25)
                onMoved: (value) => page.controller.previewOption("input:repeat_rate", value)
                onCommitted: (value) => page.controller.setOption("input:repeat_rate", value)
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Repeat delay"
            description: "Milliseconds before a held key starts repeating."

            SharedUi.SettingSlider {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                theme: page.theme
                from: 150
                to: 1000
                stepSize: 25
                suffix: " ms"
                value: page.controller.optionNumber("input:repeat_delay", 600)
                onMoved: (value) => page.controller.previewOption("input:repeat_delay", value)
                onCommitted: (value) => page.controller.setOption("input:repeat_delay", value)
            }

        }

        SettingsSection {
            width: parent.width
            theme: page.theme
            title: "Pointer"
            description: "Mouse speed and focus policy"
        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Mouse sensitivity"
            description: "Negative slows the pointer down, positive speeds it up."

            SharedUi.SettingSlider {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                theme: page.theme
                from: -1
                to: 1
                stepSize: 0.05
                value: page.controller.optionNumber("input:sensitivity", 0)
                onMoved: (value) => page.controller.previewOption("input:sensitivity", value)
                onCommitted: (value) => page.controller.setOption("input:sensitivity", value)
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Focus follows mouse"
            description: "Off focuses on click only; loose keeps focus until another window is entered."
            showDescription: true

            SharedUi.SettingSelect {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                theme: page.theme
                model: [{
                    "label": "Off",
                    "value": "0"
                }, {
                    "label": "Always",
                    "value": "1"
                }, {
                    "label": "Loose",
                    "value": "2"
                }, {
                    "label": "Full",
                    "value": "3"
                }]
                value: page.controller.optionNumber("input:follow_mouse", 1).toString()
                onActivated: (value) => page.controller.setOption("input:follow_mouse", Number(value))
            }

        }

        SettingsSection {
            width: parent.width
            theme: page.theme
            title: "Touchpad"
            description: "Gestures used for scrolling and clicking"
        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Natural scrolling"
            description: "Move the content with your fingers instead of the viewport."

            SharedUi.SettingToggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                theme: page.theme
                checked: page.controller.optionBool("input:touchpad:natural_scroll", false)
                onToggled: (value) => page.controller.setOption("input:touchpad:natural_scroll", value)
            }

        }

        SharedUi.SettingRow {
            theme: page.theme
            label: "Tap to click"
            description: "Register a tap as a click without pressing the pad down."

            SharedUi.SettingToggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                theme: page.theme
                checked: page.controller.optionBool("input:touchpad:tap-to-click", true)
                onToggled: (value) => page.controller.setOption("input:touchpad:tap-to-click", value)
            }

        }

    }

}

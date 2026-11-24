import QtQuick
import Quickshell
import "../../ui" as SharedUi

// Az eszkozvalaszto: az eszkoz neve alatt nyilik le, es az osszes eszkozt
// mutatja -- a mostanit is, akcentes sorkent, hogy latsszon, mirol valtunk.
Item {
    id: picker

    property var controller: null
    property var devices: []
    property bool input: false
    property bool open: false

    readonly property var theme: controller ? controller.theme : null

    signal chosen()

    implicitHeight: open ? list.implicitHeight + 8 : 0
    clip: true
    visible: implicitHeight > 0 || heightAnimation.running

    Behavior on implicitHeight {
        NumberAnimation {
            id: heightAnimation
            duration: 200
            easing.type: Easing.OutQuint
        }
    }

    Column {
        id: list

        width: parent.width
        y: 4
        spacing: 2
        opacity: picker.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }

        Repeater {
            model: ScriptModel { values: picker.devices }

            SharedUi.ListRow {
                id: deviceOption

                required property var modelData
                readonly property bool current: picker.controller
                    ? (picker.input ? picker.controller.isDefaultInput(modelData) : picker.controller.isDefaultOutput(modelData))
                    : false

                width: list.width
                implicitHeight: 44
                theme: picker.theme
                active: current
                glyph: picker.controller ? picker.controller.deviceGlyph(modelData, picker.input) : ""
                title: picker.controller ? picker.controller.nodeTitle(modelData) : ""
                trailing: current ? "" : qsTr("Use")
                accessibleName: current ? qsTr("%1, in use").arg(title) : qsTr("Use %1").arg(title)
                onClicked: {
                    if (picker.controller && !current) {
                        if (picker.input) picker.controller.setDefaultInput(modelData)
                        else picker.controller.setDefaultOutput(modelData)
                    }
                    picker.chosen()
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: deviceOption.current
                    text: "󰄬"
                    color: picker.controller ? picker.controller.panelAccent : "#b7372f"
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 14
                }
            }
        }
    }
}

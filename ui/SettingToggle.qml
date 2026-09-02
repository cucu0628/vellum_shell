import QtQuick

// Ki/be kapcsolo. A shell tobbi resze nem hasznal QtQuick.Controls-t, ezert ez
// is sima Rectangle + MouseArea -- de a billentyuzetet es a kepernyoolvasot
// ugyanugy ki kell szolgalnia, mint egy rendes CheckBox-nak.
Item {
    id: toggle

    property var theme: null
    property bool checked: false
    // Amit a kepernyoolvaso mond. A SettingRow magatol atadja a sor cimket.
    property string accessibleName: ""
    property string accessibleDescription: ""

    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string surface: theme && theme.surface ? theme.surface : "#1b1613"

    signal toggled(bool value)

    function activate() {
        if (toggle.enabled) toggle.toggled(!toggle.checked)
    }

    implicitWidth: 46
    implicitHeight: 24

    activeFocusOnTab: enabled
    Keys.onSpacePressed: (event) => { toggle.activate(); event.accepted = true }
    Keys.onReturnPressed: (event) => { toggle.activate(); event.accepted = true }
    Keys.onEnterPressed: (event) => { toggle.activate(); event.accepted = true }

    Accessible.role: Accessible.CheckBox
    Accessible.name: toggle.accessibleName
    Accessible.description: toggle.accessibleDescription
    Accessible.checkable: true
    Accessible.checked: toggle.checked
    Accessible.onToggleAction: toggle.activate()
    Accessible.onPressAction: toggle.activate()

    Rectangle {
        id: track

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 46
        height: 24
        radius: 0
        color: toggle.checked ? toggle.accent : toggle.surface
        border.color: toggle.checked ? toggle.accent : toggle.muted
        border.width: 1

        Behavior on color {
            ColorAnimation {
                duration: 130
            }

        }

        Rectangle {
            width: 16
            height: 16
            radius: 0
            color: toggle.checked ? toggle.surface : toggle.muted
            anchors.verticalCenter: parent.verticalCenter
            x: toggle.checked ? parent.width - width - 4 : 4

            Behavior on x {
                NumberAnimation {
                    duration: 130
                    easing.type: Easing.OutCubic
                }

            }

        }

        FocusRing {
            theme: toggle.theme
            active: toggle.activeFocus
        }

    }

    MouseArea {
        anchors.fill: track
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.activate()
    }

}

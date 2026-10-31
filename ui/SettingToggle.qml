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

    implicitWidth: 40
    implicitHeight: 28

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

    // Ugyanaz a kerek, keret nelkuli forma, mint a lenyilo panelek csempei:
    // kikapcsolva halvany feher alap, bekapcsolva telt akcentes sin.
    Rectangle {
        id: track

        readonly property color accentColor: toggle.accent

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 22
        radius: height / 2
        color: toggle.checked
            ? track.accentColor
            : Qt.rgba(1, 1, 1, toggleMouse.containsMouse ? 0.14 : 0.09)

        Behavior on color {
            ColorAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }

        }

        Rectangle {
            width: 16
            height: 16
            radius: 8
            color: toggle.checked ? toggle.surface : toggle.muted
            anchors.verticalCenter: parent.verticalCenter
            x: toggle.checked ? parent.width - width - 3 : 3
            // Nyomasra a gomb kicsit megnyulik, mint egy fizikai kapcsolo.
            scale: toggleMouse.pressed ? 0.88 : 1

            Behavior on x {
                SpringAnimation {
                    spring: 7
                    damping: 0.6
                    epsilon: 0.05
                }

            }

            Behavior on scale {
                SpringAnimation {
                    spring: 9
                    damping: 0.55
                    epsilon: 0.0005
                }

            }

        }

        FocusRing {
            theme: toggle.theme
            active: toggle.activeFocus
            cornerRadius: track.radius
        }

    }

    MouseArea {
        id: toggleMouse

        anchors.fill: track
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.activate()
    }

}

import QtQuick

// Billentyuzet-fokusz jelzese.
//
// A shell nem hasznal QtQuick.Controls-t, tehat nincs beepitett fokuszgyuru
// sem. Enelkul a Tab-bal navigalo felhasznalo nem latja, hol all -- ezt a
// vezerlok kozosen hasznaljak, hogy mindenhol ugyanugy nezzen ki.
Rectangle {
    id: ring

    property var theme: null
    property bool active: false

    readonly property string accent: theme ? theme.accent : "#b7372f"

    anchors.fill: parent
    anchors.margins: -3
    color: "transparent"
    border.color: ring.accent
    border.width: 1
    radius: 0
    visible: ring.active
    opacity: ring.active ? 0.75 : 0

    Behavior on opacity {
        NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
    }
}

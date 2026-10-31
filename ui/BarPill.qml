import QtQuick

// A felso sav elemeinek kozos hattere. Hoverre egy halvany, lekerekitett lap
// jelenik meg az elem mogott. Ha az elem panelje nyitva van (`active`), nincs
// hattere: a nyitott allapotot az akcentes ikon es a lenyilo lap jelzi.
// A szulo elejere kell tenni, hogy a tartalom alatta maradjon.
Rectangle {
    id: pill

    property var theme: null
    property bool hovered: false
    property bool active: false

    anchors.fill: parent
    anchors.topMargin: 3
    anchors.bottomMargin: 3
    radius: 6
    color: Qt.rgba(1, 1, 1, hovered && !active ? 0.08 : 0)

    Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
}

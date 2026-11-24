pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland

// Tetlenseg-figyelo, ami az idotullepes kesobbi valtozasat is koveti.
//
// A Quickshell IdleMonitor-a a `timeout` erteket csak letrehozaskor adja at a
// compositornak; egy kesobbi valtozas hatastalan. A beallitasok a
// `settings.json`-bol aszinkron erkeznek (es a Settings oldal futas kozben is
// valtoztatja oket), ezert minden valtozaskor uj monitort epitunk.
Item {
    id: watch

    // Ha hamis, nincs monitor.
    property bool active: true
    // Masodpercben; 0 = kikapcsolva.
    property int timeout: 0
    property bool respectInhibitors: true
    readonly property IdleMonitor current: monitor.item as IdleMonitor
    readonly property bool isIdle: current ? current.isIdle : false

    property int appliedTimeout: 0
    property bool appliedRespectInhibitors: true

    width: 0
    height: 0
    visible: false

    function rebuild() {
        monitor.active = false
        appliedTimeout = timeout
        appliedRespectInhibitors = respectInhibitors
        monitor.active = active && timeout > 0
    }

    // Egy idoben erkezo valtozasok (pl. active es timeout) egy ujraepitesbe
    // olvadnak.
    onActiveChanged: Qt.callLater(rebuild)
    onTimeoutChanged: Qt.callLater(rebuild)
    onRespectInhibitorsChanged: Qt.callLater(rebuild)
    Component.onCompleted: rebuild()

    Loader {
        id: monitor

        active: false
        sourceComponent: IdleMonitor {
            timeout: watch.appliedTimeout
            respectInhibitors: watch.appliedRespectInhibitors
        }
    }
}

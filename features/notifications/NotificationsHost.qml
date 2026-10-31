import QtQuick
import Quickshell
import Quickshell.Wayland
import "." as NotificationUi

PanelWindow {
    id: notifyWindow

    property var theme: null
    property int barHeight: 26
    property alias dnd: controller.dnd
    property alias currentNotification: controller.currentNotification
    property alias toastVisible: controller.toastVisible
    property alias menuOpened: controller.menuOpened
    property alias history: controller.history
    property alias groups: controller.groups
    property alias grouping: controller.groupingEnabled
    property alias unreadCount: controller.unreadCount
    readonly property alias hasToast: controller.hasToast
    readonly property bool menuExpanded: center.transitionActive

    function setMenuOpen(open, targetScreen) {
        if (targetScreen) screen = targetScreen
        if (open && controller.toastVisible) {
            toast.animateTransitions = false
            controller.hideToastForMenu()
            toastAnimationReset.restart()
        }
        controller.setMenuOpen(open)
    }

    function clearHistory() {
        controller.clearHistory()
    }

    function setAllGroupsExpanded(expanded) {
        controller.setAllGroupsExpanded(expanded)
    }

    function toggleMenu(targetScreen) {
        setMenuOpen(!(menuOpened && (!targetScreen || screen === targetScreen)), targetScreen)
    }

    visible: menuExpanded || controller.toastVisible || toast.reveal > 0
    implicitWidth: toast.width
    implicitHeight: toast.height
    color: "transparent"
    anchors { top: true; right: true; bottom: menuExpanded; left: menuExpanded }
    // A felugro ertesites a sav aljahoz es a kepernyo jobb szelehez tapad, es a
    // sav mogul csuszik le -- az ablak teteje vagja le a sav feletti reszt.
    margins { top: menuExpanded ? 0 : barHeight; right: 0 }
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "quickshell.notifications"
    WlrLayershell.exclusiveZone: -1

    NotificationUi.NotificationsController {
        id: controller
    }

    Timer { id: toastAnimationReset; interval: 0; onTriggered: toast.animateTransitions = true }

    NotificationUi.NotificationToast {
        id: toast
        anchors.right: parent.right
        y: notifyWindow.menuExpanded ? notifyWindow.barHeight : 0
        theme: notifyWindow.theme
        notification: controller.currentNotification
        actions: controller.currentActions
        shown: controller.toastVisible && !controller.menuOpened
        onActivated: controller.activateNotification()
        onActionRequested: action => controller.activateCurrentAction(action)
        onDismissed: controller.closeToast(true)
        onHoverChanged: (hovered) => {
            if (hovered) controller.pauseToastTimer()
            else controller.resumeToastTimer()
        }
    }

    NotificationUi.NotificationCenter {
        id: center
        anchors.fill: parent
        theme: notifyWindow.theme
        barHeight: notifyWindow.barHeight
        opened: controller.menuOpened
        dnd: controller.dnd
        history: controller.history
        groups: controller.groups
        onCloseRequested: controller.setMenuOpen(false)
        onDndToggleRequested: controller.dnd = !controller.dnd
        onClearRequested: controller.clearHistory()
        onItemDeleteRequested: entryId => controller.removeHistory(entryId, true)
        onItemActivated: entryId => controller.activateHistoryEntry(entryId, null)
        onItemActionRequested: (entryId, action) => controller.invokeHistoryAction(entryId, action)
        onGroupToggleRequested: groupKey => controller.toggleGroup(groupKey)
        onGroupClearRequested: groupKey => controller.removeGroup(groupKey)
        onGroupsExpandRequested: expanded => controller.setAllGroupsExpanded(expanded)
    }
}

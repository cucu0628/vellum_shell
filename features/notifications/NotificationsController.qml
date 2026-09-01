import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: controller

    property bool dnd: false
    property var currentNotification: null
    property bool toastVisible: false
    property bool menuOpened: false
    property var history: []
    property var toastQueue: []
    property var currentActions: []
    property int unreadCount: 0
    property int nextEntryId: 1
    property int currentEntryId: -1
    property int historyLimit: 100
    property bool groupingEnabled: true
    property var groups: []
    property var expandedGroups: ({})
    readonly property bool hasToast: toastVisible && currentNotification !== null

    width: 0
    height: 0
    visible: false

    function cleanText(value) {
        return (value || "").toString().replace(/<[^>]*>/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").trim()
    }

    function historyEntry(entryId) {
        for (var i = 0; i < history.length; i++) {
            if (history[i].id === entryId) return history[i]
        }
        return null
    }

    function groupKeyFor(entry) {
        if (!entry) return "notification"
        if (!groupingEnabled) return "entry-" + entry.id
        var key = (entry.appName || "").toString().toLowerCase().trim()
        return key === "" ? "notification" : key
    }

    function rebuildGroups() {
        var built = []
        var index = ({})

        for (var i = 0; i < history.length; i++) {
            var entry = history[i]
            var key = groupKeyFor(entry)
            var group = index[key]
            if (!group) {
                group = {
                    key: key,
                    appName: entry.appName || "Notification",
                    icon: entry.icon,
                    count: 0,
                    unread: 0,
                    critical: false,
                    time: entry.time,
                    expanded: expandedGroups[key] === true,
                    entries: []
                }
                index[key] = group
                built.push(group)
            }
            group.entries.push(entry)
            group.count++
            if (entry.unread) group.unread++
            if (entry.critical) group.critical = true
            if (group.icon === "" && entry.icon !== "") group.icon = entry.icon
        }

        var nextExpanded = ({})
        var expandedChanged = false
        for (var g = 0; g < built.length; g++) {
            if (expandedGroups[built[g].key] === true) nextExpanded[built[g].key] = true
        }
        for (var stale in expandedGroups) {
            if (nextExpanded[stale] !== true) expandedChanged = true
        }
        if (expandedChanged) expandedGroups = nextExpanded

        groups = built
    }

    function setGroupExpanded(key, expanded) {
        var next = ({})
        for (var existing in expandedGroups) next[existing] = expandedGroups[existing]
        if (expanded) next[key] = true
        else delete next[key]
        expandedGroups = next
        rebuildGroups()
    }

    function toggleGroup(key) {
        setGroupExpanded(key, expandedGroups[key] !== true)
    }

    function setAllGroupsExpanded(expanded) {
        var next = ({})
        if (expanded) {
            for (var i = 0; i < groups.length; i++) {
                if (groups[i].count > 1) next[groups[i].key] = true
            }
        }
        expandedGroups = next
        rebuildGroups()
    }

    function removeGroup(key) {
        var nextHistory = []
        var removedNotifications = []

        for (var i = 0; i < history.length; i++) {
            var entry = history[i]
            if (groupKeyFor(entry) === key) {
                if (entry.unread) unreadCount = Math.max(0, unreadCount - 1)
                removeQueuedEntry(entry.id)
                if (currentEntryId === entry.id) clearCurrentToast()
                if (entry.notification) removedNotifications.push(entry.notification)
            } else {
                nextHistory.push(entry)
            }
        }

        history = nextHistory
        for (var dismissed = 0; dismissed < removedNotifications.length; dismissed++) removedNotifications[dismissed].dismiss()
        showNextToast()
    }

    function removeQueuedEntry(entryId) {
        var nextQueue = []
        for (var i = 0; i < toastQueue.length; i++) {
            if (toastQueue[i] !== entryId) nextQueue.push(toastQueue[i])
        }
        toastQueue = nextQueue
    }

    function clearCurrentToast() {
        toastVisible = false
        currentNotification = null
        currentActions = []
        currentEntryId = -1
        expireTimer.stop()
    }

    function showNextToast() {
        if (currentNotification || menuOpened || dnd) return

        while (toastQueue.length > 0) {
            var entryId = toastQueue[0]
            toastQueue = toastQueue.slice(1)
            var entry = historyEntry(entryId)
            if (!entry || !entry.notification) continue

            currentNotification = entry.notification
            currentActions = entry.actions || []
            currentEntryId = entryId
            toastVisible = true
            expireTimer.interval = Math.max(2600, Math.min(7000, entry.notification.expireTimeout > 0 ? entry.notification.expireTimeout * 1000 : 4200))
            expireTimer.restart()
            return
        }
    }

    function refreshNotification(entryId) {
        var entry = historyEntry(entryId)
        if (!entry || !entry.notification) return

        var notification = entry.notification
        var actions = []
        var defaultAction = null
        for (var actionIndex = 0; actionIndex < notification.actions.length; actionIndex++) {
            var action = notification.actions[actionIndex]
            actions.push(action)
            if (action.identifier === "default") defaultAction = action
        }

        entry.appName = cleanText(notification.appName || "Notification")
        entry.summary = cleanText(notification.summary)
        entry.body = cleanText(notification.body)
        entry.icon = notification.image !== "" ? notification.image : (notification.appIcon !== "" ? Quickshell.iconPath(notification.appIcon, true) : "")
        entry.critical = notification.urgency === NotificationUrgency.Critical
        entry.actions = actions
        entry.defaultAction = defaultAction
        history = history.slice()

        if (currentEntryId === entryId) currentActions = actions
    }

    function scheduleNotificationRefresh(entryId) {
        Qt.callLater(function() { controller.refreshNotification(entryId) })
    }

    function displayNotification(notification) {
        var icon = notification.image !== "" ? notification.image : (notification.appIcon !== "" ? Quickshell.iconPath(notification.appIcon, true) : "")
        var actions = []
        var defaultAction = null
        for (var actionIndex = 0; actionIndex < notification.actions.length; actionIndex++) {
            var action = notification.actions[actionIndex]
            actions.push(action)
            if (action.identifier === "default") defaultAction = action
        }
        var entryId = nextEntryId++
        notification.tracked = true
        notification.closed.connect(function() { controller.handleNotificationClosed(entryId) })
        notification.actionsChanged.connect(function() { controller.scheduleNotificationRefresh(entryId) })
        notification.appNameChanged.connect(function() { controller.scheduleNotificationRefresh(entryId) })
        notification.appIconChanged.connect(function() { controller.scheduleNotificationRefresh(entryId) })
        notification.summaryChanged.connect(function() { controller.scheduleNotificationRefresh(entryId) })
        notification.bodyChanged.connect(function() { controller.scheduleNotificationRefresh(entryId) })
        notification.imageChanged.connect(function() { controller.scheduleNotificationRefresh(entryId) })
        notification.urgencyChanged.connect(function() { controller.scheduleNotificationRefresh(entryId) })
        var entry = {
            id: entryId,
            appName: cleanText(notification.appName || "Notification"),
            summary: cleanText(notification.summary),
            body: cleanText(notification.body),
            icon: icon,
            critical: notification.urgency === NotificationUrgency.Critical,
            time: Qt.formatTime(new Date(), "HH:mm"),
            unread: !menuOpened,
            notification: notification,
            actions: actions,
            defaultAction: defaultAction
        }
        var nextHistory = [entry]
        for (var i = 0; i < history.length && i < historyLimit - 1; i++) nextHistory.push(history[i])
        var droppedNotifications = []
        for (var dropped = historyLimit - 1; dropped < history.length; dropped++) {
            if (history[dropped].unread) unreadCount = Math.max(0, unreadCount - 1)
            removeQueuedEntry(history[dropped].id)
            if (history[dropped].notification) droppedNotifications.push(history[dropped].notification)
        }
        history = nextHistory
        if (!menuOpened) unreadCount++
        for (var expired = 0; expired < droppedNotifications.length; expired++) droppedNotifications[expired].expire()

        if (dnd || menuOpened) {
            return
        }

        toastQueue = toastQueue.concat([entryId])
        showNextToast()
    }

    function closeToast(explicitClose) {
        if (!currentNotification) return
        var entryId = currentEntryId
        var notification = currentNotification
        clearCurrentToast()
        if (explicitClose) removeHistory(entryId, true)
        else if (!notification.resident) notification.expire()
        showNextToast()
    }

    function activateNotification() {
        if (!currentNotification) return

        var notification = currentNotification
        var entryId = currentEntryId
        var entry = historyEntry(entryId)
        if (!entry || !entry.defaultAction) return
        clearCurrentToast()
        activateHistoryEntry(entryId, notification)
        showNextToast()
    }

    function activateCurrentAction(action) {
        if (!currentNotification || !action) return

        var notification = currentNotification
        var entryId = currentEntryId
        clearCurrentToast()
        invokeEntryAction(entryId, action, notification)
        showNextToast()
    }

    function setMenuOpen(open) {
        menuOpened = open
        if (open) {
            unreadCount = 0
            if (toastVisible) hideToastForMenu()
        }
    }

    function hideToastForMenu() {
        clearCurrentToast()
        toastQueue = []
    }

    function removeHistory(entryId, dismissNotification) {
        var nextHistory = []
        var removedNotification = null
        removeQueuedEntry(entryId)
        for (var i = 0; i < history.length; i++) {
            var entry = history[i]
            if (entry.id === entryId) {
                if (entry.unread) unreadCount = Math.max(0, unreadCount - 1)
                if (dismissNotification && entry.notification) removedNotification = entry.notification
            } else {
                nextHistory.push(entry)
            }
        }
        history = nextHistory
        if (removedNotification) removedNotification.dismiss()
    }

    function invokeEntryAction(entryId, action, fallbackNotification) {
        var entry = historyEntry(entryId)
        var notification = entry && entry.notification ? entry.notification : fallbackNotification
        var resident = notification && notification.resident

        if (action && resident) {
            if (entry && entry.unread) {
                entry.unread = false
                unreadCount = Math.max(0, unreadCount - 1)
                history = history.slice()
            }
            action.invoke()
            return
        }

        removeHistory(entryId, false)

        if (action) {
            action.invoke()
        } else if (notification) {
            notification.dismiss()
        }
    }

    function invokeHistoryAction(entryId, action) {
        if (!action) return
        invokeEntryAction(entryId, action, null)
    }

    function activateHistoryEntry(entryId, fallbackNotification) {
        var selectedEntry = null
        for (var i = 0; i < history.length; i++) {
            if (history[i].id === entryId) {
                selectedEntry = history[i]
                break
            }
        }
        if (!selectedEntry || !selectedEntry.defaultAction) return
        invokeEntryAction(entryId, selectedEntry.defaultAction, fallbackNotification)
    }

    function handleNotificationClosed(entryId) {
        removeQueuedEntry(entryId)
        var wasCurrent = currentEntryId === entryId
        if (wasCurrent) clearCurrentToast()

        var nextHistory = []
        for (var i = 0; i < history.length; i++) {
            var entry = history[i]
            if (entry.id === entryId) {
                entry.notification = null
                entry.actions = []
                entry.defaultAction = null
            }
            nextHistory.push(entry)
        }
        history = nextHistory
        if (wasCurrent) Qt.callLater(showNextToast)
    }

    function clearHistory() {
        var notifications = []
        for (var i = 0; i < history.length; i++) {
            if (history[i].notification) notifications.push(history[i].notification)
        }
        clearCurrentToast()
        toastQueue = []
        history = []
        unreadCount = 0
        for (var dismissed = 0; dismissed < notifications.length; dismissed++) notifications[dismissed].dismiss()
    }

    function pauseToastTimer() {
        expireTimer.stop()
    }

    function resumeToastTimer() {
        if (toastVisible) expireTimer.restart()
    }

    onHistoryChanged: rebuildGroups()
    onGroupingEnabledChanged: {
        expandedGroups = ({})
        rebuildGroups()
    }
    onDndChanged: if (dnd) toastQueue = []

    NotificationServer {
        actionsSupported: true
        imageSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        keepOnReload: false
        onNotification: (notification) => controller.displayNotification(notification)
    }

    Timer {
        id: expireTimer
        onTriggered: controller.closeToast(false)
    }
}

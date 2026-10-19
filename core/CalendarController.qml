import QtQuick

// Google Naptar a Rust backend `calendar` topicjabol.
//
// A bejelentkezest (OAuth a bongeszoben), a tokent es a lekerest a daemon
// vegzi; ez a fajl binding, plusz egy napokra bontott index, hogy a havi racs
// ne a teljes esemenylistat szurje minden cellaban. Daemon nelkul minden ures
// marad, a naptar sima naptarkent mukodik tovabb.
Item {
    id: calendar

    required property var backend
    property bool active: false

    readonly property var topic: backend && backend.topics.calendar ? backend.topics.calendar : ({})

    readonly property bool available: backend ? backend.connected : false
    readonly property bool configured: topic.configured === true
    readonly property bool connected: topic.connected === true
    readonly property string status: topic.status || "idle"
    readonly property bool authorizing: status === "authorizing"
    readonly property bool syncing: status === "syncing"
    // A token a kulcstarban van, ami most zarolt. A refresh() feloldja
    // (jelszoablakkal); a hatterben futo szinkron ezt sosem teszi meg.
    readonly property bool locked: topic.locked === true
    readonly property string account: topic.account || ""
    readonly property string error: topic.error || ""
    readonly property string authUrl: topic.authUrl || ""
    readonly property real updatedAt: topic.updatedAt || 0
    readonly property var calendars: topic.calendars || []
    readonly property var events: topic.events || []
    // "YYYY-M-D" (helyi datum) -> az aznapi esemenyek; elol az egesz naposak.
    readonly property var eventsByDay: buildIndex(events)

    // Egy parancs sajat hibaja (pl. rossz client ID). A topic `error` mezoje a
    // szinkron hibait hordozza; ez a kettot nem keveri ossze.
    property string callError: ""

    width: 0
    height: 0
    visible: false

    function dayKey(date) {
        return date.getFullYear() + "-" + (date.getMonth() + 1) + "-" + date.getDate()
    }

    function eventsOn(date) {
        return eventsByDay[dayKey(date)] || []
    }

    function localDate(text) {
        var parts = String(text).split("-")
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))
    }

    function buildIndex(list) {
        var index = {}
        for (var i = 0; i < list.length; i++) {
            var event = list[i]
            var first, last
            if (event.allDay) {
                first = localDate(event.startDate)
                last = localDate(event.endDate)
                last.setDate(last.getDate() - 1)
            } else {
                first = new Date(event.start)
                // A vege kizarolagos: egy ejfelkor vegzodo esemeny nem log at
                // a kovetkezo napra.
                last = new Date(Math.max(event.start, event.end - 1))
            }
            var day = new Date(first.getFullYear(), first.getMonth(), first.getDate())
            for (var guard = 0; day <= last && guard < 366; guard++) {
                var key = dayKey(day)
                if (!index[key]) index[key] = []
                index[key].push(event)
                day = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1)
            }
        }
        for (var dayName in index) {
            index[dayName].sort(function(a, b) {
                if (a.allDay !== b.allDay) return a.allDay ? -1 : 1
                return a.allDay ? 0 : a.start - b.start
            })
        }
        return index
    }

    function login() {
        if (!backend) return
        callError = ""
        backend.call("calendar", "login", {}, function(data, error) {
            if (error) calendar.callError = error.message
            else if (data && data.url) Qt.openUrlExternally(data.url)
        })
    }

    function reopenLogin() {
        if (authUrl !== "") Qt.openUrlExternally(authUrl)
    }

    function cancelLogin() {
        if (backend) backend.call("calendar", "cancelLogin", {})
    }

    function logout() {
        if (backend) backend.call("calendar", "logout", {})
    }

    function refresh() {
        if (backend) backend.call("calendar", "refresh", {})
    }

    function setCalendar(id, enabled) {
        if (backend) backend.call("calendar", "setCalendar", { "id": id, "enabled": enabled })
    }

    // A callback igy hivodik: done(ok).
    function setClient(clientId, clientSecret, done) {
        if (!backend) return
        callError = ""
        backend.call("calendar", "setClient", { "clientId": clientId, "clientSecret": clientSecret }, function(data, error) {
            if (error) calendar.callError = error.message
            if (done) done(!error)
        })
    }

    // Lazy topic: a daemon csak akkor kerdezi a Google-t, ha valaki nezi.
    onActiveChanged: {
        if (!backend) return
        if (active) backend.subscribe("calendar")
        else backend.unsubscribe("calendar")
    }

    Component.onCompleted: if (backend && active) backend.subscribe("calendar")
    Component.onDestruction: if (backend && active) backend.unsubscribe("calendar")
}

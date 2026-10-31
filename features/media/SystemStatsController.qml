import QtQuick

// CPU-, RAM- es lemezhasznalat a Rust backend `sysstats` topicjabol.
//
// Korabban ez a fajl ket FileView-t olvasott es egy `df -P /` processzt
// inditott. A `df` eltunt, a szamolas pedig egy helyre kerult.
//
// Az `active` tovabbra is kapcsol: a backend lazy topicja miatt a hurok ott
// sem fut, amig senki nem nezi.
Item {
    id: stats

    required property var backend
    property bool active: false

    // Nem `state`: az utkozne a QQuickItem beepitett propertyjevel.
    readonly property var topic: backend && backend.topics.sysstats ? backend.topics.sysstats : ({})

    readonly property int cpuUsage: topic.cpuUsage || 0
    readonly property int ramUsage: topic.ramUsage || 0
    readonly property int diskUsage: topic.diskUsage || 0
    // Regebbi daemon ezeket nem kuldi: ilyenkor -1, es a kartya csak a
    // szazalekot mutatja.
    readonly property real ramUsedGib: topic.ramUsedGib !== undefined ? topic.ramUsedGib : -1
    readonly property real ramTotalGib: topic.ramTotalGib !== undefined ? topic.ramTotalGib : -1
    readonly property real diskUsedGib: topic.diskUsedGib !== undefined ? topic.diskUsedGib : -1
    readonly property real diskTotalGib: topic.diskTotalGib !== undefined ? topic.diskTotalGib : -1
    readonly property int uptimeSeconds: topic.uptimeSeconds || 0

    // Az utolso 60 CPU-minta a grafikonhoz. A backend masodpercenkent kuld egy
    // uj allapotot akkor is, ha az ertek nem valtozott, ezert a topichoz
    // kotunk, nem a cpuUsage-hez.
    readonly property int historyLength: 60
    property var cpuHistory: []

    onTopicChanged: {
        if (topic.cpuUsage === undefined) return
        var next = cpuHistory.slice(Math.max(0, cpuHistory.length - historyLength + 1))
        next.push(topic.cpuUsage)
        cpuHistory = next
    }

    width: 0
    height: 0
    visible: false

    onActiveChanged: {
        if (!backend) return
        if (active) backend.subscribe("sysstats")
        else backend.unsubscribe("sysstats")
    }

    // Az onActiveChanged nem fut le, ha a controller mar aktivkent jon letre
    // (a shell szintjen mindig az): ilyenkor itt iratkozunk fel.
    Component.onCompleted: if (backend && active) backend.subscribe("sysstats")

    Component.onDestruction: if (backend && active) backend.unsubscribe("sysstats")
}

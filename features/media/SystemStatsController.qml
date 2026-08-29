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

    width: 0
    height: 0
    visible: false

    onActiveChanged: {
        if (!backend) return
        if (active) backend.subscribe("sysstats")
        else backend.unsubscribe("sysstats")
    }

    Component.onDestruction: if (backend && active) backend.unsubscribe("sysstats")
}

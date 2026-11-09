import QtQuick

// A backend `netsecrets` topicja: a NetworkManager jelszokeresei (uj vagy
// elutasitott Wi-Fi jelszo, 802.1X, PPPoE). A backend csak addig agent, amig ez
// a controller feliratkozik, igy shell nelkul a kerdes egy masik agenthez
// (nm-applet, `nmcli --ask`) kerul.
//
// A titok csak a `reply` hivasban utazik; a topic sosem tartalmazza.
Item {
    id: agent

    required property var backend

    readonly property var topic: backend && backend.topics.netsecrets ? backend.topics.netsecrets : null
    readonly property var request: topic && topic.request ? topic.request : null
    readonly property int requestId: request ? request.id : 0
    property bool busy: false
    property string error: ""

    width: 0
    height: 0
    visible: false

    // A topic minden pushra uj objektumot ad; csak a keres valtasa nullaz.
    onRequestIdChanged: {
        busy = false
        error = ""
    }

    function reply(secrets) {
        if (!request || busy) return
        var id = request.id
        busy = true
        error = ""
        backend.call("netsecrets", "reply", { "id": id, "secrets": secrets }, function(data, err) {
            if (agent.requestId !== id) return
            agent.busy = false
            if (err) agent.error = err.message || "The password could not be sent."
        })
    }

    function cancel() {
        if (!request) return
        backend.call("netsecrets", "cancel", { "id": request.id }, null)
    }

    Component.onCompleted: if (backend) backend.subscribe("netsecrets")
}

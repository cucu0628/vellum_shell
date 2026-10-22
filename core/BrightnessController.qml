import QtQuick

// A beepitett kijelzo fenyereje a Rust backend `brightness` topicjabol.
// Hattervilagitas nelkuli gepen (vagy daemon nelkul) `available` hamis, es a
// shell nem mutat fenyero-OSD-t.
Item {
    id: controller

    required property var backend

    readonly property var topic: backend && backend.topics.brightness ? backend.topics.brightness : null
    readonly property bool available: topic !== null && topic.available === true
    readonly property int percent: available ? (topic.percent || 0) : -1
    readonly property string device: available ? (topic.device || "") : ""

    width: 0
    height: 0
    visible: false

    // Lepes szazalekban; a backend a durva fokozatu paneleken legalabb egy
    // fokozatot lep.
    function step(delta) {
        if (backend) backend.call("brightness", "step", { "delta": delta })
    }

    Component.onCompleted: if (backend) backend.subscribe("brightness")
}

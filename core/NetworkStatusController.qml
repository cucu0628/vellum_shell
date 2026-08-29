import QtQuick

// Halozati allapot a Rust backend `network` topicjabol.
//
// Korabban ez a fajl `nmcli`-t es `ip -4 -j`-t inditott, 300 masodpercenkent es
// minden eszkoz-esemenynel, majd kezzel parsolta a kimenetet. Az adat most
// kozvetlenul a NetworkManagertol jon, esemenyvezerelten.
//
// A publikus property-nevek valtozatlanok: a bar es a halozati panel ezekre epul.
Item {
    id: controller

    required property var backend

    // Nem `state`: az utkozne a QQuickItem beepitett propertyjevel.
    readonly property var topic: backend && backend.topics.network ? backend.topics.network : ({})

    readonly property bool connected: topic.connected === true
    readonly property string connectionType: topic.connectionType || "offline"
    readonly property string connectionName: topic.connectionName || ""
    readonly property string device: topic.device || ""
    readonly property string lanIp: topic.lanIp || ""
    readonly property bool vpnActive: topic.vpnActive === true
    readonly property string vpnName: topic.vpnName || ""

    width: 0
    height: 0
    visible: false

    Component.onCompleted: if (backend) backend.subscribe("network")

    // A backend magatol ertesit a valtozasrol; ez csak azert maradt meg, hogy a
    // korabbi hivasi pontok ne torjenek el.
    function refresh() {}
}

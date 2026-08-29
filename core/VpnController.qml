import QtQuick

// A VPN sav-elem es a Proton panel kozos allapota, a backend `vpn` topicjabol.
//
// A megosztas ugyanaz maradt, ami korabban is volt, es ugyanazert: minden
// `protonvpn` hivas ~2,5 masodperc python-indulas, ezert az "all-e az alagut"
// kerdesre a NetworkManager valaszol ezredmasodpercek alatt, a CLI-t pedig
// csak reszletekhez es muveletekhez hivjuk -- most mar a backendben, gyorsitotarazva.
//
// A publikus property-nevek es fuggvenyek valtozatlanok: a panel ezekre epul.
Item {
    id: controller

    required property var backend

    readonly property var topic: backend && backend.topics.vpn ? backend.topics.vpn : ({})

    // Olcso allapot, a savval kozosen.
    readonly property bool active: topic.active === true
    readonly property string rawName: topic.rawName || ""
    readonly property string name: topic.name || ""
    readonly property bool cliConnected: topic.cliConnected === true
    readonly property bool protonActive: topic.protonActive === true
    readonly property bool cliAvailable: topic.cliAvailable !== false

    // Reszletek, amiket a CLI tolt fel.
    readonly property string server: topic.server || ""
    readonly property string location: topic.location || ""
    readonly property string load: topic.load || ""
    readonly property string protocol: topic.protocol || ""
    readonly property string publicIp: topic.publicIp || ""
    readonly property string killSwitch: topic.killSwitch || ""
    readonly property bool locationSelection: topic.locationSelection === true
    readonly property bool planKnown: topic.planKnown === true
    readonly property var countries: topic.countries || []

    property bool panelOpen: false
    property bool checking: false
    property string action: ""
    property string errorMessage: ""
    readonly property bool busy: action !== ""

    width: 0
    height: 0
    visible: false

    Component.onCompleted: if (backend) backend.subscribe("vpn")

    // A backend magatol ertesit; ez csak a korabbi hivasi pontok kedveert van.
    function refresh() {}

    function refreshDetails(force) {
        if (!cliAvailable || checking) return
        checking = true
        backend.call("vpn", "details", { force: force === true }, (result, error) => {
            controller.checking = false
            if (error) controller.errorMessage = error.message
        })
    }

    function refreshConfig(force) {
        if (!cliAvailable) return
        backend.call("vpn", "config", { force: force === true }, (result, error) => {
            if (error) controller.errorMessage = error.message
        })
    }

    function refreshCountries() {
        if (!cliAvailable) return
        // A backend maga hagyja ki a hivast, ha nincs helyvalasztas vagy mar
        // megvan a lista.
        backend.call("vpn", "countries", {}, (result, error) => {
            if (error) controller.errorMessage = error.message
        })
    }

    function panelOpened() {
        errorMessage = ""
        // Nincs mit leirni, amig nem all alagut -- olyankor nem fizetunk a CLI-ert.
        if (protonActive) refreshDetails(false)
        refreshConfig(false)
    }

    function run(label, method, params) {
        if (busy) return
        action = label
        errorMessage = ""
        backend.call("vpn", method, params || {}, (result, error) => {
            controller.action = ""
            if (error) controller.errorMessage = error.message
            else controller.refreshDetails(true)
        })
    }

    function connectFastest() { run("connect", "connect", {}) }
    function connectCountry(code) { run("connect", "connect", { country: code }) }
    function disconnectVpn() { run("disconnect", "disconnect", {}) }
    function openApp() { backend.call("vpn", "openApp", {}, null) }
}

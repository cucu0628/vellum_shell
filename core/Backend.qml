pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Kliens a Rust backendhez ($XDG_RUNTIME_DIR/vellum-shell.sock).
//
// A shell akkor is mukodik, ha a daemon nem fut: ilyenkor a `topics` ures marad,
// a controllerek a sajat alapertekeikre esnek vissza, es a kapcsolat a
// hatterben ujraprobalkozik. Sosem blokkol es sosem dob.
Item {
    id: backend

    // A `VELLUM_SOCKET` mindket oldalon ugyanaz a kapcsolo (lasd
    // `ipc::socket_path`): XDG_RUNTIME_DIR nelkul a Rust oldal uid-suffixes
    // /tmp utvonalra esik vissza, amit innen nem lehet kiszamolni. Ilyen
    // munkamenetben a `shell-start` allitja be ezt a valtozot mindkettonek.
    readonly property string socketPath: {
        var explicitPath = Quickshell.env("VELLUM_SOCKET")
        if (explicitPath) return explicitPath
        var runtimeDir = Quickshell.env("XDG_RUNTIME_DIR")
        if (runtimeDir) return runtimeDir + "/vellum-shell.sock"
        // UID nelkul nem allithato elo biztonsagos /tmp fallback. A normal
        // indito script ilyen kornyezetben VELLUM_SOCKET-et ad at; onallo
        // inditasnal a shell inkabb daemon nelkul, degradaltan mukodik.
        return ""
    }
    readonly property bool connected: _socket ? _socket.connected : false

    // A daemon nelkul ezek az allapotok mar nem allapotok, hanem emlekek: a
    // halozat, a VPN vagy a csatolt eszkozok kozben barmi lehet. A `theme`
    // szandekosan nincs koztuk -- az konfiguracio, ami a daemon kiesese utan is
    // ervenyes marad, es a torlese az egesz shellt alapertelmezett szinekre
    // ejtene.
    readonly property var volatileTopics: ["network", "vpn", "removable", "privacy", "sysstats", "weather", "hypr", "calendar", "session", "brightness"]

    // A Socket sajat magat regisztralja ide. Nem a Loader.item-et hasznaljuk,
    // mert az meg null, amikor a frissen letrehozott Socket mar csatlakozott.
    property var _socket: null

    // topic -> a topic legutobbi allapota. Nem `state`: az utkozne a
    // QQuickItem beepitett state propertyjevel.
    //
    // Topiconkent kulon property, nem egyetlen map: egy map minden uzenetnel uj
    // objektum lett volna, es a masodpercenkenti `sysstats` frissites igy az
    // osszes `backend.topics.*` kotest (tema, halozat, VPN...) ujraertekelte.
    // Uj backend topic = egy uj sor itt es a `topicNames`-ben.
    readonly property QtObject topics: QtObject {
        property var brightness
        property var calendar
        property var clipboard
        property var health
        property var hypr
        property var network
        property var privacy
        property var removable
        property var session
        property var sysstats
        property var theme
        property var vpn
        property var weather
    }
    readonly property var topicNames: ["brightness", "calendar", "clipboard", "health", "hypr", "network", "privacy", "removable", "session", "sysstats", "theme", "vpn", "weather"]

    signal topicUpdated(string topic, var data)

    width: 0
    height: 0
    visible: false

    property var _pending: ({})       // keres id -> callback
    property var _deadlines: ({})     // keres id -> lejarat (ms, Date.now())
    property var _refcounts: ({})     // topic -> hany feliratkozo
    property int _nextId: 1
    property int _backoff: 250
    property bool _rebuilding: false

    // Feliratkozas egy topicra. Tobb controller is kerheti ugyanazt; a
    // leiratkozas csak az utolso utan megy ki a daemonnak.
    function subscribe(topic) {
        var count = _refcounts[topic] || 0
        _refcounts[topic] = count + 1
        if (count === 0) _send({ op: "subscribe", topics: [topic] })
    }

    function unsubscribe(topic) {
        var count = _refcounts[topic] || 0
        if (count <= 0) return
        _refcounts[topic] = count - 1
        if (count === 1) _send({ op: "unsubscribe", topics: [topic] })
    }

    // Ha a daemon fogadja a kerest, de nem valaszol, a hivo ennyi ido utan
    // "timeout" hibat kap, ahelyett hogy orokre varna. A backend sajat
    // idokorlatai (CLI 20 s, hosszu parancs 30 s) ez alatt maradnak; ami ennel
    // tovabb tarthat (kulcstar-feloldas), az a `timeoutMs`-sel kerjen tobbet.
    property int callTimeout: 60000

    // Parancs kuldese. A callback (ha van) igy hivodik: cb(data, error).
    // Hiba eseten `error` egy { code, message } objektum.
    function call(domain, method, params, callback, timeoutMs) {
        var id = _nextId++
        if (callback) {
            _pending[id] = callback
            _deadlines[id] = Date.now() + (timeoutMs > 0 ? timeoutMs : callTimeout)
            pendingSweep.start()
        }
        if (!_send({ op: "call", id: id, domain: domain, method: method, params: params || {} })) {
            delete _pending[id]
            delete _deadlines[id]
            if (callback) callback(null, {
                code: "disconnected",
                message: "a backend nem elerheto"
            })
        }
        return id
    }

    function _send(message) {
        message.v = 1
        if (!_socket || !_socket.connected) {
            return false
        }
        _socket.write(JSON.stringify(message) + "\n")
        _socket.flush()
        return true
    }

    function _onLine(line) {
        if (line.trim() === "") return

        var message
        try {
            message = JSON.parse(line)
        } catch (e) {
            console.warn("Backend: ertelmezhetetlen sor:", line)
            return
        }

        if (message.topic !== undefined) {
            if (topicNames.indexOf(message.topic) >= 0) topics[message.topic] = message.data
            else console.warn("Backend: ismeretlen topic:", message.topic)
            topicUpdated(message.topic, message.data)
            return
        }

        if (message.id === undefined) return
        var callback = _pending[message.id]
        if (!callback) return
        delete _pending[message.id]
        delete _deadlines[message.id]
        if (message.ok) callback(message.data, null)
        else callback(null, message.error || { code: "unknown", message: "" })
    }

    function _onConnected(socket) {
        _backoff = 250
        reconnectTimer.stop()
        if (!socket) return

        // Ujracsatlakozas utan minden elo feliratkozast helyreallitunk, hogy a
        // daemon ujraindulasa ne hagyjon befagyott allapotot a shellben.
        var activeTopics = []
        for (var topic in _refcounts) {
            if (_refcounts[topic] > 0) activeTopics.push(topic)
        }
        if (activeTopics.length > 0) {
            socket.write(JSON.stringify({ v: 1, op: "subscribe", topics: activeTopics }) + "\n")
        }

        socket.flush()
    }

    function _onDisconnected() {
        // A valaszra varo hivok ne fagyjanak be orokre.
        // Elobb levalasztjuk a terkepet: egy callbackbol inditott uj hivas igy
        // nem veszhet el a regi pending allapot takaritasakor.
        var pending = _pending
        _pending = {}
        _deadlines = {}
        for (var id in pending) {
            pending[id](null, { code: "disconnected", message: "megszakadt a kapcsolat a backenddel" })
        }
        _dropVolatileTopics()
        _scheduleReconnect()
    }

    // A mulando allapotok eldobasa, hogy a controllerek a sajat "nem elerheto"
    // agukra essenek vissza, ahelyett hogy elavult adatot mutatnanak
    // aktualiskent. Ujracsatlakozaskor a daemon amugy is azonnal kuld friss
    // snapshotot minden elo feliratkozasra.
    function _dropVolatileTopics() {
        for (var i = 0; i < volatileTopics.length; i++) {
            var key = volatileTopics[i]
            if (topics[key] === undefined || topics[key] === null) continue
            topics[key] = null
            topicUpdated(key, null)
        }
    }

    // A Quickshell Socket egy sikertelen vagy megszakadt kapcsolat utan nem
    // eleszthato ujra -- a `connected` visszaallitasa nem tesz semmit. Ezert a
    // Loadert kapcsoljuk ki-be, ami friss Socket peldanyt epit.
    function _scheduleReconnect() {
        // Szandekosan a Socket elo allapotat nezzuk, nem a szarmaztatott
        // `connected` propertyt: a bontas pillanataban a binding meg a regi
        // true erteket adhatja vissza, es akkor sosem utemeznenk ujra.
        //
        // A _rebuilding azert kell, mert a regi Socket lebontasa is kivalt egy
        // "megszakadt" allapotvaltast -- e nelkul az ujraepites sajat magat
        // utemezne be ujra es ujra.
        if ((_socket && _socket.connected) || reconnectTimer.running || _rebuilding) return
        reconnectTimer.interval = _backoff
        _backoff = Math.min(_backoff * 2, 10000)
        reconnectTimer.restart()
    }

    Loader {
        id: socketLoader
        active: backend.socketPath !== ""

        sourceComponent: Component {
            Socket {
                id: socketInstance
                path: backend.socketPath
                connected: true

                Component.onCompleted: backend._socket = socketInstance
                Component.onDestruction: {
                    if (backend._socket === socketInstance) backend._socket = null
                }

                parser: SplitParser {
                    splitMarker: "\n"
                    onRead: line => backend._onLine(line)
                }

                onConnectionStateChanged: {
                    if (connected) backend._onConnected(socketInstance)
                    else backend._onDisconnected()
                }

                onError: backend._scheduleReconnect()
            }
        }
    }

    // A lejart hivasok takaritasa. Csak addig fut, amig van valaszra varo hivas.
    Timer {
        id: pendingSweep
        interval: 1000
        repeat: true
        onTriggered: {
            var now = Date.now()
            var expired = []
            var waiting = false
            for (var id in backend._deadlines) {
                if (backend._deadlines[id] <= now) expired.push(id)
                else waiting = true
            }
            if (!waiting) stop()
            for (var i = 0; i < expired.length; i++) {
                var callback = backend._pending[expired[i]]
                delete backend._pending[expired[i]]
                delete backend._deadlines[expired[i]]
                if (callback) callback(null, { code: "timeout", message: "a backend nem valaszolt idoben" })
            }
        }
    }

    Timer {
        id: reconnectTimer
        repeat: false
        onTriggered: {
            // A flag csak a lebontasra vonatkozik. Az aktivalas mar nelkule
            // fut, kulonben az uj Socket azonnali hibaja is elnyelodne, es
            // sosem lenne tobb ujraprobalkozas.
            backend._rebuilding = true
            socketLoader.active = false
            backend._rebuilding = false
            socketLoader.active = true
        }
    }
}

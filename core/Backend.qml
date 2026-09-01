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

    readonly property string socketPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/vellum-shell.sock"
    readonly property bool connected: _socket ? _socket.connected : false

    // A Socket sajat magat regisztralja ide. Nem a Loader.item-et hasznaljuk,
    // mert az meg null, amikor a frissen letrehozott Socket mar csatlakozott.
    property var _socket: null

    // topic -> a topic legutobbi allapota. Nem `state`: az utkozne a
    // QQuickItem beepitett state propertyjevel.
    property var topics: ({})

    signal topicUpdated(string topic, var data)

    width: 0
    height: 0
    visible: false

    property var _pending: ({})       // keres id -> callback
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

    // Parancs kuldese. A callback (ha van) igy hivodik: cb(data, error).
    // Hiba eseten `error` egy { code, message } objektum.
    function call(domain, method, params, callback) {
        var id = _nextId++
        if (callback) _pending[id] = callback
        if (!_send({ op: "call", id: id, domain: domain, method: method, params: params || {} })) {
            delete _pending[id]
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
            var next = {}
            for (var key in backend.topics) next[key] = backend.topics[key]
            next[message.topic] = message.data
            backend.topics = next
            topicUpdated(message.topic, message.data)
            return
        }

        if (message.id === undefined) return
        var callback = _pending[message.id]
        if (!callback) return
        delete _pending[message.id]
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
        for (var id in pending) {
            pending[id](null, { code: "disconnected", message: "megszakadt a kapcsolat a backenddel" })
        }
        _scheduleReconnect()
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
        active: true

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

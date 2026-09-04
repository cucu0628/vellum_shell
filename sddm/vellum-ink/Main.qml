import QtQuick
import QtQml
import QtQuick.Window
import "." as Ink

// Vellum Shell "Vellum Ink" greeter, a zarolokepernyo vizualis nyelve.
// SDDM-re forditva: elhomalyosodo hatterkep, nagy ora, panel-kartya, azonos
// paletta -- kiegeszitve azzal, amit csak a greeter tud: felhasznalo- es
// munkamenet-valaszto, billentyuzetkiosztas es energia-muveletek.
Item {
    id: root

    width: 1920
    height: 1080

    // --- szinek a theme.conf-bol, a lockscreen palettajaval megegyezoen ---
    readonly property color background: config.colorBackground || "#1f1f28"
    readonly property color foreground: config.colorForeground || "#dcd7ba"
    readonly property color accent: config.colorAccent || "#c34043"
    readonly property color surface: config.colorSurface || "#2a2a37"
    readonly property color muted: config.colorMuted || "#727169"
    readonly property color alertColor: config.colorAlert || "#d7472f"
    // A shell palettajaban a `MUTED` a halvanyabb kontur, a `LIGHT_FOREGROUND`
    // a szoveg. A theme.conf `colorMuted`-je a MUTED-bol jon, tehat mindketto
    // szerepere ez all a legkozelebb.
    readonly property color outline: muted
    readonly property string themeName: config.themeName || ""

    // A greeter sajat hatterkep-peldanya, a tema mappajahoz kepest. A /home
    // tipikusan 0700, ezert az sddm felhasznalo nem erne el az eredetit -- a
    // temamotor ir ide egy kicsinyitett masolatot minden temavaltaskor. Ha
    // hianyzik, az InkBackground a temaszinre es az ensō vizjelre esik vissza.
    readonly property string wallpaper: {
        var name = config.background || ""
        // A theme.conf-ot a temamotor irja. Ha a futo daemon meg egy regebbi
        // binaris, a `{{...}}` helyorzo feloldatlanul maradhat a fajlban --
        // olyat ne adjunk az Image-nek, mert a greeter csak hibat logol.
        return name.indexOf("{{") >= 0 ? "" : name
    }

    // Tobb kijelzo eseten csak egy kepernyore kerul a bejelentkezo kartya.
    // A valasztott monitor a shell lockscreenjevel egyezik, mert a greeter sajat
    // "primary" kepernyoje a kimenet-sorrendbol jon, nem a felhasznalo dontesebol.
    //
    // FONTOS: a connector nevere NEM lehet epiteni. Ez a greeter sajat X
    // szervere alatt fut, ami mas neveket ad ugyanarra a kijelzore, mint a
    // Wayland munkamenet (amdgpu alatt pl. HDMI-A-1 helyett HDMI-A-0, DP-2
    // helyett DisplayPort-1 -- meg az indexeles is eltolodik). Ezert elsodlegesen
    // az EDID sorozatszamra parositunk: az mindket oldalon ugyanaz.
    readonly property string screenName: Screen.name || ""
    readonly property string screenSerial: Screen.serialNumber || ""
    readonly property string screenModel: Screen.model || ""

    readonly property string configuredScreen: config.inputScreen || ""
    readonly property string configuredSerial: config.inputScreenSerial || ""
    readonly property string configuredModel: config.inputScreenModel || ""

    // Csak akkor tamaszkodunk egy azonositora, ha az tenyleg megtalalhato a
    // kepernyok kozott -- kulonben sehol nem jelenne meg a kartya.
    //
    // A sorozatszam a legpontosabb, de a Qt nem minden platformon tolti ki
    // (Waylanden merve ures volt, X11 alatt a RANDR EDID-bol jonnie kellene),
    // ezert a modell a gyakorlati tartalek.
    readonly property bool serialUsable: configuredSerial !== ""
        && screenSerials.indexOf(configuredSerial) >= 0
    // A modell csak akkor donthet, ha egyedi: ket azonos tipusu monitornal nem
    // kulonboztetne meg oket, olyankor inkabb tovabblepunk a nevre.
    readonly property bool modelUsable: !serialUsable && configuredModel !== ""
        && countOf(screenModels, configuredModel) === 1
    readonly property bool nameUsable: !serialUsable && !modelUsable
        && configuredScreen !== "" && screenNames.indexOf(configuredScreen) >= 0

    readonly property bool fallbackPrimary: (typeof primaryScreen === "undefined") ? true : primaryScreen
    // A kartya kepernyoje kizarolag a beallitastol fugg. (Ablakaktivitasra nem
    // lehet epiteni: layer-shell/offscreen alatt egyik greeter ablak sem jelzi
    // magat aktivnak, olyankor sehol nem jelenne meg a kartya.) A billentyuzet
    // fokusz esetleges elcsuszasat az InkAmbient rejtett beviteli mezoje fogja el.
    readonly property bool isPrimary: serialUsable
        ? screenSerial === configuredSerial
        : (modelUsable
            ? screenModel === configuredModel
            : (nameUsable ? screenName === configuredScreen : fallbackPrimary))

    // Az SDDM screenModel-je ablakonkent csak a sajat kepernyot tartalmazza,
    // ezert a teljes listat a QGuiApplication-tol kerjuk el.
    readonly property var screenNames: collect(function (s) { return s.name })
    readonly property var screenSerials: collect(function (s) { return s.serialNumber })
    readonly property var screenModels: collect(function (s) { return s.model })

    function collect(pick) {
        var values = []
        var screens = Qt.application.screens
        for (var i = 0; i < screens.length; i++) values.push(pick(screens[i]) || "")
        return values
    }

    function countOf(values, wanted) {
        var count = 0
        for (var i = 0; i < values.length; i++) {
            if (values[i] === wanted) count++
        }
        return count
    }

    // --- allapot ---
    property string password: ""
    property bool busy: false
    property bool failed: false
    property bool closing: false
    // A kilepes ket utemu: eloszor a kartya tunik el, csak utana enged fel a
    // dermedt hatter -- ugyanaz a koreografia, mint a zarolokepernyon.
    property bool thawing: false
    property bool ready: false
    property int revealStep: 0
    property string statusText: "Enter password"
    property var currentTime: new Date()

    // Egyszerre csak egy legordulo lista lehet nyitva: "" | "user" | "session"
    property string openPicker: ""

    property var users: []
    property var sessions: []
    property int userIndex: 0
    property int sessionIndex: 0

    readonly property string userName: (userIndex >= 0 && userIndex < users.length) ? users[userIndex].name : (userModel.lastUser || "")
    readonly property string userLabel: (userIndex >= 0 && userIndex < users.length) ? users[userIndex].label : (userModel.lastUser || "user")
    readonly property bool userNeedsPassword: (userIndex >= 0 && userIndex < users.length) ? users[userIndex].needsPassword : true
    readonly property string sessionLabel: (sessionIndex >= 0 && sessionIndex < sessions.length) ? sessions[sessionIndex].label : ""

    readonly property string hostText: (typeof sddm !== "undefined" && sddm.hostName) ? sddm.hostName : ""

    // --- ora, ugyanaz a formazas mint a LockRoot-ban ---
    readonly property var dayNames: ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"]
    readonly property var monthNames: ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]

    readonly property int weekdayIndex: (currentTime.getDay() + 6) % 7
    readonly property string timeText: two(currentTime.getHours()) + ":" + two(currentTime.getMinutes())
    readonly property string secondsText: two(currentTime.getSeconds())
    readonly property string weekdayText: dayNames[weekdayIndex]
    readonly property string dateText: monthNames[currentTime.getMonth()] + " " + currentTime.getDate() + " " + currentTime.getFullYear()
    readonly property real dayProgress: (currentTime.getHours() * 3600 + currentTime.getMinutes() * 60 + currentTime.getSeconds()) / 86400

    function two(value) {
        return value < 10 ? "0" + value : "" + value
    }

    function clearPassword() {
        if (busy) return
        password = ""
    }

    function tryLogin() {
        if (busy || closing) return
        if (userName === "") {
            failed = true
            statusText = "No user available"
            return
        }
        if (userNeedsPassword && password === "") return

        busy = true
        failed = false
        statusText = "Checking..."
        sddm.login(userName, password, sessionIndex)
    }

    function selectUser(index) {
        if (index < 0 || index >= users.length) return
        userIndex = index
        password = ""
        failed = false
        statusText = "Enter password"
    }

    function selectSession(index) {
        if (index < 0 || index >= sessions.length) return
        sessionIndex = index
    }

    // Az Instantiator minden modellsort peldanyosit, igy sima JS tombbe
    // gyujthetjuk a megjeleniteshez szukseges mezoket.
    function rebuildUsers() {
        var list = []
        for (var i = 0; i < userItems.count; i++) {
            var item = userItems.objectAt(i)
            if (!item) continue
            list.push({
                name: item.name,
                label: (item.realName && item.realName.length > 0) ? item.realName : item.name,
                needsPassword: item.needsPassword
            })
        }
        users = list
        if (userIndex >= list.length) userIndex = 0
    }

    function rebuildSessions() {
        var list = []
        for (var i = 0; i < sessionItems.count; i++) {
            var item = sessionItems.objectAt(i)
            if (!item) continue
            list.push({
                label: item.name,
                comment: item.comment
            })
        }
        sessions = list
        if (sessionIndex >= list.length) sessionIndex = 0
    }

    Component.onCompleted: {
        rebuildUsers()
        rebuildSessions()
        userIndex = Math.max(0, Math.min(users.length - 1, userModel.lastIndex))
        sessionIndex = Math.max(0, Math.min(sessions.length - 1, sessionModel.lastIndex))
        introTimer.start()
    }

    Instantiator {
        id: userItems

        model: userModel
        delegate: QtObject {
            required property string name
            required property string realName
            required property bool needsPassword
        }

        onObjectAdded: root.rebuildUsers()
        onObjectRemoved: root.rebuildUsers()
    }

    Instantiator {
        id: sessionItems

        model: sessionModel
        delegate: QtObject {
            required property string name
            required property string comment
        }

        onObjectAdded: root.rebuildSessions()
        onObjectRemoved: root.rebuildSessions()
    }

    Connections {
        target: sddm

        function onLoginSucceeded() {
            root.busy = false
            root.statusText = "Welcome"
            root.closing = true
            thawTimer.start()
        }

        function onLoginFailed() {
            root.busy = false
            root.failed = true
            root.password = ""
            root.statusText = "Wrong password"
        }

        function onInformationMessage(message) {
            root.busy = false
            root.failed = true
            root.statusText = message
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = new Date()
    }

    Timer {
        id: introTimer
        interval: 60
        onTriggered: {
            root.ready = true
            revealTimer.start()
        }
    }

    // Lepcsozetes megjelenes: 1 = a hatter fagy be, 2 = ora, 3 = kartya,
    // 4 = beviteli mezo, valasztok es a rendszermuveletek.
    Timer {
        id: revealTimer
        interval: 110
        repeat: true
        onTriggered: {
            root.revealStep += 1
            if (root.revealStep >= 4) revealTimer.stop()
        }
    }

    // A kartya eltunese utan enged fel a dermedes: a greeter utolso kepe igy
    // mar a tiszta hatterkep, nem egy fatyolos, vignettas lap.
    Timer {
        id: thawTimer
        interval: 130
        onTriggered: root.thawing = true
    }

    Ink.InkBackground {
        anchors.fill: parent
        greeter: root
    }

    Loader {
        anchors.fill: parent
        active: root.isPrimary
        sourceComponent: Ink.InkCard { greeter: root }
    }

    Loader {
        anchors.fill: parent
        active: !root.isPrimary
        sourceComponent: Ink.InkAmbient { greeter: root }
    }

}

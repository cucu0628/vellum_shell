pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

// A settings app allapota es minden backend-hivasa. Az `AppearanceController`
// mintajat koveti: a nezet vekony, a logika itt van.
//
// A Hyprland ertekek harom helyrol jonnek ossze:
//   * `hypr/read`   -- az elo ertekek, ezt mutatjak a vezerlok;
//   * `hypr/monitors` -- a csatlakoztatott kijelzok;
//   * a lokalis `pendingOptions` -- amit a felhasznalo epp elallitott, de a
//     backend meg nem igazolta vissza. Enelkul a csuszka visszaugrana a regi
//     ertekre minden mozgatas kozben.
Item {
    id: controller

    required property var backend
    property var theme: null
    property bool opened: false
    property string activePage: "display"

    property var monitors: []
    property var options: ({})
    property var pendingOptions: ({})
    property var optionWrites: ({})
    property int writeGeneration: 0
    property bool backendAvailable: false
    property bool loading: false
    property int loadGeneration: 0

    // Egy monitor sem lehet kivalasztva, amig a lista be nem tolt.
    property string selectedOutput: ""

    readonly property var selectedMonitor: {
        for (var i = 0; i < monitors.length; i++) {
            if (monitors[i].name === selectedOutput)
                return monitors[i];

        }
        return monitors.length > 0 ? monitors[0] : null;
    }

    width: 0
    height: 0
    visible: false

    // Lazy topic: a backend csak akkor figyeli a Hyprland esemenyeit, amig az
    // ablak nyitva van. Ez inditja el a modul `run` hurkat is, ami kiirja a
    // generalt Lua modulokat.
    onOpenedChanged: {
        if (!backend)
            return ;

        if (opened) {
            backend.subscribe("hypr");
            reload();
        } else {
            // Egy meg nem erositett kijelzovaltas nem maradhat allva csak
            // azert, mert bezartuk az ablakot. A backend orajat ez csak
            // megelozi -- az ugyanigy visszaallitana.
            revertPreview();
            backend.unsubscribe("hypr");
        }
    }

    Component.onDestruction: if (backend && opened) backend.unsubscribe("hypr")

    // Monitor hotplug es `hyprctl reload` eseten a backend magatol tolja az uj
    // allapotot; a sajat, meg nem nyugtazott ertekeinket viszont nem dobjuk el.
    function applyTopic(data) {
        if (!data)
            return ;

        if (data.available !== undefined)
            backendAvailable = data.available === true;
        if (data.monitors !== undefined) {
            monitors = data.monitors;
            if (selectedOutput === "" && monitors.length > 0)
                selectedOutput = monitors[0].name;

        }
        if (data.options !== undefined) {
            options = data.options;
        }
    }

    Connections {
        function onTopicUpdated(topic, data) {
            if (topic === "hypr")
                controller.applyTopic(data);

        }

        target: controller.backend
    }

    function reload() {
        loadGeneration++;
        loading = true;
        var generation = loadGeneration;

        backend.call("hypr", "read", {}, (result, error) => {
            if (generation !== controller.loadGeneration) return
            controller.loading = false
            if (error) {
                console.warn("Settings: a Hyprland opciok nem olvashatoak:", error.message)
                controller.backendAvailable = false
                return
            }
            // Hyprland nelkul a modul udvariasan ures objektumot ad vissza.
            // Ez nem irhato allapot, ezert a kompozitor-oldalakat letiltjuk.
            controller.backendAvailable = result && Object.keys(result).length > 0
            controller.options = result || ({})
            controller.pendingOptions = ({})
        })

        backend.call("hypr", "monitors", {}, (result, error) => {
            if (generation !== controller.loadGeneration) return
            if (error) {
                console.warn("Settings: a monitorok nem olvashatoak:", error.message)
                return
            }
            controller.monitors = result || []
            if (controller.selectedOutput === "" && controller.monitors.length > 0)
                controller.selectedOutput = controller.monitors[0].name
        })
    }

    // Az elo ertek, kiveve ha epp allitjuk -- akkor a sajat, meg nem nyugtazott
    // ertekunk nyer.
    function optionValue(key, fallback) {
        if (pendingOptions[key] !== undefined)
            return pendingOptions[key];

        return options[key] !== undefined ? options[key] : fallback;
    }

    function optionNumber(key, fallback) {
        var value = optionValue(key, fallback);
        var number = Number(value);
        return isNaN(number) ? fallback : number;
    }

    function optionBool(key, fallback) {
        var value = optionValue(key, fallback);
        return value === true || value === "true" || value === 1;
    }

    function optionText(key, fallback) {
        var value = optionValue(key, fallback);
        return value === undefined || value === null ? fallback : value.toString();
    }

    // Optimista frissites: a vezerlo azonnal az uj erteket mutatja, a backend
    // valasza csak megerositi. Igy a csuszka nem ugral huzas kozben.
    function previewOption(key, value) {
        var next = Object.assign({}, pendingOptions);
        next[key] = value;
        pendingOptions = next;
    }

    function setOption(key, value) {
        previewOption(key, value);
        writeGeneration++;
        var generation = writeGeneration;
        var writes = Object.assign({}, optionWrites);
        writes[key] = generation;
        optionWrites = writes;
        var values = {};
        values[key] = value;
        backend.call("hypr", "setOptions", {
            "values": values
        }, (result, error) => {
            if (error) {
                console.warn("Settings: a(z)", key, "nem allithato:", error.message)
                // A sikertelen irast nem tartjuk fenn: essen vissza az elore.
                if (controller.optionWrites[key] === generation)
                    controller.finishOptionWrite(key)
                return
            }
            if (result && result.options)
                controller.options = Object.assign({}, controller.options, result.options)
            if (controller.optionWrites[key] === generation)
                controller.finishOptionWrite(key)
        })
    }

    function finishOptionWrite(key) {
        var nextPending = Object.assign({}, pendingOptions);
        delete nextPending[key];
        pendingOptions = nextPending;

        var nextWrites = Object.assign({}, optionWrites);
        delete nextWrites[key];
        optionWrites = nextWrites;
    }

    // -- kijelzo-elonezet ----------------------------------------------------
    //
    // A tranzakciot a backend birtokolja: a `previewMonitors` eloben alkalmaz,
    // de nem ment, es megerosites nelkul magatol visszaall. Itt csak a tokent
    // es a visszaszamlalast tukrozzuk.
    //
    // Azert itt es nem a DisplayPage-ben: ez a controller az ablak szintjen el,
    // igy egy oldalvaltas nem viszi magaval. Az ablak bezarasat pedig mar a
    // backend oraja fedi -- korabban a Timerrel egyutt a visszaallitas is
    // eltunt, es egy rossz monitorbeallitas veglegesse valt.
    property string previewToken: ""
    property int previewSeconds: 0
    property bool previewBusy: false

    signal previewFailed(string message)

    // Egy egesz elrendezes egyetlen hivasban: a kijelzok pozicioja egymashoz
    // kepest ertelmes, ezert felig alkalmazott allapot nem maradhat utanunk.
    function previewMonitors(settings, callback) {
        if (previewBusy)
            return;

        previewBusy = true;
        backend.call("hypr", "previewMonitors", {
            "monitors": settings
        }, (result, error) => {
            controller.previewBusy = false
            if (error) {
                console.warn("Settings: a kijelzo nem allithato:", error.message)
                controller.previewFailed(error.message || "a kijelzo nem allithato")
                controller.reload()
                if (callback)
                    callback(false)
                return
            }
            controller.previewToken = result && result.token ? result.token : ""
            controller.previewSeconds = Math.max(1, Math.round((result && result.timeoutMs ? result.timeoutMs : 12000) / 1000))
            controller.reload()
            if (callback)
                callback(true)
        })
    }

    function confirmPreview() {
        var token = previewToken;
        if (token === "")
            return;

        clearPreview();
        backend.call("hypr", "confirmMonitors", {
            "token": token
        }, (result, error) => {
            if (error)
                console.warn("Settings: a kijelzobeallitas nem mentheto:", error.message)
            controller.reload()
        })
    }

    function revertPreview() {
        var token = previewToken;
        if (token === "")
            return;

        clearPreview();
        backend.call("hypr", "revertMonitors", {
            "token": token
        }, (result, error) => {
            if (error)
                console.warn("Settings: a visszaallitas nem sikerult:", error.message)
            controller.reload()
        })
    }

    function clearPreview() {
        previewToken = "";
        previewSeconds = 0;
    }

    // Csak tukor: a tenyleges visszaallitast a backend vegzi, akkor is, ha ez
    // az ablak addigra eltunt.
    Timer {
        id: previewTimer

        interval: 1000
        repeat: true
        running: controller.previewToken !== ""
        onTriggered: {
            controller.previewSeconds--;
            if (controller.previewSeconds <= 0) {
                controller.clearPreview();
                controller.reload();
            }
        }
    }

    function resetScope(scope) {
        backend.call("hypr", "reset", {
            "scope": scope
        }, (result, error) => {
            if (error) {
                console.warn("Settings: a visszaallitas nem sikerult:", error.message)
                return
            }
            controller.pendingOptions = ({})
            controller.optionWrites = ({})
            controller.reload()
        })
    }

    // A settings app tobb oldala kulso parancsot indit (TUI telepitok,
    // nm-connection-editor). Egy kozos Process eleg: ezek mind rovid, egyszerre
    // egy fut, es a kimenetuk a sajat ablakukban jelenik meg.
    function run(command) {
        runProcess.running = false;
        runProcess.command = ["sh", "-c", command];
        runProcess.running = true;
    }

    Process {
        id: runProcess
    }

}

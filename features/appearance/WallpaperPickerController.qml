import QtQuick

// A hatterkep-valaszto allapota.
//
// Bongeszes kozben semmi nem valtozik: a carousel maga az elonezet. Enterre
// (vagy a kijelolt kartyara kattintva) a valodi hatterkep-ablakok azonnal
// atallnak, a backend pedig rogziti a valasztast. A temahoz nem nyul -- kiveve
// a dinamikus temat, ami a kepbol szuletik, ezert azt ujra kell szamolni.
Item {
    id: controller

    required property var backend
    property var theme: null
    property var wallpaperController: null
    // Igaz, amig a valaszto latszik es ez a nezet az aktiv.
    property bool active: false

    property var items: []
    property string query: ""
    property int currentIndex: 0
    property int confirmingIndex: -1
    property bool applying: false
    property bool loaded: false
    property int loadGeneration: 0

    readonly property var visibleItems: filterItems(items, query)
    readonly property var currentEntry: visibleItems.length > 0
        ? visibleItems[Math.max(0, Math.min(currentIndex, visibleItems.length - 1))]
        : null

    // A backend `DYNAMIC_SLUG` allandoja: ennel a temanal a paletta a kepet koveti.
    readonly property string dynamicSlug: "dynamic-matugen"

    // A megerosites animacioja utan kerjuk a bezarast.
    signal closeRequested

    width: 0
    height: 0
    visible: false

    onActiveChanged: if (active) begin()

    function begin() {
        confirmingIndex = -1
        query = ""
        load()
    }

    function load() {
        loadGeneration++
        var generation = loadGeneration
        backend.call("theme", "wallpapers", {}, (result, error) => {
            if (generation !== controller.loadGeneration) return
            controller.loaded = true
            if (error) {
                console.warn("Appearance: a hatterkepek nem olvashatoak:", error.message)
                controller.items = []
                return
            }
            controller.applyItems(result || [])
        })
    }

    function release() {
        loadGeneration++
        items = []
        loaded = false
    }

    function applyItems(list) {
        var current = wallpaperController ? wallpaperController.currentWallpaper : ""
        var index = 0
        for (var i = 0; i < list.length; i++) {
            if (list[i].path === current || (current === "" && list[i].current)) index = i
        }
        items = list
        currentIndex = index
    }

    function filterItems(list, text) {
        var needle = (text || "").trim().toLowerCase()
        if (needle === "") return list
        return list.filter(item => item.name.toLowerCase().indexOf(needle) !== -1)
    }

    // A szures nem ugraltatja el a kijelolest, ha a kep tovabbra is latszik.
    function setQuery(text) {
        var keep = currentEntry ? currentEntry.path : ""
        query = text
        var next = 0
        for (var i = 0; i < visibleItems.length; i++) {
            if (visibleItems[i].path === keep) next = i
        }
        currentIndex = next
    }

    function select(index) {
        if (visibleItems.length === 0 || confirmingIndex >= 0) return
        currentIndex = Math.max(0, Math.min(index, visibleItems.length - 1))
    }

    // A ket vegen korbefordul: a carousel nem er veget.
    function step(delta) {
        var count = visibleItems.length
        if (count === 0 || confirmingIndex >= 0) return
        currentIndex = ((currentIndex + delta) % count + count) % count
    }

    function isCurrent(entry) {
        return !!entry && !!wallpaperController && entry.path === wallpaperController.currentWallpaper
    }

    function pick() {
        var entry = currentEntry
        if (!entry || confirmingIndex >= 0) return
        if (isCurrent(entry)) {
            closeRequested()
            return
        }

        confirmingIndex = currentIndex
        applying = true

        var previous = wallpaperController ? wallpaperController.currentWallpaper : ""
        if (wallpaperController) wallpaperController.setCurrentWallpaper(entry.path)

        var dynamic = !!theme && theme.slug === dynamicSlug
        var method = dynamic ? "apply" : "setWallpaper"
        var params = dynamic ? { slug: dynamicSlug, wallpaper: entry.path } : { path: entry.path }

        backend.call("theme", method, params, (result, error) => {
            controller.applying = false
            if (!error) return
            // Ne maradjon az asztalon olyan kep, amit a backend nem rogzitett.
            console.warn("Appearance: a hatterkep nem allithato be:", error.message)
            if (controller.wallpaperController && previous !== "")
                controller.wallpaperController.setCurrentWallpaper(previous)
        })

        confirmTimer.restart()
    }

    Timer {
        id: confirmTimer
        interval: 320
        onTriggered: controller.closeRequested()
    }
}

import QtQuick

// A temavalaszto allapota.
//
// Bongeszes kozben semmi nem kerul lemezre: a ThemeStore ratolja a jelolt
// szineket az elo palettara, igy a bar es maga a valaszto mar az uj temaban
// latszik. A `theme apply` (generatorok, portal ujrainditas) csak Enterre fut;
// barmilyen mas kilepes visszaallitja az eredeti szineket.
Item {
    id: controller

    required property var backend
    property var theme: null
    property var wallpaperController: null
    property bool active: false

    property var items: []
    property int currentIndex: 0
    property int confirmingIndex: -1
    property bool applying: false
    // Enter utan a bezaras mar nem allithatja vissza az elonezetet.
    property bool committed: false
    property bool loaded: false
    property string originalSlug: ""
    property int loadGeneration: 0
    property int previewGeneration: 0

    readonly property var visibleItems: items
    readonly property var currentEntry: items.length > 0
        ? items[Math.max(0, Math.min(currentIndex, items.length - 1))]
        : null

    signal closeRequested

    width: 0
    height: 0
    visible: false

    onActiveChanged: {
        if (active) begin()
        else if (!committed) restoreOriginal()
    }

    onCurrentEntryChanged: if (active && !committed) previewNow()

    function begin() {
        committed = false
        confirmingIndex = -1
        originalSlug = theme && theme.slug ? theme.slug : ""
        load()
    }

    function load() {
        loadGeneration++
        var generation = loadGeneration
        backend.call("theme", "list", {}, (result, error) => {
            if (generation !== controller.loadGeneration) return
            controller.loaded = true
            if (error) {
                console.warn("Appearance: a temak nem olvashatoak:", error.message)
                controller.items = []
                return
            }
            controller.applyItems(result || [])
        })
    }

    function release() {
        loadGeneration++
        previewGeneration++
        items = []
        loaded = false
    }

    function applyItems(list) {
        var index = 0
        for (var i = 0; i < list.length; i++) {
            if (list[i].slug === originalSlug || (originalSlug === "" && list[i].current)) index = i
        }
        if (originalSlug === "" && list.length > 0) originalSlug = list[index].slug
        items = list
        currentIndex = index
    }

    function select(index) {
        if (items.length === 0 || confirmingIndex >= 0) return
        currentIndex = Math.max(0, Math.min(index, items.length - 1))
    }

    function step(delta) {
        var count = items.length
        if (count === 0 || confirmingIndex >= 0) return
        currentIndex = ((currentIndex + delta) % count + count) % count
    }

    function isCurrent(entry) {
        return !!entry && entry.slug === originalSlug
    }

    // A jelolt tema latvanya: csak a shell sajat szinei. Semmi lemez, semmi
    // kulso alkalmazas.
    function previewNow() {
        var entry = currentEntry
        if (!theme || !entry) return

        if (entry.kind === "dynamic") {
            // A dinamikus paletta a kepbol szuletik: a backend szamolja ki,
            // iras nelkul. Kep nelkul nincs mibol, olyankor marad az elozo.
            dynamicPreviewTimer.restart()
            return
        }

        previewGeneration++
        dynamicPreviewTimer.stop()
        theme.setPreview({
            BACKGROUND: entry.background,
            FOREGROUND: entry.foreground,
            ACCENT: entry.accent,
            SURFACE: entry.surface,
            LIGHT_FOREGROUND: entry.muted
        })
    }

    function requestDynamicPreview() {
        var wallpaper = wallpaperController ? wallpaperController.currentWallpaper : ""
        if (!theme || wallpaper === "" || !currentEntry || currentEntry.kind !== "dynamic") return

        previewGeneration++
        var generation = previewGeneration
        backend.call("theme", "preview", { wallpaper: wallpaper }, (result, error) => {
            if (generation !== controller.previewGeneration || controller.committed) return
            if (error) {
                console.warn("Appearance: a dinamikus paletta nem szamolhato:", error.message)
                return
            }
            if (controller.theme && result && result.colors) controller.theme.setPreview(result.colors)
        })
    }

    function restoreOriginal() {
        previewGeneration++
        dynamicPreviewTimer.stop()
        if (theme) theme.setPreview({})
    }

    // A tema rakerul mindenre (GTK, kitty, btop, ikonok, Zen, greeter...). Az
    // elonezet a helyen marad, amig a backend ki nem tolja az igazi palettat,
    // igy a shell nem villan.
    function pick() {
        var entry = currentEntry
        if (!entry || confirmingIndex >= 0) return
        if (isCurrent(entry)) {
            closeRequested()
            return
        }

        committed = true
        applying = true
        confirmingIndex = currentIndex

        backend.call("theme", "apply", { slug: entry.slug }, (result, error) => {
            controller.applying = false
            if (!error) return
            // Bezarva mar nincs hova kiirni a hibat, ezert legalabb ne hagyjuk
            // az asztalt hazug allapotban: vissza az eredetire.
            console.warn("Appearance: a tema nem alkalmazhato:", error.message)
            controller.restoreOriginal()
        })

        confirmTimer.restart()
    }

    Timer {
        id: dynamicPreviewTimer
        interval: 180
        onTriggered: controller.requestDynamicPreview()
    }

    Timer {
        id: confirmTimer
        interval: 320
        onTriggered: controller.closeRequested()
    }
}

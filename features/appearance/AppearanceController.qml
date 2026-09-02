import QtQuick

// A Studio allapota.
//
// Bongeszes kozben semmi nem kerul lemezre: a ThemeStore ratolja a jelolt
// szineket az elo palettara, a WallpaperController pedig atallitja a valodi
// hatterkep-ablakokat. Igy a kepernyon a sajat asztal latszik az uj temaban --
// nincs szukseg mock feluletre.
//
// A `theme apply` (nyolc generator, portal ujrainditas) csak Enterre fut le.
Item {
    id: controller

    required property var backend
    property var theme: null
    property var wallpaperController: null
    property bool opened: false
    // Csak azt jelzi, melyik sav miatt nyilt meg a felulet (`style wallpaper`
    // vs `style theme`). Mindket sav mindig mukodik, nincs szekciovaltas.
    property string mode: "wallpaper"
    property var themeItems: []
    property var wallpaperItems: []
    property int selectedThemeIndex: 0
    property int selectedWallpaperIndex: 0
    property bool applying: false
    property int loadGeneration: 0
    property int previewGeneration: 0

    // Amivel a felulet nyilt. Escape ide all vissza.
    property string originalSlug: ""
    property string originalWallpaper: ""

    readonly property var selectedTheme: themeItems.length > 0 ? themeItems[Math.max(0, Math.min(selectedThemeIndex, themeItems.length - 1))] : null
    readonly property var selectedWallpaper: wallpaperItems.length > 0 ? wallpaperItems[Math.max(0, Math.min(selectedWallpaperIndex, wallpaperItems.length - 1))] : null

    // A ketto fuggetlenul is valtozhat. Korabban mindketto meglete kellett,
    // ezert ures `~/Pictures/wallpapers` mappaval a temavaltas nemaan
    // elnyelodott -- pont a friss telepites allapotaban.
    readonly property bool dirty: (!!selectedTheme && selectedTheme.slug !== originalSlug)
        || (!!selectedWallpaper && selectedWallpaper.path !== originalWallpaper)

    signal focusRequested
    signal dockToggleRequested

    width: 0
    height: 0
    visible: false

    onOpenedChanged: {
        if (opened) {
            applying = false
            originalSlug = theme && theme.slug ? theme.slug : ""
            originalWallpaper = wallpaperController ? wallpaperController.currentWallpaper : ""
            loadItems()
            focusRequested()
        } else if (!applying) {
            // A PopupCoordinator kivulrol is zarhat (masik felulet nyilik).
            // Olyankor sem maradhat az asztalon egy sosem commitolt elonezet.
            restoreOriginal()
        }
    }

    function loadItems() {
        loadGeneration++
        themeItems = []
        wallpaperItems = []

        var generation = loadGeneration
        backend.call("theme", "list", {}, (result, error) => {
            if (generation !== controller.loadGeneration || !controller.opened) return
            if (error) {
                console.warn("Appearance: a temak nem olvashatoak:", error.message)
                return
            }
            controller.applyThemes(result || [])
        })
        backend.call("theme", "wallpapers", {}, (result, error) => {
            if (generation !== controller.loadGeneration || !controller.opened) return
            if (error) {
                console.warn("Appearance: a hatterkepek nem olvashatoak:", error.message)
                return
            }
            controller.applyWallpapers(result || [])
        })
    }

    function releaseResources() {
        loadGeneration++
        previewGeneration++
        themeItems = []
        wallpaperItems = []
    }

    function applyThemes(items) {
        var currentIndex = 0
        for (var i = 0; i < items.length; i++) {
            if (items[i].current) {
                currentIndex = i
                if (originalSlug === "") originalSlug = items[i].slug
            }
        }
        selectedThemeIndex = currentIndex
        themeItems = items
    }

    function applyWallpapers(items) {
        var currentIndex = 0
        for (var i = 0; i < items.length; i++) {
            if (items[i].current) {
                currentIndex = i
                if (originalWallpaper === "") originalWallpaper = items[i].path
            }
        }
        selectedWallpaperIndex = currentIndex
        wallpaperItems = items
    }

    function imageSource(path) {
        if (!path) return ""
        if (path.startsWith("file:")) return path
        return path.startsWith("/") ? "file://" + path : ""
    }

    function selectWallpaper(index) {
        if (wallpaperItems.length === 0) return
        selectedWallpaperIndex = Math.max(0, Math.min(index, wallpaperItems.length - 1))
    }

    function selectPalette(index) {
        if (themeItems.length === 0) return
        selectedThemeIndex = Math.max(0, Math.min(index, themeItems.length - 1))
    }

    function moveWallpaper(delta) { selectWallpaper(selectedWallpaperIndex + delta) }
    function movePalette(delta) { selectPalette(selectedThemeIndex + delta) }

    function selectDynamicTheme() {
        for (var i = 0; i < themeItems.length; i++) {
            if (themeItems[i].kind === "dynamic") {
                selectPalette(i)
                return
            }
        }
    }

    // A valasztas latvanya: csak a shell sajat szinei es a hatterkep-ablakok.
    // Minden in-process, semmi lemez, semmi kulso alkalmazas.
    function previewNow() {
        if (selectedWallpaper && wallpaperController)
            wallpaperController.setCurrentWallpaper(selectedWallpaper.path)
        if (!theme || !selectedTheme) return

        if (selectedTheme.kind === "dynamic") {
            // A dinamikus paletta a kepbol szuletik: a backend szamolja ki,
            // iras nelkul. Addig nem villantjuk fel a regi szineket. Kep nelkul
            // nincs mibol szamolni, olyankor marad az elozo elonezet.
            if (!selectedWallpaper) return
            dynamicPreviewTimer.restart()
            return
        }

        previewGeneration++
        dynamicPreviewTimer.stop()
        theme.setPreview({
            BACKGROUND: selectedTheme.background,
            FOREGROUND: selectedTheme.foreground,
            ACCENT: selectedTheme.accent,
            SURFACE: selectedTheme.surface,
            LIGHT_FOREGROUND: selectedTheme.muted
        })
    }

    function requestDynamicPreview() {
        if (!theme || !selectedWallpaper || !selectedTheme || selectedTheme.kind !== "dynamic") return

        previewGeneration++
        var generation = previewGeneration
        backend.call("theme", "preview", { wallpaper: selectedWallpaper.path }, (result, error) => {
            if (generation !== controller.previewGeneration) return
            if (error) {
                console.warn("Appearance: a dinamikus paletta nem szamolhato:", error.message)
                return
            }
            if (controller.theme && result && result.colors) controller.theme.setPreview(result.colors)
        })
    }

    // Az elonezet elengedese: a ThemeStore visszaall a backend palettajara, a
    // hatterkep pedig arra, amivel a felulet nyilt.
    function restoreOriginal() {
        previewGeneration++
        dynamicPreviewTimer.stop()
        if (theme) theme.setPreview({})
        if (wallpaperController && originalWallpaper !== "") wallpaperController.setCurrentWallpaper(originalWallpaper)
    }

    // Enter: a tema rakerul mindenre (GTK, kitty, btop, ikonok, Zen, SDDM...),
    // a felulet pedig bezarul. Az elonezet a helyen marad, amig a backend ki nem
    // tolja az igazi palettat, igy a shell nem villan.
    function applyAndClose() {
        if (applying) return

        if (!dirty || !selectedTheme) {
            opened = false
            return
        }

        applying = true
        var previousSlug = originalSlug
        var previousWallpaper = originalWallpaper

        // Hatterkep nelkul a `wallpaper` kulcsot el sem kuldjuk: a backend
        // olyankor a mar rogzitett kepnel marad, ahelyett hogy torolne.
        var params = { slug: selectedTheme.slug }
        if (selectedWallpaper) params.wallpaper = selectedWallpaper.path

        backend.call("theme", "apply", params, (result, error) => {
            controller.applying = false
            if (!error) return

            // Bezarva mar nincs hova kiirni a hibat, ezert legalabb ne hagyjuk
            // az asztalt hazug allapotban: vissza az eredetire.
            console.warn("Appearance: a tema nem alkalmazhato:", error.message)
            controller.originalSlug = previousSlug
            controller.originalWallpaper = previousWallpaper
            controller.restoreOriginal()
        })

        opened = false
    }

    function cancelAndClose() {
        restoreOriginal()
        opened = false
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            cancelAndClose()
            event.accepted = true
        } else if (event.key === Qt.Key_Left || (event.key === Qt.Key_H && event.modifiers === Qt.ControlModifier)) {
            moveWallpaper(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Right || (event.key === Qt.Key_L && event.modifiers === Qt.ControlModifier)) {
            moveWallpaper(1)
            event.accepted = true
        } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_K && event.modifiers === Qt.ControlModifier)) {
            movePalette(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_J && event.modifiers === Qt.ControlModifier)) {
            movePalette(1)
            event.accepted = true
        } else if (event.key === Qt.Key_D) {
            selectDynamicTheme()
            event.accepted = true
        } else if (event.key === Qt.Key_Space) {
            dockToggleRequested()
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            applyAndClose()
            event.accepted = true
        }
    }

    onSelectedThemeChanged: if (opened) previewNow()
    onSelectedWallpaperChanged: if (opened) previewNow()

    Timer {
        id: dynamicPreviewTimer
        interval: 180
        onTriggered: controller.requestDynamicPreview()
    }
}

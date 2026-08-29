import QtQuick

Item {
    id: controller

    required property var backend
    property var theme: null
    property var wallpaperController: null
    property bool opened: false
    property string mode: "wallpaper"
    property string activeSection: "wallpaper"
    property var themeItems: []
    property var wallpaperItems: []
    property int selectedThemeIndex: 0
    property int selectedWallpaperIndex: 0
    property bool applying: false
    property bool sceneApplied: false
    property int loadGeneration: 0

    readonly property var selectedTheme: themeItems.length > 0 ? themeItems[Math.max(0, Math.min(selectedThemeIndex, themeItems.length - 1))] : null
    readonly property var selectedWallpaper: wallpaperItems.length > 0 ? wallpaperItems[Math.max(0, Math.min(selectedWallpaperIndex, wallpaperItems.length - 1))] : null

    signal focusRequested
    signal themeScrollRequested
    signal wallpaperScrollRequested

    width: 0
    height: 0
    visible: false

    onOpenedChanged: {
        if (opened) {
            closeTimer.stop()
            activeSection = mode === "theme" ? "theme" : "wallpaper"
            sceneApplied = false
            applying = false
            loadItems()
            focusRequested()
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
        // A generacio leptetese ervenyteleniti a meg uton levo valaszokat.
        loadGeneration++
        themeItems = []
        wallpaperItems = []
    }

    function applyThemes(items) {
        var currentIndex = 0
        for (var i = 0; i < items.length; i++) {
            if (items[i].current) currentIndex = i
        }
        selectedThemeIndex = currentIndex
        themeItems = items
        themeScrollRequested()
    }

    function applyWallpapers(items) {
        var currentIndex = 0
        for (var i = 0; i < items.length; i++) {
            if (items[i].current) currentIndex = i
        }
        selectedWallpaperIndex = currentIndex
        wallpaperItems = items
        wallpaperScrollRequested()
    }

    function imageSource(path) {
        if (!path) return ""
        if (path.startsWith("file:")) return path
        return path.startsWith("/") ? "file://" + path : ""
    }

    function setSection(section) {
        activeSection = section
        if (section === "theme") themeScrollRequested()
        else wallpaperScrollRequested()
    }

    function moveSelection(delta) {
        if (activeSection === "theme") {
            selectedThemeIndex = Math.max(0, Math.min(selectedThemeIndex + delta, themeItems.length - 1))
            themeScrollRequested()
        } else {
            selectedWallpaperIndex = Math.max(0, Math.min(selectedWallpaperIndex + delta, wallpaperItems.length - 1))
            wallpaperScrollRequested()
        }
    }

    function selectDynamicTheme() {
        for (var i = 0; i < themeItems.length; i++) {
            if (themeItems[i].kind === "dynamic") {
                selectedThemeIndex = i
                setSection("theme")
                return
            }
        }
    }

    function applyScene() {
        if (!selectedTheme || !selectedWallpaper || applying) return
        applying = true
        sceneApplied = false

        // A dinamikus paletta csak azutan letezik, hogy a backend feldolgozta a
        // kivalasztott kepet -- addig ne villantsuk fel az elozo kep szineit.
        if (theme && selectedTheme.kind !== "dynamic") {
            theme.setPreview({
                BACKGROUND: selectedTheme.background,
                FOREGROUND: selectedTheme.foreground,
                ACCENT: selectedTheme.accent,
                SURFACE: selectedTheme.surface,
                LIGHT_FOREGROUND: selectedTheme.muted
            })
        }
        if (wallpaperController) wallpaperController.setCurrentWallpaper(selectedWallpaper.path)

        // Ami korabban kilenc lancolt bash script volt, az most egy hivas.
        backend.call("theme", "apply", {
            slug: selectedTheme.slug,
            wallpaper: selectedWallpaper.path
        }, (result, error) => {
            controller.applying = false
            controller.sceneApplied = true
            if (error) {
                console.warn("Appearance: a tema nem alkalmazhato:", error.message)
                if (controller.theme) controller.theme.setPreview({})
            }
            closeTimer.restart()
        })
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            opened = false
            event.accepted = true
        } else if (event.key === Qt.Key_Tab) {
            setSection(activeSection === "wallpaper" ? "theme" : "wallpaper")
            event.accepted = true
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up || (event.key === Qt.Key_K && event.modifiers === Qt.ControlModifier)) {
            moveSelection(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || (event.key === Qt.Key_J && event.modifiers === Qt.ControlModifier)) {
            moveSelection(1)
            event.accepted = true
        } else if (event.key === Qt.Key_D) {
            selectDynamicTheme()
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            applyScene()
            event.accepted = true
        }
    }

    Timer { id: closeTimer; interval: 520; onTriggered: controller.opened = false }

}

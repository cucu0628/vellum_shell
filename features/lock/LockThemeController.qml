import QtQuick

// A zarolokepernyo palettaja es hatterkepe a backend `theme` topicjabol.
//
// Korabban ez a fajl a `scripts/theme-read` kimenetet parsolta. Ha a backend
// nem elerheto, a lenti alapertekek maradnak -- a zarolas ilyenkor is mukodik,
// csak semleges szinekkel es hatterkep nelkul.
QtObject {
    id: root

    required property var backend

    readonly property var themeTopic: backend && backend.topics.theme ? backend.topics.theme : null

    readonly property var colors: themeTopic && themeTopic.colors ? themeTopic.colors : ({})

    // Ugyanaz a hatterkep, amit a core/WallpaperController rak az asztalra: a
    // zarolas igy nem egy masik kepernyo, hanem ugyanannak a lapnak a
    // befagyasztasa.
    readonly property string wallpaper: themeTopic && themeTopic.wallpaper ? themeTopic.wallpaper : ""

    // FIGYELEM: a lekepezes szandekosan "kereszt", ugyanugy, mint a
    // core/ThemeStore-ban: a MUTED kulcs az `outline`-ba megy, a
    // LIGHT_FOREGROUND pedig a `muted`-be.
    readonly property string background: colors.BACKGROUND || "#1e1e2e"
    readonly property string foreground: colors.FOREGROUND || "#cdd6f4"
    readonly property string accent: colors.ACCENT || "#89b4fa"
    readonly property string surface: colors.SURFACE || "#181825"
    readonly property string muted: colors.LIGHT_FOREGROUND || "#bac2de"
    readonly property string outline: colors.MUTED || "#9399b2"

    // Sajat feliratkozas kell: az onallo LockShell.qml-ben nincs ThemeStore, ami
    // helyettunk megtenne. A szamlalt feliratkozas miatt a beagyazott esetben
    // ez nem jelent masodik kerest a daemon fele.
    Component.onCompleted: if (backend) backend.subscribe("theme")
}

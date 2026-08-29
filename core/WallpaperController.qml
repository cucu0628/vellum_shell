import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
    id: controller

    required property string shellDir
    required property var backend
    property var screens: []
    // Empty until the backend reports a real file, so the wallpaper windows
    // never try to open a path that may not exist.
    property string currentWallpaper: ""

    width: 0
    height: 0
    visible: false

    // A backend `theme` topicja hordozza az aktiv hatterkepet is, igy nem kell
    // kulon lekerdezni: temavaltaskor magatol frissul.
    readonly property string reportedWallpaper: backend && backend.topics.theme && backend.topics.theme.wallpaper
        ? backend.topics.theme.wallpaper
        : ""

    onReportedWallpaperChanged: setCurrentWallpaper(reportedWallpaper)

    Component.onCompleted: if (backend) backend.subscribe("theme")

    // A feliratkozas magatol hozza a valtozasokat; ez csak azert maradt meg,
    // hogy a korabbi hivasi pontok ne torjenek el. Ujra-feliratkozni nem
    // szabad: a szamlalo novekedne parositott leiratkozas nelkul.
    function load() {}

    function setCurrentWallpaper(path) {
        if (path && path !== "") currentWallpaper = path
    }

    function source(path) {
        if (!path || path === "") return ""
        if (path.startsWith("file:")) return path
        return "file://" + path
    }


    Instantiator {
        model: controller.screens
        delegate: PanelWindow {
            id: wallpaperWindow
            required property var modelData

            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            color: "#000000"
            WlrLayershell.layer: WlrLayershell.Background
            WlrLayershell.namespace: "quickshell.wallpaper"
            WlrLayershell.exclusiveZone: -1

            Image {
                anchors.fill: parent
                source: controller.source(controller.currentWallpaper)
                sourceSize: Qt.size(width * wallpaperWindow.screen.devicePixelRatio, height * wallpaperWindow.screen.devicePixelRatio)
                fillMode: Image.PreserveAspectCrop
                smooth: true
                asynchronous: true
                // Identical monitor sizes can share the decoded wallpaper.
                cache: true
            }

            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: 0.10
            }
        }
    }
}

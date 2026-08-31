pragma ComponentBehavior: Bound

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

    // A hatterkepre valo dupla kattintas. A `core` nem tudhat a `features`-rol,
    // ezert csak jelez -- hogy mit jelent, azt a shell.qml donti el.
    signal doubleClicked(var targetScreen)

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

            // Ket reteg, keresztusztatassal. A hatso az elozo kepet tartja, amig
            // az uj be nem toltott, igy a valtas nem fekete villanason keresztul
            // tortenik -- a valaszto vegiglepkedese ettol lesz folyamatos.
            property string backSource: ""

            readonly property size textureSize: Qt.size(
                width * wallpaperWindow.screen.devicePixelRatio,
                height * wallpaperWindow.screen.devicePixelRatio)

            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            color: "#000000"
            WlrLayershell.layer: WlrLayershell.Background
            WlrLayershell.namespace: "quickshell.wallpaper"
            WlrLayershell.exclusiveZone: -1

            Image {
                anchors.fill: parent
                source: wallpaperWindow.backSource
                sourceSize: wallpaperWindow.textureSize
                fillMode: Image.PreserveAspectCrop
                smooth: true
                asynchronous: true
                cache: true
                visible: source !== ""
            }

            Image {
                id: frontLayer
                anchors.fill: parent
                source: controller.source(controller.currentWallpaper)
                sourceSize: wallpaperWindow.textureSize
                fillMode: Image.PreserveAspectCrop
                smooth: true
                asynchronous: true
                // Identical monitor sizes can share the decoded wallpaper.
                cache: true
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                // Amint az uj kep all, o lesz a kovetkezo valtas hattere. A cache
                // miatt ez ugyanaz a textura, nem egy masodik dekodolas.
                onStatusChanged: if (status === Image.Ready) wallpaperWindow.backSource = source
            }

            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: 0.10
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                // A kattintott monitort adjuk tovabb, nem a fokuszaltat: a
                // valaszto ott nyiljon, ahova a felhasznalo kattintott.
                onDoubleClicked: controller.doubleClicked(wallpaperWindow.modelData)
            }
        }
    }
}

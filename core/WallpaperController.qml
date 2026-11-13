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


    // Az atmenet hossza (ms). A ThemeStore szinatmenete ennel kicsit rovidebb,
    // igy dinamikus temanal a felulet a kep terulese alatt er at.
    property int transitionDuration: 1100

    Instantiator {
        model: controller.screens
        delegate: PanelWindow {
            id: wallpaperWindow
            required property var modelData

            // Ket kepreteg, szerepcserevel: az "elol" levo latszik, a masikba
            // toltodik a kovetkezo kep. Amig az uj nem all, a regi marad, igy a
            // valtas sosem fekete villanason at tortenik. Amikor all, a
            // tus-shader atuszik ra, utana a szerepek megcserelodnek --
            // forras-masolas nelkul, ami ujratoltest (es villanast) okozna.
            property bool frontIsA: true
            readonly property Image frontImage: frontIsA ? layerA : layerB
            readonly property Image backImage: frontIsA ? layerB : layerA
            // Atmenet kozben ide kerul a kesobb kert kep; a folyo atmenet
            // vegen indul. A kozbulso kerelmek elesnek, csak az utolso szamit.
            property string pendingSource: ""
            property bool transitioning: false
            property real progress: 0
            property real seed: 0

            readonly property size textureSize: Qt.size(
                width * wallpaperWindow.screen.devicePixelRatio,
                height * wallpaperWindow.screen.devicePixelRatio)

            function request(path) {
                var target = controller.source(path)
                if (target === "") return
                if (transitioning) {
                    pendingSource = target === backImage.source.toString() ? "" : target
                    return
                }
                // Ha a mar lathato kep jon vissza (pl. a backend elutasitotta az
                // ujat), a meg toltodo bejovo kep ne induljon el utolag.
                if (target === frontImage.source.toString()) {
                    backImage.source = ""
                    return
                }
                // Az elso kepet (vagy a meg be sem toltottet) nincs mibol
                // atuszni: egyszeruen megjelenik.
                if (frontImage.source.toString() === "" || frontImage.status !== Image.Ready) {
                    backImage.source = ""
                    frontImage.source = target
                    return
                }
                // A cache-elt kep szinkronban is Ready lehet: ezt is a
                // layerStatusChanged inditja.
                backImage.source = target
            }

            function begin() {
                seed = Math.random() * 100
                progress = 0
                transitioning = true
                inkAnimation.restart()
            }

            function finish() {
                var old = frontImage
                frontIsA = !frontIsA
                transitioning = false
                progress = 0
                // A regi textura felszabadul; a cache miatt egy visszavaltas
                // akkor is gyors.
                old.source = ""
                var next = pendingSource
                pendingSource = ""
                if (next !== "") request(next)
            }

            // Ha az uj kep nem toltheto be, ne ragadjon be a valtas.
            function abandon() {
                backImage.source = ""
                var next = pendingSource
                pendingSource = ""
                if (next !== "") request(next)
            }

            Component.onCompleted: request(controller.currentWallpaper)

            Connections {
                target: controller
                function onCurrentWallpaperChanged() { wallpaperWindow.request(controller.currentWallpaper) }
            }

            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            color: "#000000"
            WlrLayershell.layer: WlrLayershell.Background
            WlrLayershell.namespace: "quickshell.wallpaper"
            WlrLayershell.exclusiveZone: -1

            // A shader alatt mindket reteg lathato marad: igy a textura-szolgaltato
            // biztosan friss. A bejovo reteg csak tartalek-modban latszik (ha a
            // shader nem toltheto), ott sima keresztusztatassal.
            function layerOpacity(layer, front) {
                if (layer.status !== Image.Ready) return 0
                if (front || inkEffect.usable) return 1
                return progress
            }

            function imageAspect(layer) {
                return layer.implicitHeight > 0 ? layer.implicitWidth / layer.implicitHeight : inkEffect.aspect
            }

            function layerStatusChanged(layer, front) {
                if (front || transitioning) return
                if (layer.status === Image.Ready) begin()
                else if (layer.status === Image.Error) abandon()
            }

            Image {
                id: layerA
                readonly property bool front: wallpaperWindow.frontIsA
                anchors.fill: parent
                z: front ? 0 : 1
                visible: source.toString() !== "" && (front || wallpaperWindow.transitioning)
                sourceSize: wallpaperWindow.textureSize
                fillMode: Image.PreserveAspectCrop
                smooth: true
                asynchronous: true
                // Identical monitor sizes can share the decoded wallpaper.
                cache: true
                opacity: wallpaperWindow.layerOpacity(layerA, front)
                Behavior on opacity {
                    enabled: layerA.front
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
                onStatusChanged: wallpaperWindow.layerStatusChanged(layerA, front)
            }

            Image {
                id: layerB
                readonly property bool front: !wallpaperWindow.frontIsA
                anchors.fill: parent
                z: front ? 0 : 1
                visible: source.toString() !== "" && (front || wallpaperWindow.transitioning)
                sourceSize: wallpaperWindow.textureSize
                fillMode: Image.PreserveAspectCrop
                smooth: true
                asynchronous: true
                cache: true
                opacity: wallpaperWindow.layerOpacity(layerB, front)
                Behavior on opacity {
                    enabled: layerB.front
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
                onStatusChanged: wallpaperWindow.layerStatusChanged(layerB, front)
            }

            ShaderEffect {
                id: inkEffect

                readonly property bool usable: status !== ShaderEffect.Error
                property var fromTexture: wallpaperWindow.frontImage
                property var toTexture: wallpaperWindow.backImage
                readonly property real progress: wallpaperWindow.progress
                readonly property real aspect: width / Math.max(1, height)
                readonly property real seed: wallpaperWindow.seed
                // A folt a kepernyo kozepe kore, enyhen lefele tolva indul: igy
                // a felso sav (a bar mogott) ter at utoljara.
                readonly property point origin: Qt.point(0.5, 0.56)
                readonly property real fromAspect: wallpaperWindow.imageAspect(wallpaperWindow.frontImage)
                readonly property real toAspect: wallpaperWindow.imageAspect(wallpaperWindow.backImage)

                anchors.fill: parent
                z: 2
                visible: wallpaperWindow.transitioning && usable
                fragmentShader: Qt.resolvedUrl("shaders/wallpaper-ink.frag.qsb")
            }

            NumberAnimation {
                id: inkAnimation
                target: wallpaperWindow
                property: "progress"
                from: 0
                to: 1
                duration: controller.transitionDuration
                easing.type: Easing.InOutSine
                onFinished: wallpaperWindow.finish()
            }

            Rectangle {
                anchors.fill: parent
                z: 3
                color: "#000000"
                opacity: 0.10
            }

            MouseArea {
                anchors.fill: parent
                z: 4
                acceptedButtons: Qt.LeftButton
                // A kattintott monitort adjuk tovabb, nem a fokuszaltat: a
                // valaszto ott nyiljon, ahova a felhasznalo kattintott.
                onDoubleClicked: controller.doubleClicked(wallpaperWindow.modelData)
            }
        }
    }
}

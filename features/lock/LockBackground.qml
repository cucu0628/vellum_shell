import QtQuick
import QtQuick.Effects
import "../../ui" as SharedUi

// A zarolas nem egy uj kepernyo, hanem a meglevo asztal befagyasztasa.
// Ugyanaz a hatterkep marad alatta, csak elhomalyosodik es alaszall -- ezert
// nincs fekete atmenet sem be-, sem kilepeskor. Hatterkep nelkul a shell
// papirfelulete marad: temaszin, halvany ensō es vignetta.
Item {
    id: backgroundView

    required property var lockRoot

    // A dermedes sajat allapota: a panel eltunesekor (`closing`) meg all, es
    // csak a `thawing` oldja fel. Igy a kilepesnek van iranya.
    readonly property bool frosted: lockRoot.ready && !lockRoot.thawing
    readonly property bool hasWallpaper: wallpaperImage.status === Image.Ready
    // Felengedeskor rovidebb: a zarolast 500 ms-nal engedjuk el, es a felulet
    // addigra mar pontosan az asztali hatterkep legyen.
    readonly property int settleDuration: lockRoot.closing ? 340 : 560
    readonly property real ensoSize: Math.min(width, height) * 0.56

    readonly property string wallpaperSource: {
        var path = backgroundView.lockRoot.wallpaper
        if (!path || path === "") return ""
        return path.startsWith("file:") ? path : "file://" + path
    }

    Rectangle {
        id: paper

        anchors.fill: parent
        color: backgroundView.lockRoot.background

        Behavior on color { ColorAnimation { duration: 180 } }
    }

    // Az eles kep. A `sourceSize` szandekosan ugyanaz a keplet, mint a
    // core/WallpaperController-ben: igy a zaraskor letrejovo kep ugyanabbol a
    // pixmap-gyorsitotarbol jon, mint az asztali hatterkep, es nem kell ujra
    // dekodolni. Lathato marad, mert ez a biztos alap: ha a MultiEffect
    // barmiert nem all elo, ez latszik -- nem fekete lap.
    Image {
        id: wallpaperImage

        anchors.fill: parent
        source: backgroundView.wallpaperSource
        sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        visible: backgroundView.hasWallpaper
        // Ha megis dekodolni kell, a kep ne pattanjon be: a temaszinrol usztatjuk.
        opacity: status === Image.Ready ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaperImage
        visible: backgroundView.hasWallpaper
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 48
        // Zaraskor 0-rol indul, tehat az elso kocka meg pontosan az asztal.
        blur: backgroundView.frosted ? 1 : 0
        brightness: backgroundView.frosted ? -0.1 : 0
        saturation: backgroundView.frosted ? -0.3 : 0

        Behavior on blur { NumberAnimation { duration: backgroundView.settleDuration; easing.type: Easing.InOutQuad } }
        Behavior on brightness { NumberAnimation { duration: backgroundView.settleDuration; easing.type: Easing.InOutQuad } }
        Behavior on saturation { NumberAnimation { duration: backgroundView.settleDuration; easing.type: Easing.InOutQuad } }
    }

    // Fatyol a temaszinbol: ettol lesz olvashato a szoveg barmilyen kepen, es
    // ettol tartozik a zarolas a shellhez, nem a hatterkephez.
    Rectangle {
        anchors.fill: parent
        color: backgroundView.lockRoot.background
        opacity: backgroundView.hasWallpaper ? (backgroundView.frosted ? 0.5 : 0) : 0

        Behavior on opacity { NumberAnimation { duration: backgroundView.settleDuration; easing.type: Easing.InOutQuad } }
    }

    // Vizjel es vignetta: a zarolas sajat retege, tehat ugyanugy fel kell
    // engednie, mint a homalynak. Enelkul az utolso kocka meg sotet szelu, es a
    // surface eltuneseben ez egyetlen kepkockas villanaskent latszik.
    Item {
        anchors.fill: parent
        opacity: backgroundView.frosted ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: backgroundView.settleDuration; easing.type: Easing.InOutQuad } }

        // A shell jegye halvanyan: ugyanaz az ensō, mint a panelek vizjele.
        SharedUi.ShellLogo {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -backgroundView.height * 0.03
            size: backgroundView.ensoSize
            color: backgroundView.lockRoot.foreground
            opacity: backgroundView.hasWallpaper ? 0.02 : 0.05
        }

        Rectangle {
            anchors.fill: parent

            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.14) }
                GradientStop { position: 0.45; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.38) }
            }
        }

        Rectangle {
            anchors.fill: parent

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.22) }
                GradientStop { position: 0.36; color: "transparent" }
                GradientStop { position: 0.64; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.22) }
            }
        }
    }

    // Hibas jelszo: egyetlen halvany villanas az egesz lapon, minden monitoron.
    Rectangle {
        id: alertFlash

        anchors.fill: parent
        color: backgroundView.lockRoot.alertColor
        opacity: 0
    }

    Connections {
        target: backgroundView.lockRoot

        function onFailedChanged() {
            if (backgroundView.lockRoot.failed) alertAnimation.restart()
        }
    }

    SequentialAnimation {
        id: alertAnimation

        NumberAnimation { target: alertFlash; property: "opacity"; to: 0.06; duration: 90 }
        NumberAnimation { target: alertFlash; property: "opacity"; to: 0; duration: 430; easing.type: Easing.OutCubic }
    }
}

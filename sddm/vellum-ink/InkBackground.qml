import QtQuick
import QtQuick.Effects
import "." as Ink

// A greeter hattere ugyanaz, mint a zarolokepernyoe: az asztal hatterkepe
// elhomalyositva, temaszinu fatyol alatt.
//
// A kep a tema mappajaban ul (`background.jpg`), mert a `/home` tipikusan
// 0700: az `sddm` felhasznalo nem erne el az eredetit. A masolatot a
// temamotor irja oda minden temavaltaskor. Ha hianyzik, a temaszin es a
// halvany ensō marad -- a greeter attol meg mukodik.
Item {
    id: backgroundView

    required property var greeter

    readonly property bool frosted: greeter.ready && !greeter.thawing
    readonly property bool hasWallpaper: wallpaperImage.status === Image.Ready
    readonly property real ensoSize: Math.min(width, height) * 0.56
    readonly property int settleDuration: greeter.closing ? 340 : 560

    Rectangle {
        id: paper

        anchors.fill: parent
        color: backgroundView.greeter.background

        Behavior on color { ColorAnimation { duration: 180 } }
    }

    // Az eles kep lathato marad a blur alatt: ha a MultiEffect barmiert nem all
    // elo (pl. szoftveres renderelo a greeterben), ez latszik, nem ures lap.
    Image {
        id: wallpaperImage

        anchors.fill: parent
        source: backgroundView.greeter.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        visible: backgroundView.hasWallpaper
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
        blur: backgroundView.frosted ? 1 : 0
        brightness: backgroundView.frosted ? -0.1 : 0
        saturation: backgroundView.frosted ? -0.3 : 0

        Behavior on blur { NumberAnimation { duration: backgroundView.settleDuration; easing.type: Easing.InOutQuad } }
        Behavior on brightness { NumberAnimation { duration: backgroundView.settleDuration; easing.type: Easing.InOutQuad } }
        Behavior on saturation { NumberAnimation { duration: backgroundView.settleDuration; easing.type: Easing.InOutQuad } }
    }

    // Fatyol a temaszinbol: ettol lesz olvashato a szoveg barmilyen kepen, es
    // ettol tartozik a greeter a shellhez, nem a hatterkephez.
    Rectangle {
        anchors.fill: parent
        color: backgroundView.greeter.background
        opacity: backgroundView.hasWallpaper ? (backgroundView.frosted ? 0.5 : 0) : 0

        Behavior on opacity { NumberAnimation { duration: backgroundView.settleDuration; easing.type: Easing.InOutQuad } }
    }

    // Vizjel es vignetta egy retegben: a bejelentkezeskor egyutt kell
    // felengedniuk a homallyal, kulonben a kepernyo szele ugrik egyet.
    Item {
        anchors.fill: parent
        opacity: backgroundView.frosted ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: backgroundView.settleDuration; easing.type: Easing.InOutQuad } }

        Ink.InkLogo {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -backgroundView.height * 0.03
            size: backgroundView.ensoSize
            color: backgroundView.greeter.foreground
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

    // Hibas jelszo: egyetlen halvany villanas minden kijelzon.
    Rectangle {
        id: alertFlash

        anchors.fill: parent
        color: backgroundView.greeter.alertColor
        opacity: 0
    }

    Connections {
        target: backgroundView.greeter

        function onFailedChanged() {
            if (backgroundView.greeter.failed) alertAnimation.restart()
        }
    }

    SequentialAnimation {
        id: alertAnimation

        NumberAnimation { target: alertFlash; property: "opacity"; to: 0.06; duration: 90 }
        NumberAnimation { target: alertFlash; property: "opacity"; to: 0; duration: 430; easing.type: Easing.OutCubic }
    }
}

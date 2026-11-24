import QtQuick
import "../../ui" as SharedUi

// Az alapertelmezett kimenet hangereje: a panel fo vezerloje. Vastag, teljes
// szelessegu sav; a kitoltott resz halvany akcentes "tus", a vegen egy tomor
// el a mutato, a szazalek pedig az el mellett ul -- a leolvasas ott van, ahol
// a kez is. Zene kozben a kitoltott reszben a cava spektruma mozog: a hang ott
// latszik, ahol szabalyozzuk. Nemitva a kitoltes szurkebe valt, a spektrum all.
Item {
    id: fader

    property var controller: null
    property var node: null
    // A cava teljes spektruma (0..100); ures, ha nem szol zene.
    property var spectrum: []

    readonly property var theme: controller ? controller.theme : null
    readonly property real ratio: controller ? controller.volumeRatio(node) : 0
    readonly property int percent: controller ? controller.percent(node) : 0
    readonly property bool muted: node && node.audio ? node.audio.muted : false
    readonly property bool hovered: dragArea.containsMouse || dragArea.pressed
    readonly property color accent: controller ? controller.panelAccent : "#b7372f"
    readonly property color mutedColor: controller ? controller.mutedFg : "#958b7a"
    readonly property color ink: muted ? mutedColor : accent
    readonly property real fillWidth: Math.round(width * ratio)
    readonly property bool showSpectrum: !muted && spectrum && spectrum.length > 1
    // A szazalek az el jobb oldalan, amig elfer; utana a kitoltesen belul.
    readonly property bool labelInside: fillWidth + 12 + readout.implicitWidth > width - 12

    // A spektrum szintje egy 0..1 pozicion, koszinuszos interpolacioval a cava
    // savjai kozott (mint a media panelen); a gyok a halk reszeket emeli.
    function level(position) {
        var values = spectrum
        if (!values || values.length < 2) return 0
        var scaled = Math.max(0, Math.min(1, position)) * (values.length - 1)
        var lower = Math.floor(scaled)
        var upper = Math.min(values.length - 1, lower + 1)
        var t = (1 - Math.cos((scaled - lower) * Math.PI)) / 2
        var raw = values[lower] * (1 - t) + values[upper] * t
        return Math.sqrt(Math.max(0, Math.min(100, raw)) / 100)
    }

    function step(delta) {
        if (controller && node && node.audio) controller.setVolume(node, (node.audio.volume || 0) + delta)
    }

    implicitHeight: 40
    activeFocusOnTab: true

    Accessible.role: Accessible.Slider
    Accessible.name: qsTr("Output volume")
    Accessible.description: muted ? qsTr("Muted") : qsTr("%1 percent").arg(percent)

    Keys.onLeftPressed: (event) => { step(-0.05); event.accepted = true }
    Keys.onDownPressed: (event) => { step(-0.05); event.accepted = true }
    Keys.onRightPressed: (event) => { step(0.05); event.accepted = true }
    Keys.onUpPressed: (event) => { step(0.05); event.accepted = true }
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_M && controller) {
            controller.toggleMute(node)
            event.accepted = true
        }
    }

    Rectangle {
        id: track

        anchors.fill: parent
        radius: 8
        color: controller ? controller.inkBg : "#191b16"
        clip: true

        // A kitoltes: halvany tus a sav elejetol a mutatoig.
        Rectangle {
            id: fill

            width: fader.fillWidth
            height: parent.height
            radius: track.radius
            color: Qt.rgba(fader.ink.r, fader.ink.g, fader.ink.b, fader.hovered ? 0.34 : 0.28)
            Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }

        // A spektrum csak a kitoltott reszben, alulrol felfele no. A csikok
        // a teljes savhoz igazodnak, igy huzaskor nem csusznak el, csak
        // tobb vagy kevesebb latszik beloluk.
        Item {
            width: fader.fillWidth
            height: parent.height
            clip: true
            opacity: fader.showSpectrum ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 240 } }

            Repeater {
                id: bars

                readonly property int barWidth: 3
                readonly property int gap: 3
                model: Math.max(8, Math.floor((track.width - 8 + gap) / (barWidth + gap)))

                Rectangle {
                    required property int index
                    readonly property real level: fader.showSpectrum ? fader.level(index / Math.max(1, bars.count - 1)) : 0

                    x: 4 + index * (bars.barWidth + bars.gap)
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    width: bars.barWidth
                    height: Math.max(2, (track.height - 12) * level)
                    // Csendben nincs pottyor a sav aljan: csak a hang rajzol.
                    visible: level > 0.04
                    radius: width / 2
                    color: fader.accent
                    opacity: 0.2 + 0.35 * level

                    Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                }
            }
        }
    }

    // A mutato: tomor el a kitoltes vegen.
    Rectangle {
        id: edge

        x: Math.max(4, Math.min(fader.width - width - 4, fader.fillWidth - width / 2))
        anchors.verticalCenter: parent.verticalCenter
        width: fader.hovered || fader.activeFocus ? 4 : 3
        height: parent.height - 12
        radius: width / 2
        color: fader.ink
        Behavior on width { NumberAnimation { duration: 100 } }
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Text {
        id: readout

        x: fader.labelInside ? edge.x - implicitWidth - 10 : edge.x + edge.width + 10
        anchors.verticalCenter: parent.verticalCenter
        text: fader.muted ? qsTr("Muted") : fader.percent + "%"
        color: fader.muted ? fader.mutedColor : (controller ? controller.panelFg : "#e8ddc7")
        font.pixelSize: 13
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
    }

    MouseArea {
        id: dragArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: (mouse) => {
            if (fader.controller) fader.controller.setVolumeFromX(fader.node, mouse.x, width)
        }
        onPositionChanged: (mouse) => {
            if (pressed && fader.controller) fader.controller.setVolumeFromX(fader.node, mouse.x, width)
        }
        onWheel: (wheel) => {
            if (fader.controller) fader.controller.wheelVolume(fader.node, wheel)
        }
    }

    SharedUi.FocusRing {
        theme: fader.theme
        active: fader.activeFocus
        cornerRadius: track.radius
    }
}

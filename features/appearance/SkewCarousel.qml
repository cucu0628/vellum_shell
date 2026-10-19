pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets

// Ferde, kozepre huzo carousel (a motor-dev/wallpaperCarousel nyoman).
//
// A kartyak dontott parallelogrammak; a kijelolt all kozepen, teljes meretben
// es fenyeron, a tobbi a tavolsaggal negyzetesen zsugorodik es halvanyul. A
// kartya belsejet a `card` komponens rajzolja -- a carousel csak a keretet, a
// mozgast es a valasztas visszajelzeset adja, igy a hatterkep- es a
// temavalaszto ugyanazt a nyelvet beszeli.
//
// Az igazsag forrasa a controller: a `currentIndex` kivulrol jon, a carousel
// csak keri a valtozast (`currentRequested`), nem allitja maganak.
Item {
    id: carousel

    property var theme: null
    property var model: []
    property int currentIndex: 0
    property int cardWidth: 300
    property int cardHeight: 420
    property real skew: -0.35
    property real selectedScale: 1.08
    // A megerositett kartya felnagyul es elhalvanyul, a tobbi visszahuzodik.
    property int confirmingIndex: -1
    // A kartya tartalma. Kap egy `entry`, egy `focused` es egy `skew` propertyt.
    property Component card: null

    readonly property color fg: theme ? theme.foreground : "#e8ddc7"
    readonly property color accent: theme ? theme.accent : "#b7372f"
    readonly property color hairline: Qt.rgba(fg.r, fg.g, fg.b, 0.16)
    readonly property color placeholder: theme && theme.surface ? theme.surface : "#191b16"
    // A kartyak kepeinek dekodolasi merete. Szandekosan a kartya meretebol
    // szamolt allando, nem a tenyleges elemmeret: a kijelolt keret vastagabb,
    // es ha a `sourceSize` ezt kovetne, minden lepesnel ujratoltene a kepet --
    // kozben pedig a kartya ures (fekete) lenne.
    //
    // Nem sima binding: a szelesseg es a magassag kulon frissul, es a koztes,
    // felemas meretre is betoltene minden kep. Valtozaskor elobb nullara all
    // (a kartyak ilyenkor nem kernek kepet), es csak a kovetkezo korben kapja
    // meg a vegleges erteket.
    property size textureSize: Qt.size(0, 0)

    function updateTextureSize() {
        textureSize = Qt.size(
            Math.round((cardWidth + Math.abs(skew) * cardHeight) * 1.4),
            Math.round(cardHeight * 1.4))
    }

    function invalidateTextureSize() {
        textureSize = Qt.size(0, 0)
        Qt.callLater(updateTextureSize)
    }

    onCardWidthChanged: invalidateTextureSize()
    onCardHeightChanged: invalidateTextureSize()
    onSkewChanged: invalidateTextureSize()
    Component.onCompleted: Qt.callLater(updateTextureSize)

    signal currentRequested(int index)
    signal activated(int index)
    signal stepRequested(int delta)

    function syncCurrent() {
        if (list.count === 0) return
        var target = Math.max(0, Math.min(carousel.currentIndex, list.count - 1))
        if (list.currentIndex !== target) list.currentIndex = target
        if (!list.settled) {
            list.positionViewAtIndex(target, ListView.Center)
            list.settled = true
        }
    }

    onCurrentIndexChanged: syncCurrent()
    onModelChanged: {
        list.settled = false
        Qt.callLater(syncCurrent)
    }

    ListView {
        id: list

        // Az elso igazitas ugras, nem csuszas: nyitaskor a kijelolt mar a
        // helyen legyen, ne a lista elejerol fusson be.
        property bool settled: false

        anchors.fill: parent
        orientation: ListView.Horizontal
        model: carousel.model
        spacing: 0
        clip: false
        cacheBuffer: carousel.cardWidth * 4
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width - carousel.cardWidth) / 2
        preferredHighlightEnd: (width + carousel.cardWidth) / 2
        highlightMoveDuration: settled ? 220 : 0
        highlightMoveVelocity: -1
        boundsBehavior: Flickable.StopAtBounds
        interactive: carousel.confirmingIndex < 0

        onCountChanged: carousel.syncCurrent()
        // Huzassal a lista maga lep: ezt visszajelezzuk a controllernek. Csak
        // felhasznaloi mozgasnal -- a modellcsere is atallitja a currentIndexet,
        // az viszont nem valasztas.
        onCurrentIndexChanged: {
            if (moving && currentIndex >= 0 && currentIndex !== carousel.currentIndex)
                carousel.currentRequested(currentIndex)
        }

        delegate: Item {
            id: slot

            required property var modelData
            required property int index

            readonly property bool focused: index === carousel.currentIndex
            readonly property bool confirmed: carousel.confirmingIndex === index
            readonly property bool otherConfirmed: carousel.confirmingIndex >= 0 && !confirmed
            readonly property bool hovered: pointer.containsMouse && carousel.confirmingIndex < 0
            readonly property int distance: Math.abs(index - carousel.currentIndex)
            readonly property real falloff: 1 / (1 + distance * distance)
            readonly property real baseScale: 0.75
            readonly property real restScale: baseScale + (carousel.selectedScale - baseScale) * falloff

            width: carousel.cardWidth
            height: list.height
            z: confirmed ? 100 : Math.max(1, 20 - distance)

            Item {
                id: plate

                // A dontott kartya a sajat szelessegenel `slant`-tal szelesebb
                // savot foglal; a reteg (layer) csak a plate teruletet rogziti,
                // ezert annak a teljes parallelogrammat le kell fednie.
                readonly property real slant: Math.abs(carousel.skew) * carousel.cardHeight

                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                width: carousel.cardWidth + slant
                height: carousel.cardHeight

                scale: slot.confirmed ? 1.5
                    : slot.otherConfirmed ? slot.restScale * 0.8
                    : slot.hovered ? slot.restScale + 0.05
                    : slot.restScale
                opacity: slot.confirmed || slot.otherConfirmed ? 0
                    : slot.hovered ? 1
                    : 0.12 + 0.88 * slot.falloff
                // Atfedo, felig atlatszo retegeknel csak egyben halvanyitva
                // nem latszik at a kartya keretje a sajat kepen.
                layer.enabled: opacity > 0 && opacity < 1
                layer.smooth: true

                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                // A dontes a bal felso sarok korul tortenik; ezzel az eltolassal
                // a parallelogramma pontosan kitolti a plate-et.
                Item {
                    id: slanted

                    x: carousel.skew < 0 ? plate.slant : 0
                    width: carousel.cardWidth
                    height: parent.height

                    transform: Matrix4x4 {
                        matrix: Qt.matrix4x4(1, carousel.skew, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                    }

                    Rectangle {
                        id: rim

                        readonly property int thickness: slot.focused ? 3 : 1

                        anchors.fill: parent
                        antialiasing: true
                        color: slot.focused ? carousel.accent : carousel.hairline
                        Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        ClippingRectangle {
                            anchors.fill: parent
                            anchors.margins: rim.thickness
                            antialiasing: true
                            color: carousel.placeholder

                            Loader {
                                id: cardLoader
                                anchors.fill: parent
                                sourceComponent: carousel.card
                            }

                            Binding {
                                target: cardLoader.item
                                when: cardLoader.status === Loader.Ready
                                property: "entry"
                                value: slot.modelData
                            }

                            Binding {
                                target: cardLoader.item
                                when: cardLoader.status === Loader.Ready
                                property: "focused"
                                value: slot.focused
                            }

                            Binding {
                                target: cardLoader.item
                                when: cardLoader.status === Loader.Ready
                                property: "skew"
                                value: carousel.skew
                            }

                            Binding {
                                target: cardLoader.item
                                when: cardLoader.status === Loader.Ready
                                property: "textureSize"
                                value: carousel.textureSize
                            }
                        }
                    }
                }
            }

            MouseArea {
                id: pointer

                anchors.centerIn: parent
                width: carousel.cardWidth * plate.scale
                height: carousel.cardHeight * plate.scale
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: carousel.confirmingIndex < 0
                onClicked: {
                    if (slot.focused) carousel.activated(slot.index)
                    else carousel.currentRequested(slot.index)
                }
            }
        }
    }

    WheelHandler {
        id: wheel

        property real accumulated: 0

        target: null
        onWheel: (event) => {
            var delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y
            if (delta === 0) delta = event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x
            wheel.accumulated += delta

            while (wheel.accumulated <= -120) {
                wheel.accumulated += 120
                carousel.stepRequested(1)
            }
            while (wheel.accumulated >= 120) {
                wheel.accumulated -= 120
                carousel.stepRequested(-1)
            }
            event.accepted = true
        }
    }
}

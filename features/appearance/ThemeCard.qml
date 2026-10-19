pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "."

// Temakartya a ferde carouselben: egy kis asztal az adott temaban.
//
// Felul a bar munkaterulet-pottyokkel, kozepen egy terminalablak, amelyben a
// tema terminalszineivel kiemelt "kodsorok" futnak, alatta betuminta, egy
// akcentes gomb es kapcsolo, legalul pedig a feluletszinek festeksavjai a
// kartya dontesevel parhuzamosan. A kijelolt kartyan a sorok begepelodnek es a
// kurzor villog. A dinamikus tema asztala a sajat hatterkep, mert abbol szuletik.
Item {
    id: card

    property var entry: null
    property bool focused: false
    property real skew: -0.35
    // Amig a carousel meg nem adta meg, nem kerunk kepet: kulonben egyszer
    // rossz meretben, aztan ujra toltene.
    property size textureSize: Qt.size(0, 0)
    readonly property bool sized: textureSize.width > 0 && textureSize.height > 0
    property string wallpaperSource: ""
    // A dinamikus tema a jelenlegi hatterkepbol frissen szamolt szinei (a
    // lista bejegyzesevel azonos alakban). Amig nincs meg, a lista szinei maradnak.
    property var dynamicSummary: null

    readonly property bool dynamic: !!entry && entry.kind === "dynamic"
    readonly property var colors: dynamic && dynamicSummary ? dynamicSummary : entry
    readonly property color background: colors ? colors.background : "#11130f"
    readonly property color foreground: colors ? colors.foreground : "#e8ddc7"
    readonly property color accent: colors ? colors.accent : "#b7372f"
    readonly property color surface: colors && colors.surface ? colors.surface : background
    readonly property color muted: colors && colors.muted ? colors.muted : foreground

    // A terminalszineket a backend `theme/list` adja. Regebbi daemonnal hianyoznak:
    // olyankor a feluletszinekbol rakjuk ossze, hogy a kartya akkor is ertelmes legyen.
    readonly property var terminal: colors && colors.terminal ? colors.terminal : null
    function ansi(name) {
        if (terminal && terminal[name]) return terminal[name]
        switch (name) {
        case "red": case "blue": case "magenta": return accent
        case "green": return foreground
        default: return muted
        }
    }
    function tone(key) {
        switch (key) {
        case "fg": return foreground
        case "muted": return muted
        case "accent": return accent
        default: return ansi(key)
        }
    }

    // A lepteket a kartya magassagahoz kotjuk, igy minden kepernyon aranyos.
    readonly property real unit: height / 100
    readonly property int barHeight: Math.round(unit * 5.5)
    readonly property int windowTop: barHeight + Math.round(unit * 5)
    readonly property int windowHeight: Math.round(unit * 44)
    readonly property int specimenTop: windowTop + windowHeight + Math.round(unit * 4.5)
    readonly property int bandHeight: Math.round(unit * 16)

    // [behuzas, [[szin, a sor szelessegenek tortje], ...]] -- egy kitalalt, de
    // kodnak olvashato reszlet: kulcsszo, nev, szoveg, megjegyzes, szam.
    readonly property var codeRows: [
        [0, [["magenta", 0.16], ["blue", 0.3], ["fg", 0.07]]],
        [1, [["yellow", 0.18], ["fg", 0.05], ["green", 0.4]]],
        [1, [["muted", 0.56]]],
        [1, [["cyan", 0.16], ["red", 0.12], ["fg", 0.22]]],
        [2, [["blue", 0.22], ["green", 0.3]]],
        [1, [["magenta", 0.2], ["red", 0.1]]],
        [0, [["fg", 0.07]]]
    ]
    readonly property var segmentOffsets: {
        var offsets = []
        var total = 0
        for (var i = 0; i < codeRows.length; i++) {
            offsets.push(total)
            total += codeRows[i][1].length
        }
        offsets.push(total)
        return offsets
    }
    readonly property int segmentCount: segmentOffsets[segmentOffsets.length - 1]

    // 0..1: hany szegmens latszik. Kijeloleskor nullarol ujra begepelodik.
    property real typed: 1

    onFocusedChanged: {
        typing.stop()
        if (focused) {
            typed = 0
            typing.start()
        } else {
            typed = 1
        }
    }

    NumberAnimation {
        id: typing
        target: card
        property: "typed"
        from: 0
        to: 1
        duration: 900
        easing.type: Easing.InOutQuad
    }

    // -- hatter -------------------------------------------------------------

    Rectangle {
        anchors.fill: parent
        color: card.background
    }

    Upright {
        id: backdrop

        skew: card.skew

        Image {
            anchors.fill: parent
            visible: card.dynamic
            source: card.dynamic && card.sized ? card.wallpaperSource : ""
            sourceSize: card.textureSize
            retainWhileLoading: true
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
        }

        // A kepen a feluletnek olvashatonak kell maradnia: lefele a tema
        // hatterebe sotetedik, ahogy egy valodi asztalon a panelek alatt.
        Rectangle {
            anchors.fill: parent
            visible: card.dynamic
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(card.background.r, card.background.g, card.background.b, 0.15) }
                GradientStop { position: 0.75; color: Qt.rgba(card.background.r, card.background.g, card.background.b, 0.85) }
            }
        }

        // Akcentes derengés a jobb felso sarokban: a tema "fenye".
        Shape {
            anchors.fill: parent
            visible: !card.dynamic
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: backdrop.rightEdge(card.unit * 14) - card.unit * 10
                    centerY: card.unit * 14
                    centerRadius: card.unit * 62
                    focalX: centerX
                    focalY: centerY
                    GradientStop { position: 0; color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.34) }
                    GradientStop { position: 1; color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0) }
                }
                PathRectangle { x: 0; y: 0; width: backdrop.width; height: backdrop.height }
            }
        }
    }

    // -- a kartyaval dolo elemek --------------------------------------------

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: card.barHeight
        color: Qt.rgba(card.surface.r, card.surface.g, card.surface.b, 0.94)
    }

    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: card.bandHeight

        Rectangle { width: parent.width * 0.22; height: parent.height; color: card.surface }
        Rectangle { width: parent.width * 0.34; height: parent.height; color: card.accent }
        Rectangle { width: parent.width * 0.22; height: parent.height; color: card.muted }
        Rectangle { width: parent.width * 0.22; height: parent.height; color: card.foreground }
    }

    // -- egyenesen allo felulet ----------------------------------------------

    Upright {
        id: desk

        skew: card.skew

        // Bar: munkaterulet-pottyok balra, ora jobbra.
        Row {
            x: desk.insetLeft(0, card.barHeight) + 10
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: card.barHeight / 2
            spacing: 4

            Repeater {
                model: 5
                delegate: Rectangle {
                    required property int index
                    width: index === 1 ? 14 : 5
                    height: 5
                    radius: 2.5
                    color: index === 1 ? card.accent : Qt.rgba(card.muted.r, card.muted.g, card.muted.b, 0.7)
                }
            }
        }

        Rectangle {
            x: desk.insetLeft(0, card.barHeight) + desk.insetWidth(0, card.barHeight) - width - 10
            y: (card.barHeight - height) / 2
            width: 24
            height: 5
            radius: 2.5
            color: card.foreground
            opacity: 0.85
        }

        // Terminalablak arnyekkal.
        Item {
            id: terminalWindow

            readonly property int margin: 14

            x: desk.insetLeft(y, y + height) + margin
            y: card.windowTop
            width: desk.insetWidth(y, y + height) - margin * 2
            height: card.windowHeight

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 5
                anchors.leftMargin: 3
                anchors.rightMargin: -3
                anchors.bottomMargin: -5
                radius: 7
                color: "#000000"
                opacity: 0.28
            }

            Rectangle {
                id: windowBody
                anchors.fill: parent
                radius: 7
                color: card.surface
                border.width: 1
                border.color: card.focused
                    ? Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.7)
                    : Qt.rgba(card.foreground.r, card.foreground.g, card.foreground.b, 0.1)
                clip: true

                // Cimsor: a harom ablakgomb a terminal piros, sarga, zold szinevel.
                Row {
                    x: 10
                    y: 9
                    spacing: 5

                    Rectangle { width: 7; height: 7; radius: 3.5; color: card.ansi("red") }
                    Rectangle { width: 7; height: 7; radius: 3.5; color: card.ansi("yellow") }
                    Rectangle { width: 7; height: 7; radius: 3.5; color: card.ansi("green") }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 10
                    width: parent.width * 0.26
                    height: 5
                    radius: 2.5
                    color: card.muted
                    opacity: 0.6
                }

                Rectangle {
                    x: 0
                    y: 25
                    width: parent.width
                    height: 1
                    color: Qt.rgba(card.foreground.r, card.foreground.g, card.foreground.b, 0.08)
                }

                Column {
                    id: code

                    readonly property real lineWidth: windowBody.width - 24

                    x: 12
                    y: 38
                    spacing: Math.max(7, Math.round(card.unit * 2.6))

                    Repeater {
                        model: card.codeRows

                        delegate: Row {
                            id: codeRow

                            required property var modelData
                            required property int index

                            x: modelData[0] * 12
                            height: 5
                            spacing: 4

                            Repeater {
                                model: codeRow.modelData[1]

                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index

                                    readonly property int order: card.segmentOffsets[codeRow.index] + index
                                    readonly property real shown: Math.max(0, Math.min(1, card.typed * card.segmentCount - order))

                                    width: Math.round(code.lineWidth * modelData[1] * shown)
                                    height: 5
                                    radius: 2.5
                                    visible: shown > 0
                                    color: card.tone(modelData[0])
                                    opacity: modelData[0] === "muted" ? 0.75 : 1
                                }
                            }
                        }
                    }

                    // Prompt es kurzor: a kurzor csak a kijelolt kartyan villog.
                    Row {
                        height: 9
                        spacing: 5

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 9
                            height: 5
                            radius: 2.5
                            color: card.accent
                        }

                        Rectangle {
                            id: cursor
                            anchors.verticalCenter: parent.verticalCenter
                            width: 5
                            height: 10
                            radius: 1
                            color: card.foreground
                            opacity: card.focused ? 1 : 0.5

                            SequentialAnimation on opacity {
                                running: card.focused
                                loops: Animation.Infinite
                                PauseAnimation { duration: 480 }
                                NumberAnimation { to: 0; duration: 80 }
                                PauseAnimation { duration: 420 }
                                NumberAnimation { to: 1; duration: 80 }
                            }
                        }
                    }
                }
            }
        }

        // Betuminta, akcentes gomb es kapcsolo: a tema szinei egy kezelofeluleten.
        Item {
            id: specimen

            readonly property int margin: 16

            x: desk.insetLeft(y, y + height) + margin
            y: card.specimenTop
            width: desk.insetWidth(y, y + height) - margin * 2
            height: Math.round(card.unit * 12)

            Text {
                id: specimenText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Aa"
                color: card.foreground
                font.family: "serif"
                font.pixelSize: Math.round(card.unit * 10.5)
                font.weight: Font.Medium
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(card.unit * 14)
                    height: Math.round(card.unit * 5)
                    radius: height / 2
                    color: card.accent

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.5
                        height: 4
                        radius: 2
                        color: card.background
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(card.unit * 8)
                    height: Math.round(card.unit * 4.2)
                    radius: height / 2
                    color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.35)
                    border.width: 1
                    border.color: card.accent

                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 3
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.height - 6
                        height: width
                        radius: width / 2
                        color: card.foreground
                    }
                }
            }
        }

        // A terminal hat szine sorban, mint egy festekpaletta lyukai.
        Row {
            readonly property int rowTop: card.specimenTop + specimen.height + Math.round(card.unit * 3.5)

            x: desk.insetLeft(rowTop, rowTop + 8) + 16
            y: rowTop
            spacing: 6

            Repeater {
                model: ["red", "yellow", "green", "cyan", "blue", "magenta"]
                delegate: Rectangle {
                    required property string modelData
                    width: 8
                    height: 8
                    radius: 4
                    color: card.ansi(modelData)
                }
            }
        }
    }
}

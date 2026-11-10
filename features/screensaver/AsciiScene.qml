import QtQuick

// A kepernyovedo rajzolata ASCII karakterekbol. Ket shader-menet: a jelenet
// (shaders/<sceneName>.frag) cellankent tonust, anyagot es melyseget szamol, a
// glyphs.frag ebbol karaktert es szint. A CPU-n csak az ido fut.
Item {
    id: scene

    property real time: 0
    // 0 = ures, 1 = teljes kep; a cellak veletlen sorrendben jelennek meg.
    property real reveal: 1
    // Kepernyonkent mas, hogy a monitorok ne ugyanazt a kepet mutassak.
    property real seed: 0
    // A jelenet neve: shaders/<sceneName>.frag.qsb (lasd ScreensaverThemes.js).
    property string sceneName: "shapes"
    property color backgroundColor: "#11130f"
    property color lightColor: "#e8ddc7"
    // Az anyagok szine a jelenet sorrendjeben; a hianyzo helyekre az utolso jut.
    property var inkColors: ["#b7372f", "#958b7a"]
    // A legfenyesebb tonus mennyire menjen a lightColor fele (0-1).
    property real highlight: 1
    property real devicePixelRatio: 1
    // A monitor helye es merete a kozos vasznon, es a vaszon merete (logikai
    // pixel): a monitorokon atnyulo jelenet ebbol tudja, melyik reszet rajzolja.
    property point screenOrigin: Qt.point(0, 0)
    property size canvasSize: Qt.size(width, height)

    // Ha a shader nem toltheto be, a hivo leallithatja a kepernyovedot, nehogy
    // egy lathatatlan ablak fogja meg a bemenetet.
    readonly property bool failed: fieldPass.status === ShaderEffect.Error
        || glyphPass.status === ShaderEffect.Error

    // Mert tintasuruseg szerint szigoruan novekvo sor (Noto Sans Mono): ha egy
    // karakter ritkabb az elozonel, a sima feluleten sav latszik. Vizszintes
    // vonalu karakter (- =) nincs benne, mert a sorokbol csikok lennenek.
    readonly property string ramp: " .:;+*cxo$#&@"
    // A konturok iranyai a glyphs.frag sorrendjeben, a vegen a felso szel.
    readonly property string edges: "|/-\\_"
    // A jelenetek altal kozvetlenul kert karakterek (common.glsl GLYPH_*):
    // madar, hullam, csillogas, level, deneverszarny, sziv (<3).
    readonly property string extras: "v~=%^<3"
    readonly property string glyphs: ramp + edges + extras

    readonly property int cellWidth: Math.max(1, Math.ceil(metrics.advanceWidth("M")))
    // A sorkoz szuk, mint egy terminalban: a forma ne essen szet csikokra.
    readonly property int cellHeight: Math.max(1, Math.ceil(metrics.font.pixelSize * 1.12))
    readonly property int columns: Math.ceil(width * devicePixelRatio / cellWidth)
    readonly property int rows: Math.ceil(height * devicePixelRatio / cellHeight)

    function paletteAt(index) {
        var colors = scene.inkColors || []
        if (colors.length === 0) return scene.lightColor
        return colors[Math.min(index, colors.length - 1)]
    }

    FontMetrics {
        id: metrics
        font.family: "monospace"
        font.pixelSize: Math.round(14 * scene.devicePixelRatio)
        font.weight: Font.Medium
    }

    // A karakterkeszlet a felhasznalo monospace betujevel, egy sorba rakva.
    Row {
        id: atlasRow

        Repeater {
            model: scene.glyphs.length

            Text {
                required property int index

                width: scene.cellWidth
                height: scene.cellHeight
                text: scene.glyphs.charAt(index)
                textFormat: Text.PlainText
                color: "white"
                font: metrics.font
                renderType: Text.NativeRendering
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    ShaderEffectSource {
        id: atlasSource

        width: 0
        height: 0
        sourceItem: atlasRow
        hideSource: true
        smooth: false
        textureSize: Qt.size(scene.cellWidth * scene.glyphs.length, scene.cellHeight)
    }

    ShaderEffect {
        id: fieldPass

        readonly property real time: scene.time
        readonly property real aspect: scene.width / Math.max(1, scene.height)
        readonly property real seed: scene.seed
        readonly property size gridSize: Qt.size(scene.columns, scene.rows)
        readonly property point screenOrigin: scene.screenOrigin
        readonly property size screenSize: Qt.size(scene.width, scene.height)
        readonly property size canvasSize: scene.canvasSize

        width: scene.columns
        height: scene.rows
        blending: false
        fragmentShader: Qt.resolvedUrl("shaders/" + scene.sceneName + ".frag.qsb")
    }

    ShaderEffectSource {
        id: fieldSource

        width: 0
        height: 0
        sourceItem: fieldPass
        hideSource: true
        smooth: false
        textureSize: Qt.size(scene.columns, scene.rows)
    }

    ShaderEffect {
        id: glyphPass

        readonly property size pixelSize: Qt.size(scene.width * scene.devicePixelRatio, scene.height * scene.devicePixelRatio)
        readonly property size cellSize: Qt.size(scene.cellWidth, scene.cellHeight)
        readonly property size gridSize: Qt.size(scene.columns, scene.rows)
        readonly property real rampLength: scene.ramp.length
        readonly property real glyphCount: scene.glyphs.length
        readonly property real reveal: scene.reveal
        readonly property real highlight: scene.highlight
        readonly property color backgroundColor: scene.backgroundColor
        readonly property color lightColor: scene.lightColor
        readonly property color palette0: scene.paletteAt(0)
        readonly property color palette1: scene.paletteAt(1)
        readonly property color palette2: scene.paletteAt(2)
        readonly property color palette3: scene.paletteAt(3)
        readonly property color palette4: scene.paletteAt(4)
        readonly property color palette5: scene.paletteAt(5)
        readonly property var field: fieldSource
        readonly property var atlas: atlasSource

        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("shaders/glyphs.frag.qsb")
    }
}

import QtQuick
import QtQuick.Shapes
import "../../ui" as SharedUi

// Egy kijelzo inditokepernyoje: tus-papir, kozepen a ket vonasban megirt logo
// egy enso-korben, alatta a nev es az udvozles.
Item {
    id: view

    required property var splashRoot

    readonly property var theme: splashRoot.theme
    readonly property real logoSize: Math.round(Math.min(width, height) * 0.085)
    readonly property real ensoRadius: Math.round(logoSize * 0.95)
    readonly property real lift: splashRoot.lift
    readonly property real centerX: width / 2
    // A jel kicsit a kozep folott all, hogy a felirattal egyutt legyen kozepen.
    readonly property real centerY: Math.round(height / 2 - logoSize * 0.35)

    // --- a papir ---

    ShaderEffect {
        id: ink

        readonly property bool usable: view.splashRoot.shadersEnabled && status !== ShaderEffect.Error
        readonly property real spread: view.splashRoot.spread
        readonly property real open: view.splashRoot.open
        readonly property real aspect: width / Math.max(1, height)
        readonly property real seed: view.splashRoot.seed
        readonly property point origin: Qt.point(view.centerX / Math.max(1, width), view.centerY / Math.max(1, height))
        readonly property color paperColor: view.theme.background
        readonly property color rimColor: view.theme.accent

        anchors.fill: parent
        visible: usable
        // Kikapcsolva (`effects.shaders`) a shadert be sem toltjuk.
        fragmentShader: view.splashRoot.shadersEnabled ? Qt.resolvedUrl("shaders/splash-ink.frag.qsb") : ""
    }

    // Tartalek, ha a shader nem toltheto vagy ki van kapcsolva: sima atusztatas.
    Rectangle {
        anchors.fill: parent
        visible: !ink.usable
        color: view.theme.background
        opacity: view.splashRoot.spread * (1 - view.splashRoot.open)
    }

    // --- a jel ---

    Item {
        id: mark

        x: view.centerX - width / 2
        y: view.centerY - height / 2
        width: view.ensoRadius * 2 + 32
        height: width
        opacity: 1 - view.lift
        scale: 1 + view.lift * 0.08

        // Akcentus-izzas a jel mogott: a tus "meg nedves" fenye.
        Shape {
            anchors.centerIn: parent
            width: view.ensoRadius * 3.2
            height: width
            opacity: 0.22 * view.splashRoot.glow
            scale: 0.7 + 0.3 * view.splashRoot.glow + 0.25 * view.lift
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: view.ensoRadius * 1.6
                    centerY: view.ensoRadius * 1.6
                    centerRadius: view.ensoRadius * 1.6
                    focalX: centerX
                    focalY: centerY

                    GradientStop { position: 0; color: view.theme.accent }
                    GradientStop { position: 0.45; color: Qt.rgba(view.theme.accent.r, view.theme.accent.g, view.theme.accent.b, 0.35) }
                    GradientStop { position: 1; color: "transparent" }
                }

                PathAngleArc {
                    centerX: view.ensoRadius * 1.6
                    centerY: view.ensoRadius * 1.6
                    radiusX: view.ensoRadius * 1.6
                    radiusY: radiusX
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }

        // Enso: egy ecsetvonasos, nyitott kor, ket egymasra futo vonallal.
        Item {
            id: enso

            anchors.fill: parent
            scale: 1 + view.lift * 0.3

            RotationAnimation on rotation {
                running: view.splashRoot.waiting && !view.splashRoot.leaving
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 2600
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: view.theme.foreground
                    strokeWidth: Math.max(2, view.logoSize * 0.04)
                    capStyle: ShapePath.RoundCap

                    PathAngleArc {
                        centerX: enso.width / 2
                        centerY: enso.height / 2
                        radiusX: view.ensoRadius
                        radiusY: view.ensoRadius
                        startAngle: -70
                        sweepAngle: 318 * view.splashRoot.enso
                    }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: view.theme.foreground
                    strokeWidth: Math.max(1, view.logoSize * 0.016)
                    capStyle: ShapePath.RoundCap

                    PathAngleArc {
                        centerX: enso.width / 2
                        centerY: enso.height / 2
                        radiusX: view.ensoRadius + Math.max(2, view.logoSize * 0.035)
                        radiusY: radiusX
                        startAngle: -64
                        sweepAngle: 290 * view.splashRoot.enso
                    }
                }
            }

            opacity: 0.5
        }

        SharedUi.ShellLogo {
            anchors.centerIn: parent
            size: view.logoSize
            color: view.theme.accent
            leftReveal: view.splashRoot.leftStroke
            rightReveal: view.splashRoot.rightStroke
        }
    }

    // --- a felirat ---

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: mark.y + mark.height + 16 + (1 - view.splashRoot.words) * 8
        spacing: 8
        opacity: view.splashRoot.words * (1 - view.lift)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Vellum"
            color: view.theme.foreground
            font.family: "serif"
            font.pixelSize: 26
            // A betuk osszezarnak, ahogy a felirat megjelenik.
            font.letterSpacing: 2 + 10 * (1 - view.splashRoot.words)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: view.splashRoot.greetingName !== ""
                ? "Welcome back, " + view.splashRoot.greetingName
                : "Welcome back"
            textFormat: Text.PlainText
            color: view.theme.muted
            font.pixelSize: 12
        }
    }
}

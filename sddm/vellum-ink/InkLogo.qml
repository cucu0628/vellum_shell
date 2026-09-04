import QtQuick
import QtQuick.Shapes

// A Vellum Shell jegye: ensō, a jobb felso sarkan nyitva hagyott ecsetvonas.
//
// A greeter tema onallo mappaba telepul (`/usr/share/sddm/themes/vellum-ink`),
// ezert nem erheti el a shell `ui/ShellLogo.qml`-jet -- ez annak a masolata.
// A ket fajlt egyutt kell tartani, ahogy az `assets/vellum-logo.svg`-t is.
Item {
    id: logo

    property color color: "#e8ddc7"
    property real size: 16

    implicitWidth: size
    implicitHeight: size
    width: implicitWidth
    height: implicitHeight

    readonly property real u: size / 16

    // Ecsetgeometria, 16x16 racsegysegben es fokban.
    readonly property int segments: 72
    readonly property real meanRadius: 6.0
    readonly property real startAngle: -24
    readonly property real sweep: 316
    readonly property real maxWidth: 1.95

    // Nyomas a vonas menten: gyors leteres, tartott kozep, felemelkedo farok.
    function pressure(t) {
        let w;
        if (t < 0.18)
            w = 0.68 + 0.32 * Math.sin((t / 0.18) * Math.PI / 2);
        else if (t < 0.52)
            w = 1;
        else
            w = 1 - 0.8 * Math.pow((t - 0.52) / 0.48, 1.3);
        return w * (1 + 0.1 * Math.sin(2 * Math.PI * 1.6 * t + 0.7));
    }

    // A kezzel huzott kor sosem szabalyos, es a farok befele sodrodik.
    function ringRadius(t, a) {
        let r = logo.meanRadius * (1 + 0.022 * Math.sin(2 * a + 0.9) + 0.012 * Math.sin(3 * a + 2.2));
        if (t > 0.74) {
            const s = (t - 0.74) / 0.26;
            r *= 1 - 0.085 * s * s;
        }
        return r;
    }

    // Kulso el elore, belso el vissza, zarva: az ecsetvonas kitoltott korvonal,
    // nem allando vastagsagu vonal.
    function buildPath() {
        const outer = [];
        const inner = [];
        for (let i = 0; i <= logo.segments; i++) {
            const t = i / logo.segments;
            const a = (logo.startAngle + logo.sweep * t) * Math.PI / 180;
            const r = logo.ringRadius(t, a);
            const h = logo.maxWidth * logo.pressure(t) / 2;
            const cos = Math.cos(a);
            const sin = Math.sin(a);
            outer.push([(8 + (r + h) * cos) * logo.u, (8 + (r + h) * sin) * logo.u]);
            inner.push([(8 + (r - h) * cos) * logo.u, (8 + (r - h) * sin) * logo.u]);
        }
        const points = outer.concat(inner.reverse());
        let d = "M" + points[0][0].toFixed(3) + " " + points[0][1].toFixed(3);
        for (let i = 1; i < points.length; i++)
            d += " L" + points[i][0].toFixed(3) + " " + points[i][1].toFixed(3);
        return d + " Z";
    }

    readonly property string pathData: buildPath()

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: logo.color
            strokeWidth: -1

            PathSvg { path: logo.pathData }
        }
    }
}

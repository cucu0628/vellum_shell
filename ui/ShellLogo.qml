import QtQuick
import QtQuick.Shapes

// Vellum: a calligraphic V with two folded-paper strokes.
// Keep geometry in sync with assets/vellum-logo.svg.
//
// The two strokes can be revealed separately in the order they are written:
// the left one from the top down, the right one from its foot upwards. The
// default (1, 1) is the full, static logo.
Item {
    id: logo

    property color color: "#e8ddc7"
    property real size: 16
    // 0..1: how much of each stroke is drawn.
    property real leftReveal: 1
    property real rightReveal: 1

    readonly property real unit: size / 16
    // Vertical extent of the strokes in logo units (see the paths below).
    readonly property real leftTop: 2.7
    readonly property real leftBottom: 14.3
    readonly property real rightTop: 1.7
    readonly property real rightBottom: 14.3

    implicitWidth: size
    implicitHeight: size
    width: implicitWidth
    height: implicitHeight

    component Stroke: Shape {
        id: stroke

        property string path: ""

        width: 16
        height: 16
        scale: logo.unit
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: logo.color
            strokeWidth: -1

            PathSvg { path: stroke.path }
        }
    }

    // Left stroke, written downwards.
    Item {
        width: logo.size
        height: logo.leftReveal >= 1
            ? logo.size
            : logo.unit * (logo.leftTop + (logo.leftBottom - logo.leftTop) * Math.max(0, logo.leftReveal))
        clip: logo.leftReveal < 1

        Stroke {
            path: "M 1.5 3.1 C 3.1 2.7 4.5 3.2 5.2 4.9 L 8.1 11.2 L 6.8 14.3 C 6.4 14.1 6.1 13.7 5.8 13 L 2.4 5.2 C 2.1 4.4 1.8 3.7 1.5 3.1 Z"
        }
    }

    // Right stroke, written upwards from the shared foot.
    Item {
        id: rightClip

        y: logo.rightReveal >= 1
            ? 0
            : logo.unit * (logo.rightBottom - (logo.rightBottom - logo.rightTop) * Math.max(0, logo.rightReveal))
        width: logo.size
        height: logo.size - y
        clip: logo.rightReveal < 1

        Stroke {
            y: -rightClip.y
            path: "M 7.7 14.3 C 8.1 11.3 9.2 7.5 10.8 4.7 C 11.8 3 13.1 2.1 14.6 1.7 C 13.6 3.4 12.9 5.2 12.1 7.2 L 9.8 12.7 C 9.4 13.7 8.7 14.2 7.7 14.3 Z"
        }
    }
}

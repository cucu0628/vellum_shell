import QtQuick
import QtQuick.Shapes

// Vellum: a calligraphic V with two folded-paper strokes.
// Keep geometry in sync with assets/vellum-logo.svg and
// ui/ShellLogo.qml (the greeter is installed independently).
//
// A komponensnev szandekosan elter a regi InkLogo nevtol: az SDDM sajat
// felhasznaloi QML cache-e igy nem tudja a korabbi enso bytecode-jat hasznalni.
Item {
    id: logo

    property color color: "#e8ddc7"
    property real size: 16

    implicitWidth: size
    implicitHeight: size
    width: implicitWidth
    height: implicitHeight

    Shape {
        width: 16
        height: 16
        scale: logo.size / 16
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: logo.color
            strokeWidth: -1

            PathSvg {
                path: "M 1.5 3.1 C 3.1 2.7 4.5 3.2 5.2 4.9 L 8.1 11.2 L 6.8 14.3 C 6.4 14.1 6.1 13.7 5.8 13 L 2.4 5.2 C 2.1 4.4 1.8 3.7 1.5 3.1 Z M 7.7 14.3 C 8.1 11.3 9.2 7.5 10.8 4.7 C 11.8 3 13.1 2.1 14.6 1.7 C 13.6 3.4 12.9 5.2 12.1 7.2 L 9.8 12.7 C 9.4 13.7 8.7 14.2 7.7 14.3 Z"
            }
        }
    }
}

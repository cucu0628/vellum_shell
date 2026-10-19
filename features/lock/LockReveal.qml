import QtQuick

// A zarolasi nezetek kozos megjelenese: atlatszosag es nehany pixeles elcsuszas,
// zaraskor gyorsabban. A gyerekeket kozvetlenul ebbe kell tenni.
Item {
    id: reveal

    required property var lockRoot
    property bool shown: true
    property real offset: 14

    opacity: shown ? 1 : 0
    transform: Translate {
        y: reveal.shown ? 0 : reveal.offset
        Behavior on y {
            NumberAnimation { duration: reveal.lockRoot.closing ? 160 : 520; easing.type: Easing.OutCubic }
        }
    }

    Behavior on opacity {
        NumberAnimation { duration: reveal.lockRoot.closing ? 130 : 460; easing.type: Easing.OutCubic }
    }
}

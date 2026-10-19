import QtQuick

// A ferde kartya belsejeben egyenesen allo reteg.
//
// A kartya maga egy `skew` mertekben dontott parallelogramma; ami ebbe kerul,
// az vele dol. Ez a reteg az inverz dontest kapja, igy a kepernyon egyenesen
// latszik, a parallelogramma pedig csak kivagja. Szelesebb a szulojenel, hogy a
// dontes miatt a ket also/felso sarokban se maradjon ures csik.
Item {
    id: upright

    property real skew: -0.35
    readonly property real slant: Math.abs(skew) * height

    // A parallelogramma bal szele `y` magassagban, a reteg sajat koordinataiban.
    // Szoveg igazitasahoz kell: a margot ehhez kell merni, nem a reteg szelehez.
    function leftEdge(y) {
        return skew < 0 ? Math.abs(skew) * (height - y) : Math.abs(skew) * y
    }

    function rightEdge(y) {
        return leftEdge(y) + width - slant
    }

    x: skew < 0 ? -slant : 0
    y: 0
    width: parent ? parent.width + slant : 0
    height: parent ? parent.height : 0

    transform: Matrix4x4 {
        matrix: Qt.matrix4x4(1, -upright.skew, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
    }
}

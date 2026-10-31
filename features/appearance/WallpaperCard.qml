import QtQuick
import "."

// Hatterkep-kartya a ferde carouselben: maga a kep, egyenesen allva. Felirat
// nincs rajta -- a nevet a carousel alatti sor mondja ki, egyszer.
Item {
    id: card

    property var entry: null
    property bool focused: false
    property real skew: -0.35
    // Amig a carousel meg nem adta meg, nem kerunk kepet: kulonben egyszer
    // rossz meretben, aztan ujra toltene.
    property size textureSize: Qt.size(0, 0)
    readonly property bool sized: textureSize.width > 0 && textureSize.height > 0
    property var imageSource: function (path) { return path }

    Upright {
        skew: card.skew

        Image {
            anchors.fill: parent
            source: card.entry && card.sized ? card.imageSource(card.entry.path) : ""
            // A carousel adja, allandoan: a kijeloles valtasa ne toltse ujra a kepet.
            sourceSize: card.textureSize
            retainWhileLoading: true
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            cache: true
        }
    }
}

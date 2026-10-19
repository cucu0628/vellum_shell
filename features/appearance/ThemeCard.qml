import QtQuick
import "."

// Temakartya a ferde carouselben: a paletta maga, festekmintakent. A felso
// resz a tema hattere egy betumintaval, alul a tobbi szin a kartya dontesevel
// parhuzamos savokban. A dinamikus tema a hatterkepet mutatja, mert abbol
// szuletik.
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

    readonly property bool dynamic: !!entry && entry.kind === "dynamic"
    readonly property color background: entry ? entry.background : "#11130f"
    readonly property color foreground: entry ? entry.foreground : "#e8ddc7"
    readonly property color accent: entry ? entry.accent : "#b7372f"
    readonly property color surface: entry && entry.surface ? entry.surface : background
    readonly property color muted: entry && entry.muted ? entry.muted : foreground
    readonly property int bandHeight: Math.round(height * 0.3)

    Rectangle {
        anchors.fill: parent
        color: card.background
    }

    Upright {
        id: picture

        skew: card.skew
        visible: card.dynamic && card.wallpaperSource !== ""

        Image {
            anchors.fill: parent
            source: picture.visible && card.sized ? card.wallpaperSource : ""
            sourceSize: card.textureSize
            retainWhileLoading: true
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
        }

        // A kep a savok fele a tema hatterebe olvad, igy a minta olvashato marad.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.35; color: "transparent" }
                GradientStop { position: 0.7; color: Qt.rgba(card.background.r, card.background.g, card.background.b, 0.92) }
            }
        }
    }

    // A savok a kartyaval egyutt dolnek: a parallelogramma oldalaival
    // parhuzamos festekcsikok.
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

    Upright {
        id: lettering

        skew: card.skew

        Text {
            x: lettering.leftEdge(y) + 18
            y: 16
            text: "Aa"
            color: card.foreground
            font.family: "serif"
            font.pixelSize: Math.round(lettering.height * 0.16)
            font.weight: Font.Medium
        }

        // Akcentes pont a felso sarokban: a tema "aktiv" szine kicsiben is,
        // ahogy a shellben a kijelolt allapotot jelzi.
        Rectangle {
            x: lettering.rightEdge(y) - width - 18
            y: 24
            width: 10
            height: 10
            radius: 5
            color: card.accent
        }
    }
}

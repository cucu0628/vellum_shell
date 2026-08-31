import QtQuick

// Ertek-csuszka szamkijelzovel. Huzas kozben folyamatosan `moved`-ot ad, de
// `committed`-et csak elengedeskor -- igy egy csuszka mozgatasa nem kuld tucatnyi
// irast a backendnek.
Item {
    id: slider

    property var theme: null
    property real value: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property string suffix: ""

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string surface: theme && theme.surface ? theme.surface : "#1b1613"
    readonly property real span: Math.max(0.0001, to - from)
    readonly property real ratio: Math.max(0, Math.min(1, (value - from) / span))

    signal moved(real value)
    signal committed(real value)

    function quantize(raw) {
        var clamped = Math.max(from, Math.min(to, raw));
        if (stepSize <= 0)
            return clamped;

        var steps = Math.round((clamped - from) / stepSize);
        return Math.max(from, Math.min(to, from + steps * stepSize));
    }

    function valueAt(x) {
        return quantize(from + (x / Math.max(1, track.width)) * span);
    }

    // Egesz lepeskoznel ne jelenjen meg tizedes.
    function formatted(raw) {
        var text = slider.stepSize >= 1 ? Math.round(raw).toString() : raw.toFixed(2);
        return text + slider.suffix;
    }

    implicitWidth: 240
    implicitHeight: 28

    Text {
        id: readout

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 54
        horizontalAlignment: Text.AlignRight
        text: slider.formatted(slider.value)
        color: slider.foreground
        font.family: "monospace"
        font.pixelSize: 11
    }

    Rectangle {
        id: track

        anchors.left: parent.left
        anchors.right: readout.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 4
        radius: 0
        color: slider.surface
        border.color: slider.muted
        border.width: 1

        Rectangle {
            width: parent.width * slider.ratio
            height: parent.height
            color: slider.accent
        }

        Rectangle {
            width: 10
            height: 18
            color: slider.accent
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width, parent.width * slider.ratio - width / 2))
        }

        MouseArea {
            anchors.fill: parent
            anchors.topMargin: -12
            anchors.bottomMargin: -12
            cursorShape: Qt.PointingHandCursor
            onPressed: (mouse) => slider.moved(slider.valueAt(mouse.x))
            onPositionChanged: (mouse) => {
                if (pressed)
                    slider.moved(slider.valueAt(mouse.x));

            }
            onReleased: (mouse) => slider.committed(slider.valueAt(mouse.x))
        }

    }

}

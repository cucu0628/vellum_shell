import QtQuick

// Ures allapot a hangpanelen (nincs eszkoz, vagy a PipeWire meg nem all).
Rectangle {
    property var controller: null
    property string message: ""

    color: controller ? controller.inkBg : "#1b1613"
    radius: 10

    Text {
        anchors.centerIn: parent
        width: parent.width - 32
        text: parent.message
        color: controller ? controller.mutedFg : "#9f8f7c"
        font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }
}

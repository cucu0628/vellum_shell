import QtQuick

Rectangle {
    property var controller: null
    property string message: ""

    color: controller ? controller.inkBg : "#1b1613"
    radius: 10

    Text {
        anchors.centerIn: parent
        text: parent.message
        color: controller ? controller.mutedFg : "#9f8f7c"
        font.pixelSize: 12
    }
}

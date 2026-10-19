import QtQuick

// Szakaszcim a hangpanelen: csendes, darabszam nelkul.
Item {
    property var controller: null
    property string title: ""

    height: 24

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        text: parent.title
        color: controller ? controller.mutedFg : "#9f8f7c"
        font.pixelSize: 10
        font.letterSpacing: 1
        font.weight: Font.DemiBold
    }
}

import QtQuick

// Szakaszcim a lenyilo panelekben: rovid, nagybetus cimke (mint a dashboard
// kartyain), mellette halvany darabszam vagy allapot, jobbra csendes
// muveletek (HeaderChip-ek).
Item {
    id: bar

    property var theme: null
    property string title: ""
    property string detail: ""
    default property alias actions: actionRow.data

    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"

    implicitHeight: 28

    Row {
        anchors.left: parent.left
        anchors.right: actionRow.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        clip: true

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: bar.title
            color: bar.muted
            font.pixelSize: 10
            font.letterSpacing: 1
            font.weight: Font.DemiBold
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            text: bar.detail
            textFormat: Text.PlainText
            color: bar.muted
            font.pixelSize: 10
            font.features: { "tnum": 1 }
        }
    }

    Row {
        id: actionRow

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
    }
}

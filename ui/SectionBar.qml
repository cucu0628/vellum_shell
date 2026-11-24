import QtQuick

// Szakaszcim a lenyilo panelekben: rovid, nagybetus cimke (mint a dashboard
// kartyain), mellette halvany darabszam vagy allapot, jobbra csendes
// muveletek (HeaderChip-ek).
Item {
    id: bar

    property var theme: null
    property string title: ""
    property string detail: ""
    // true: mondatszeru cim (pl. "Wi-Fi networks") nagybetus koz nelkul, az
    // eloter szinevel -- a kartya nelkuli panelek csoportcime.
    property bool sentenceCase: false
    default property alias actions: actionRow.data

    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"

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
            color: bar.sentenceCase ? bar.foreground : bar.muted
            font.pixelSize: bar.sentenceCase ? 13 : 10
            font.letterSpacing: bar.sentenceCase ? 0 : 1
            font.weight: bar.sentenceCase ? Font.Medium : Font.DemiBold
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

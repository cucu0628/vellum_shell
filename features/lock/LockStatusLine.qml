import QtQuick

// Egysoros allapot a jelszomezo alatt: balra a hitelesites allapota, jobbra
// egy billentyutipp, ha van mit torolni.
Item {
    id: line

    required property var lockRoot
    property int alignment: Text.AlignLeft

    implicitHeight: 16

    Text {
        anchors.left: parent.left
        anchors.right: hint.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: line.alignment
        // Nyugalomban ures: a mezo helyorzoje mar elmondja, mit kell tenni.
        text: line.lockRoot.failed || line.lockRoot.unlockInProgress || line.lockRoot.closing
            ? line.lockRoot.statusText
            : ""
        color: line.lockRoot.failed ? line.lockRoot.alertColor : line.lockRoot.muted
        font.pixelSize: 11
        elide: Text.ElideRight

        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Text {
        id: hint

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "Esc clears"
        color: line.lockRoot.muted
        opacity: line.lockRoot.password.length > 0 ? 0.7 : 0
        font.family: "monospace"
        font.pixelSize: 9

        Behavior on opacity { NumberAnimation { duration: 160 } }
    }
}

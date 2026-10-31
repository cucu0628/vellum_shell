import QtQuick

// Egy launcher-talalat: ikon, cim es alcim, jobb oldalt a tipus. A kijelolt
// sor halvany alapot kap; akcentes csak a jobb oldali "Open ↵" jelzes.
Rectangle {
    id: resultRow

    property var result: null
    property int resultIndex: -1
    property bool selected: false
    // Igaz, amig ez a sor a masodik Enterre var (kikapcsolas, ujrainditas).
    property bool pendingConfirm: false
    property bool hoverSelectionEnabled: true
    property string title: ""
    property string subtitle: ""
    property string glyph: ""
    property string appIconSource: ""
    property string appFallbackIcon: "?"
    property color foregroundColor: "#f1e7d0"
    property color accentColor: "#d7472f"
    property color mutedColor: "#9f8f7c"
    property color selectionColor: "#1b1613"
    readonly property bool isApp: result && result.type === "app"
    readonly property bool isEmoji: result && result.type === "emoji"
    readonly property string kindLabel: {
        if (!result) return ""
        if (result.type === "app") return "APP"
        if (result.type === "action") return "ACTION"
        if (result.type === "project") return "PROJECT"
        if (result.type === "calc") return "RESULT"
        if (result.type === "emoji") return "EMOJI"
        return result.type ? result.type.toString().toUpperCase() : ""
    }

    signal hoverRequested(int index)
    signal activationRequested(int index)

    height: 44
    radius: 8
    color: resultMouse.containsMouse || selected ? selectionColor : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: 110
        }

    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 12
        spacing: 12

        Item {
            width: 28
            height: 28
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: appIcon

                anchors.fill: parent
                source: resultRow.isApp ? resultRow.appIconSource : ""
                asynchronous: true
                mipmap: true
                sourceSize: Qt.size(56, 56)
                fillMode: Image.PreserveAspectFit
                visible: source !== "" && status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                text: resultRow.glyph
                font.family: resultRow.isEmoji ? "sans-serif" : "Symbols Nerd Font Mono"
                font.pixelSize: resultRow.isEmoji ? 19 : 16
                color: resultRow.selected ? resultRow.foregroundColor : resultRow.mutedColor
                visible: !resultRow.isApp
            }

            Text {
                anchors.centerIn: parent
                text: resultRow.appFallbackIcon
                font.family: "sans-serif"
                font.pixelSize: 15
                font.weight: Font.DemiBold
                color: resultRow.selected ? resultRow.foregroundColor : resultRow.mutedColor
                visible: resultRow.isApp && (appIcon.source === "" || appIcon.status !== Image.Ready)
            }

        }

        Column {
            width: parent.width - x - trailing.width - parent.spacing
            spacing: 1
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: resultRow.title
                textFormat: Text.PlainText
                font.pixelSize: 13
                font.weight: Font.Medium
                color: resultRow.foregroundColor
                elide: Text.ElideRight
                maximumLineCount: 1
                width: parent.width
            }

            Text {
                visible: text !== ""
                text: resultRow.subtitle
                textFormat: Text.PlainText
                font.pixelSize: 10
                color: resultRow.mutedColor
                elide: Text.ElideRight
                maximumLineCount: 1
                width: parent.width
            }

        }

        Item {
            id: trailing

            width: 64
            height: parent.height

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !resultRow.selected && !resultRow.pendingConfirm
                text: resultRow.kindLabel
                color: resultRow.mutedColor
                opacity: 0.7
                font.pixelSize: 9
                font.letterSpacing: 1
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: resultRow.selected || resultRow.pendingConfirm
                text: resultRow.pendingConfirm ? qsTr("Again ↵") : qsTr("Open ↵")
                color: resultRow.accentColor
                font.pixelSize: 11
                font.weight: resultRow.pendingConfirm ? Font.DemiBold : Font.Normal
            }

        }

    }

    MouseArea {
        id: resultMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            if (resultRow.hoverSelectionEnabled)
                resultRow.hoverRequested(resultRow.resultIndex);

        }
        onClicked: resultRow.activationRequested(resultRow.resultIndex)
    }

}

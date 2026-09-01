import QtQuick

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

    height: 46
    radius: 0
    color: resultMouse.containsMouse || selected ? selectionColor : "transparent"
    border.color: "transparent"
    border.width: 0
    scale: 1

    Rectangle {
        width: 2
        height: parent.height
        anchors.left: parent.left
        color: resultRow.accentColor
        opacity: resultRow.selected ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }

        }

    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        Item {
            width: 30
            height: 30
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: appIcon

                anchors.fill: parent
                source: resultRow.isApp ? resultRow.appIconSource : ""
                asynchronous: true
                mipmap: true
                sourceSize: Qt.size(28, 28)
                fillMode: Image.PreserveAspectFit
                visible: source !== "" && status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                text: resultRow.glyph
                font.family: resultRow.isEmoji ? "sans-serif" : "Symbols Nerd Font Mono"
                font.pixelSize: resultRow.isEmoji ? 20 : 17
                color: resultRow.selected ? resultRow.accentColor : resultRow.foregroundColor
                visible: !resultRow.isApp
            }

            Text {
                anchors.centerIn: parent
                text: resultRow.appFallbackIcon
                font.family: "sans-serif"
                font.pixelSize: 16
                font.bold: true
                color: resultRow.selected ? resultRow.accentColor : resultRow.foregroundColor
                visible: resultRow.isApp && (appIcon.source === "" || appIcon.status !== Image.Ready)
            }

        }

        Column {
            width: parent.width - 140
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: resultRow.title
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: resultRow.selected ? resultRow.accentColor : resultRow.foregroundColor
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                text: resultRow.subtitle
                font.pixelSize: 11
                color: resultRow.mutedColor
                opacity: resultRow.selected ? 0.9 : 1
                elide: Text.ElideRight
                width: parent.width
            }

        }

        Text {
            width: 86
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: resultRow.pendingConfirm ? "AGAIN  ↵" : (resultRow.selected ? "OPEN  ↵" : resultRow.kindLabel)
            color: resultRow.selected || resultRow.pendingConfirm ? resultRow.accentColor : resultRow.mutedColor
            font.bold: resultRow.pendingConfirm
            font.family: "monospace"
            font.pixelSize: 8
            font.letterSpacing: resultRow.selected ? 0 : 1.2
            opacity: resultRow.selected || resultRow.pendingConfirm ? 1 : 0.65
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

    Behavior on color {
        ColorAnimation {
            duration: 110
        }

    }

}

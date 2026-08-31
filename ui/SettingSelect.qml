pragma ComponentBehavior: Bound

import QtQuick

// Legordulo valaszto. Nem QtQuick.Controls Popup, hanem a szulo felett lebego
// sajat lista: a shell sehol nem hasznal Controls-t, es igy a temazasa is a
// tobbi elemevel egyezik.
//
// A `model` string lista, vagy `{ label, value }` objektumok listaja.
Item {
    id: select

    property var theme: null
    property var model: []
    property string value: ""
    property string placeholder: "--"
    property bool expanded: false
    property int maxVisibleRows: 8

    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"
    readonly property string surface: theme && theme.surface ? theme.surface : "#1b1613"
    readonly property string background: theme ? theme.background : "#11130f"
    readonly property string currentLabel: labelFor(value)

    signal activated(string value)

    function entryValue(entry) {
        return entry && entry.value !== undefined ? entry.value.toString() : (entry || "").toString();
    }

    function entryLabel(entry) {
        return entry && entry.label !== undefined ? entry.label.toString() : (entry || "").toString();
    }

    function labelFor(wanted) {
        for (var i = 0; i < model.length; i++) {
            if (entryValue(model[i]) === wanted)
                return entryLabel(model[i]);

        }
        return wanted === "" ? placeholder : wanted;
    }

    implicitWidth: 240
    implicitHeight: 30
    // A lenyilo lista kilog az elembol, ezert nem szabad levagni.
    clip: false

    Rectangle {
        id: box

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 30
        color: select.surface
        border.color: select.expanded ? select.accent : select.muted
        border.width: 1

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: chevron.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: select.currentLabel
            color: select.foreground
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Text {
            id: chevron

            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: select.expanded ? "▴" : "▾"
            color: select.accent
            font.pixelSize: 10
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: select.expanded = !select.expanded
        }

    }

    Rectangle {
        id: dropdown

        anchors.top: box.bottom
        anchors.topMargin: 2
        anchors.right: box.right
        width: box.width
        height: Math.min(select.maxVisibleRows, Math.max(1, select.model.length)) * 26 + 2
        visible: select.expanded && select.model.length > 0
        color: select.background
        border.color: select.accent
        border.width: 1
        z: 50

        ListView {
            anchors.fill: parent
            anchors.margins: 1
            clip: true
            model: select.model
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            delegate: Rectangle {
                id: option

                required property var modelData

                readonly property bool current: select.entryValue(option.modelData) === select.value

                width: ListView.view.width
                height: 26
                color: optionMouse.containsMouse || option.current ? select.surface : "transparent"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 9
                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    text: select.entryLabel(option.modelData)
                    color: option.current ? select.accent : select.foreground
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: optionMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        select.expanded = false;
                        select.activated(select.entryValue(option.modelData));
                    }
                }

            }

        }

    }

}

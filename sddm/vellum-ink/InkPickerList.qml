import QtQuick

// A valasztok kozos legordulo listaja. Az InkCard kozvetlen gyereke, igy a
// kattintasokat semmilyen szuloi hatar vagy alatta fekvo felulet nem nyeli el.
Item {
    id: dropdown

    required property var greeter
    property var entries: []
    property int currentIndex: 0
    property bool open: false
    property int maxHeight: 246

    signal picked(int index)

    width: 240
    height: Math.min(maxHeight, Math.max(entries.length, 1) * 34 + 2)
    visible: opacity > 0.01
    enabled: open
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.97
    transformOrigin: Item.Top

    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(dropdown.greeter.surface.r, dropdown.greeter.surface.g, dropdown.greeter.surface.b, 0.97)
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        radius: 0

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: 2
            color: dropdown.greeter.accent
        }

        ListView {
            id: list

            anchors.fill: parent
            anchors.margins: 1
            anchors.topMargin: 3
            clip: true
            model: dropdown.entries
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: dropdown.currentIndex

            delegate: Item {
                id: entry

                required property int index
                required property var modelData

                readonly property bool current: index === dropdown.currentIndex

                width: list.width
                height: 34

                Rectangle {
                    anchors.fill: parent
                    color: dropdown.greeter.accent
                    opacity: entry.current ? 0.12 : (entryMouse.containsMouse ? 0.07 : 0)

                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                Rectangle {
                    width: 2
                    height: parent.height
                    anchors.left: parent.left
                    color: dropdown.greeter.accent
                    visible: entry.current
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 13
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: entry.modelData.label
                    color: entry.current ? dropdown.greeter.foreground : dropdown.greeter.muted
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: entryMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dropdown.picked(entry.index)
                }
            }
        }
    }
}

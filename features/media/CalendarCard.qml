import QtQuick
import "../../ui" as SharedUi

SharedUi.DashPanel {
    id: card

    property var now: new Date()
    property var today: new Date()
    property var monthNames: []
    property var dayNames: []
    property bool dense: false
    signal monthChangeRequested(int delta)

    readonly property color hoverBg: Qt.rgba(1, 1, 1, 0.075)
    readonly property color lineBg: Qt.rgba(1, 1, 1, 0.055)

    function two(value) {
        return value.toString().padStart(2, "0")
    }

    title: "CALENDAR"
    kanji: ""
    trailing: card.today.getFullYear() + "." + two(card.today.getMonth() + 1) + "." + two(card.today.getDate())
    contentSpacing: 10
    editorial: true

    Item {
        id: monthRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 26

        Rectangle {
            id: prevButton
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26
            color: prevMouse.containsMouse ? card.hoverBg : "transparent"
            border.color: card.lineBg
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "‹"
                color: card.accent
                font.pixelSize: 18
            }

            MouseArea {
                id: prevMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.monthChangeRequested(-1)
            }
        }

        Text {
            anchors.left: prevButton.right
            anchors.right: nextButton.left
            anchors.verticalCenter: parent.verticalCenter
            text: (card.monthNames.length > 0 ? card.monthNames[card.now.getMonth()].toUpperCase() : "") + "  " + card.now.getFullYear()
            color: card.foreground
            font.pixelSize: 13
            font.letterSpacing: 2
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        Rectangle {
            id: nextButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26
            color: nextMouse.containsMouse ? card.hoverBg : "transparent"
            border.color: card.lineBg
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "›"
                color: card.accent
                font.pixelSize: 18
            }

            MouseArea {
                id: nextMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.monthChangeRequested(1)
            }
        }
    }

    SharedUi.CalendarGrid {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: monthRow.bottom
        anchors.topMargin: card.dense ? 10 : 14
        displayedDate: card.now
        dayNames: card.dayNames
        foreground: card.foreground
        muted: card.muted
        accent: card.accent
        todayForeground: card.background
        activeBackground: "transparent"
        hoverBackground: Qt.rgba(1, 1, 1, 0.075)
        activeBorder: "transparent"
        hoverEnabled: true
        sectionSpacing: card.dense ? 6 : 12
        cellHeight: card.dense ? 21 : 28
        rowSpacing: card.dense ? 3 : 6
        columnSpacing: card.dense ? 4 : 6
        headerHeight: card.dense ? 14 : 18
    }
}

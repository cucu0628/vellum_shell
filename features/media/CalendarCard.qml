import QtQuick
import "../../ui" as SharedUi

SharedUi.DashPanel {
    id: card

    property var now: new Date()
    property var today: new Date()
    property var monthNames: []
    property var dayNames: []
    property bool dense: false
    // "YYYY-M-D" -> esemenyek (core/CalendarController.eventsByDay). Ures, ha
    // nincs naptar bekotve.
    property var eventIndex: ({})
    readonly property var markedDays: {
        var marked = []
        var year = now.getFullYear()
        var month = now.getMonth()
        var count = new Date(year, month + 1, 0).getDate()
        for (var day = 1; day <= count; day++) {
            if (eventIndex[year + "-" + (month + 1) + "-" + day]) marked.push(day)
        }
        return marked
    }
    signal monthChangeRequested(int delta)

    readonly property color hoverBg: Qt.rgba(1, 1, 1, 0.075)
    readonly property color lineBg: Qt.rgba(1, 1, 1, 0.055)

    title: "CALENDAR"
    contentSpacing: 10

    Item {
        id: monthRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 28

        Rectangle {
            id: prevButton
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28
            radius: 6
            color: prevMouse.containsMouse ? card.hoverBg : "transparent"

            Text {
                anchors.centerIn: parent
                text: "‹"
                color: prevMouse.containsMouse ? card.accent : card.muted
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
            text: (card.monthNames.length > 0 ? card.monthNames[card.now.getMonth()] : "") + " " + card.now.getFullYear()
            color: card.foreground
            font.pixelSize: 13
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        Rectangle {
            id: nextButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28
            radius: 6
            color: nextMouse.containsMouse ? card.hoverBg : "transparent"

            Text {
                anchors.centerIn: parent
                text: "›"
                color: nextMouse.containsMouse ? card.accent : card.muted
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
        markedDays: card.markedDays
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

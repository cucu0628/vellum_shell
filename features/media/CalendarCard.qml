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

    // Kulon cim nincs: a honap neve maga a szekcio cime, mellette a lapozas.
    title: ""
    contentSpacing: 10

    Item {
        id: monthRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 28

        Text {
            anchors.left: parent.left
            anchors.right: prevButton.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: (card.monthNames.length > 0 ? card.monthNames[card.now.getMonth()] : "") + " " + card.now.getFullYear()
            color: card.foreground
            font.family: "serif"
            font.pixelSize: 15
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Rectangle {
            id: prevButton
            anchors.right: nextButton.left
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

            SharedUi.Pressable {
                id: prevMouse
                anchors.fill: parent
                theme: card.theme
                focusRadius: 6
                accessibleName: qsTr("Previous month")
                onClicked: card.monthChangeRequested(-1)
            }
        }

        Rectangle {
            id: nextButton
            anchors.right: parent.right
            anchors.rightMargin: -6
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

            SharedUi.Pressable {
                id: nextMouse
                anchors.fill: parent
                theme: card.theme
                focusRadius: 6
                accessibleName: qsTr("Next month")
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

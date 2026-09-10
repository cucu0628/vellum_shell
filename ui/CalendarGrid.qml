import QtQuick

Item {
    id: calendarGrid

    property var displayedDate: new Date()
    property var dayNames: localizedDayNames()

    function localizedDayNames() {
        var names = [];
        for (var day = 1; day <= 7; day++)
            names.push(Qt.formatDate(new Date(2024, 0, day), "ddd"));
        return names;
    }
    property color foreground: "#f1e7d0"
    property color muted: "#9f8f7c"
    property color accent: "#d7472f"
    property color todayForeground: "#15110f"
    property color activeBackground: "#1b1613"
    property color hoverBackground: activeBackground
    property color activeBorder: Qt.rgba(1, 1, 1, 0.06)
    property bool hoverEnabled: false
    property real sectionSpacing: 6
    property real cellHeight: 28
    property real rowSpacing: 6
    property real columnSpacing: 6
    property real headerHeight: 18

    readonly property real cellWidth: (width - columnSpacing * 6) / 7
    readonly property real daysHeight: cellHeight * 6 + rowSpacing * 5

    implicitHeight: headerHeight + sectionSpacing + daysHeight
    height: implicitHeight

    function firstDayOffset() {
        var first = new Date(displayedDate.getFullYear(), displayedDate.getMonth(), 1).getDay()
        return first === 0 ? 6 : first - 1
    }

    function daysInMonth() {
        return new Date(displayedDate.getFullYear(), displayedDate.getMonth() + 1, 0).getDate()
    }

    function dayForCell(index) {
        return index - firstDayOffset() + 1
    }

    function isToday(day) {
        var today = new Date()
        return day === today.getDate()
            && displayedDate.getMonth() === today.getMonth()
            && displayedDate.getFullYear() === today.getFullYear()
    }

    Grid {
        id: headerGrid
        width: parent.width
        height: calendarGrid.headerHeight
        columns: 7
        columnSpacing: calendarGrid.columnSpacing

        Repeater {
            model: calendarGrid.dayNames
            Text {
                width: calendarGrid.cellWidth
                height: calendarGrid.headerHeight
                text: modelData
                color: calendarGrid.muted
                font.pixelSize: 10
                font.letterSpacing: 1
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    Grid {
        anchors.top: headerGrid.bottom
        anchors.topMargin: calendarGrid.sectionSpacing
        width: parent.width
        height: calendarGrid.daysHeight
        columns: 7
        rowSpacing: calendarGrid.rowSpacing
        columnSpacing: calendarGrid.columnSpacing

        Repeater {
            model: 42
            Rectangle {
                property int day: calendarGrid.dayForCell(index)
                property bool activeDay: day > 0 && day <= calendarGrid.daysInMonth()
                property bool today: activeDay && calendarGrid.isToday(day)
                property bool hovered: activeDay && dayMouse.containsMouse

                width: calendarGrid.cellWidth
                height: calendarGrid.cellHeight
                color: today
                    ? calendarGrid.accent
                    : (hovered && calendarGrid.hoverEnabled ? calendarGrid.hoverBackground : (activeDay ? calendarGrid.activeBackground : "transparent"))
                border.color: activeDay && !today
                    ? (hovered && calendarGrid.hoverEnabled ? calendarGrid.accent : calendarGrid.activeBorder)
                    : "transparent"
                border.width: activeDay && !today && ((hovered && calendarGrid.hoverEnabled) || calendarGrid.activeBorder.a > 0) ? 1 : 0
                radius: 0
                Behavior on color { ColorAnimation { duration: 90; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: parent.activeDay ? parent.day.toString() : ""
                    color: parent.today ? calendarGrid.todayForeground : calendarGrid.foreground
                    opacity: parent.activeDay ? 1 : 0
                    font.pixelSize: 12
                    font.weight: parent.today ? Font.DemiBold : Font.Normal
                }

                MouseArea {
                    id: dayMouse
                    anchors.fill: parent
                    hoverEnabled: calendarGrid.hoverEnabled
                    acceptedButtons: Qt.NoButton
                }
            }
        }
    }
}

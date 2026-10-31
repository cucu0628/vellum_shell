pragma ComponentBehavior: Bound

import QtQuick
import "../../ui" as SharedUi

// A naptar kinagyitott nezete: nagy havi racs hetszamokkal, balra; a
// kijelolt nap reszletei jobbra. Barmelyik napra kattintva az lesz kijelolve.
// Bekotott Google Naptarnal a jobb oldal a nap esemenyeit listazza.
SharedUi.DashPanel {
    id: card

    property var today: new Date()
    property var monthNames: []
    property var dayNames: []
    // "YYYY-M-D" -> esemenyek (core/CalendarController.eventsByDay).
    property var eventIndex: ({})
    property bool eventsEnabled: false
    // A token a zarolt kulcstarban van: az esemenyek addig nem tolthetok be.
    property bool keyringLocked: false

    signal eventActivated(string link)

    // A nezet sajat allapota: melyik honap latszik, melyik nap van kijelolve.
    property var viewMonth: new Date(today.getFullYear(), today.getMonth(), 1)
    property var selected: new Date(today.getFullYear(), today.getMonth(), today.getDate())

    readonly property color hoverBg: Qt.rgba(1, 1, 1, 0.07)
    readonly property color lineBg: Qt.rgba(1, 1, 1, 0.06)
    readonly property var weekdayNames: {
        if (dayNames.length === 7) return dayNames
        var names = []
        for (var day = 1; day <= 7; day++) names.push(Qt.formatDate(new Date(2024, 0, day), "ddd"))
        return names
    }

    function monthName(date) {
        return monthNames.length === 12 ? monthNames[date.getMonth()] : Qt.formatDate(date, "MMMM")
    }

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
    }

    function startOfDay(date) {
        return new Date(date.getFullYear(), date.getMonth(), date.getDate())
    }

    function eventsOn(date) {
        return eventIndex[date.getFullYear() + "-" + (date.getMonth() + 1) + "-" + date.getDate()] || []
    }

    // Egy esemeny ideje a kijelolt napon: a tobb napon atnyulo esemeny
    // kozepso napja "All day", az elso "From", az utolso "Until".
    function eventTime(event, day) {
        if (event.allDay) return qsTr("All day")
        var start = new Date(event.start)
        var end = new Date(event.end)
        var startsToday = start >= startOfDay(day)
        var endsToday = end <= new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1)
        if (!startsToday && !endsToday) return qsTr("All day")
        if (!startsToday) return qsTr("Until %1").arg(Qt.formatTime(end, "HH:mm"))
        if (!endsToday) return qsTr("From %1").arg(Qt.formatTime(start, "HH:mm"))
        if (event.end === event.start) return Qt.formatTime(start, "HH:mm")
        return Qt.formatTime(start, "HH:mm") + " – " + Qt.formatTime(end, "HH:mm")
    }

    // ISO 8601 hetszam: a het csutortokje donti el, melyik evhez tartozik.
    function isoWeek(date) {
        var d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()))
        var day = d.getUTCDay() || 7
        d.setUTCDate(d.getUTCDate() + 4 - day)
        var yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1))
        return Math.ceil(((d - yearStart) / 86400000 + 1) / 7)
    }

    function dayOfYear(date) {
        return Math.round((startOfDay(date) - new Date(date.getFullYear(), 0, 1)) / 86400000) + 1
    }

    function daysInYear(year) {
        return new Date(year, 1, 29).getMonth() === 1 ? 366 : 365
    }

    function relativeText(date) {
        var diff = Math.round((startOfDay(date) - startOfDay(today)) / 86400000)
        if (diff === 0) return qsTr("Today")
        if (diff === 1) return qsTr("Tomorrow")
        if (diff === -1) return qsTr("Yesterday")
        return diff > 0 ? qsTr("In %1 days").arg(diff) : qsTr("%1 days ago").arg(-diff)
    }

    // Holdfazis egy ismert ujholdtol (2000-01-06 18:14 UTC) szamolva; napra
    // pontos, ami egy naptarhoz eleg.
    function moonPhase(date) {
        var synodic = 29.530588853
        var knownNewMoon = Date.UTC(2000, 0, 6, 18, 14)
        var noon = Date.UTC(date.getFullYear(), date.getMonth(), date.getDate(), 12)
        var age = ((noon - knownNewMoon) / 86400000) % synodic
        if (age < 0) age += synodic
        var names = [qsTr("New moon"), qsTr("Waxing crescent"), qsTr("First quarter"), qsTr("Waxing gibbous"),
            qsTr("Full moon"), qsTr("Waning gibbous"), qsTr("Last quarter"), qsTr("Waning crescent")]
        return names[Math.floor((age / synodic) * 8 + 0.5) % 8]
    }

    // A racs elso cellaja: a honap elso napjat tartalmazo het hetfoje.
    function gridStart() {
        var first = viewMonth
        var offset = (first.getDay() + 6) % 7
        return new Date(first.getFullYear(), first.getMonth(), 1 - offset)
    }

    function changeMonth(delta) {
        viewMonth = new Date(viewMonth.getFullYear(), viewMonth.getMonth() + delta, 1)
    }

    function goToday() {
        viewMonth = new Date(today.getFullYear(), today.getMonth(), 1)
        selected = startOfDay(today)
    }

    title: "CALENDAR"
    trailing: qsTr("Week %1").arg(isoWeek(today))
    closable: true

    Row {
        anchors.fill: parent
        spacing: 20

        // -- havi racs ------------------------------------------------------
        Column {
            id: monthColumn

            width: Math.round((parent.width - 21) * 0.62)
            height: parent.height
            spacing: 10

            Item {
                width: parent.width
                height: 28

                Rectangle {
                    id: prevButton

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
                        accessibleName: qsTr("Previous month")
                        onClicked: card.changeMonth(-1)
                    }
                }

                Text {
                    anchors.left: prevButton.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.monthName(card.viewMonth) + " " + card.viewMonth.getFullYear()
                    color: card.foreground
                    font.family: "serif"
                    font.pixelSize: 17
                    font.weight: Font.Medium
                }

                SharedUi.HeaderChip {
                    anchors.right: nextButton.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: implicitWidth
                    visible: !card.sameDay(card.selected, card.today)
                        || card.viewMonth.getMonth() !== card.today.getMonth()
                        || card.viewMonth.getFullYear() !== card.today.getFullYear()
                    theme: card.theme
                    label: qsTr("Today")
                    onClicked: card.goToday()
                }

                Rectangle {
                    id: nextButton

                    anchors.right: parent.right
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
                        accessibleName: qsTr("Next month")
                        onClicked: card.changeMonth(1)
                    }
                }
            }

            Grid {
                id: grid

                readonly property real cellWidth: (width - columnSpacing * 7) / 8
                readonly property real cellHeight: Math.max(24, (monthColumn.height - 38 - 18 - rowSpacing * 6) / 6)

                width: parent.width
                columns: 8
                columnSpacing: 2
                rowSpacing: 2

                // Fejlec: "Wk" + a het napjai.
                Repeater {
                    model: 8

                    Text {
                        required property int index

                        width: grid.cellWidth
                        height: 18
                        text: index === 0 ? qsTr("Wk") : card.weekdayNames[index - 1]
                        color: card.muted
                        opacity: index === 0 ? 0.7 : 1
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Repeater {
                    model: 48

                    Item {
                        id: cell

                        required property int index
                        readonly property int row: Math.floor(index / 8)
                        readonly property bool weekColumn: index % 8 === 0
                        readonly property var date: {
                            var start = card.gridStart()
                            var offset = row * 7 + (weekColumn ? 0 : index % 8 - 1)
                            return new Date(start.getFullYear(), start.getMonth(), start.getDate() + offset)
                        }
                        readonly property bool inMonth: date.getMonth() === card.viewMonth.getMonth()
                        readonly property bool isToday: !weekColumn && card.sameDay(date, card.today)
                        readonly property bool isSelected: !weekColumn && card.sameDay(date, card.selected)
                        readonly property bool weekend: !weekColumn && index % 8 >= 6
                        readonly property bool hasEvents: !weekColumn && card.eventsOn(date).length > 0

                        width: grid.cellWidth
                        height: grid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: 6
                            visible: !cell.weekColumn
                            color: cell.isToday
                                ? card.accent
                                : (dayMouse.containsMouse ? card.hoverBg : "transparent")
                            border.width: cell.isSelected && !cell.isToday ? 1 : 0
                            border.color: card.accent
                        }

                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: cell.hasEvents ? -2 : 0
                            text: cell.weekColumn ? card.isoWeek(cell.date) : cell.date.getDate()
                            color: cell.isToday
                                ? card.background
                                : (cell.weekColumn ? card.muted : card.foreground)
                            opacity: cell.weekColumn ? 0.7 : (cell.inMonth ? (cell.weekend ? 0.75 : 1) : 0.35)
                            font.pixelSize: cell.weekColumn ? 10 : 12
                            font.weight: cell.isToday || cell.isSelected ? Font.DemiBold : Font.Normal
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            width: 4
                            height: 4
                            radius: 2
                            visible: cell.hasEvents
                            color: cell.isToday ? card.background : card.accent
                            opacity: cell.inMonth || cell.isToday ? 1 : 0.35
                        }

                        MouseArea {
                            id: dayMouse

                            anchors.fill: parent
                            enabled: !cell.weekColumn
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                card.selected = card.startOfDay(cell.date)
                                if (!cell.inMonth) card.viewMonth = new Date(cell.date.getFullYear(), cell.date.getMonth(), 1)
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            width: 1
            height: parent.height
            color: card.lineBg
        }

        // -- a kijelolt nap -------------------------------------------------
        Column {
            id: dayColumn

            width: parent.width - monthColumn.width - 21 - parent.spacing * 2
            height: parent.height
            spacing: 14

            Column {
                id: dayHeader

                width: parent.width
                spacing: 2

                Text {
                    text: card.selected.getDate()
                    color: card.foreground
                    font.family: "serif"
                    font.pixelSize: 44
                    font.weight: Font.Medium
                }

                Text {
                    width: parent.width
                    text: Qt.formatDate(card.selected, "dddd") + ", " + card.monthName(card.selected)
                    color: card.foreground
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }

                Text {
                    text: card.relativeText(card.selected)
                    color: card.accent
                    font.pixelSize: 12
                }
            }

            Column {
                width: parent.width
                spacing: 8
                visible: !card.eventsEnabled

                Repeater {
                    model: [
                        { "label": qsTr("Week"), "value": card.isoWeek(card.selected) },
                        { "label": qsTr("Day of year"), "value": card.dayOfYear(card.selected) + " / " + card.daysInYear(card.selected.getFullYear()) },
                        { "label": qsTr("Moon"), "value": card.moonPhase(card.selected) }
                    ]

                    Item {
                        required property var modelData

                        width: parent.width
                        height: 18

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: card.muted
                            font.pixelSize: 11
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.value
                            color: card.foreground
                            font.pixelSize: 11
                        }
                    }
                }
            }

            // Az ev haladasa a kijelolt napig.
            Column {
                width: parent.width
                spacing: 6
                visible: !card.eventsEnabled

                Item {
                    width: parent.width
                    height: 14

                    Text {
                        anchors.left: parent.left
                        text: qsTr("Year %1").arg(card.selected.getFullYear())
                        color: card.muted
                        font.pixelSize: 10
                    }

                    Text {
                        anchors.right: parent.right
                        text: Math.round(card.dayOfYear(card.selected) / card.daysInYear(card.selected.getFullYear()) * 100) + "%"
                        color: card.muted
                        font.pixelSize: 10
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 4
                    radius: 2
                    color: card.lineBg

                    Rectangle {
                        width: parent.width * card.dayOfYear(card.selected) / card.daysInYear(card.selected.getFullYear())
                        height: parent.height
                        radius: 2
                        color: card.accent

                        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    }
                }
            }

            // A kijelolt nap esemenyei. Kattintasra a Google Naptarban nyilnak meg.
            Item {
                width: parent.width
                height: dayColumn.height - dayHeader.height - dayColumn.spacing
                visible: card.eventsEnabled

                ListView {
                    id: eventList

                    anchors.fill: parent
                    clip: true
                    spacing: 4
                    boundsBehavior: Flickable.StopAtBounds
                    model: card.eventsOn(card.selected)

                    delegate: Rectangle {
                        id: eventRow

                        required property var modelData

                        width: eventList.width
                        height: 44
                        radius: 6
                        color: eventMouse.containsMouse ? card.hoverBg : "transparent"

                        Rectangle {
                            id: eventBar

                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: 28
                            radius: 1.5
                            color: eventRow.modelData.color || card.accent
                        }

                        Column {
                            anchors.left: eventBar.right
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                width: parent.width
                                text: eventRow.modelData.title
                                textFormat: Text.PlainText
                                color: card.foreground
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: card.eventTime(eventRow.modelData, card.selected)
                                    + (eventRow.modelData.location ? " · " + eventRow.modelData.location : "")
                                textFormat: Text.PlainText
                                color: card.muted
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: eventMouse

                            anchors.fill: parent
                            enabled: eventRow.modelData.link !== ""
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.eventActivated(eventRow.modelData.link)
                        }
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.topMargin: 4
                    width: parent.width
                    visible: eventList.count === 0
                    text: card.keyringLocked
                        ? qsTr("The keyring is locked. Unlock it on the Calendar page in Settings.")
                        : qsTr("Nothing scheduled.")
                    wrapMode: Text.WordWrap
                    color: card.muted
                    font.pixelSize: 11
                }
            }
        }
    }
}

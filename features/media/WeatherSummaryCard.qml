import QtQuick
import "../../ui" as SharedUi

// Kompakt idojaras a dashboardon: a mostani allapot es a kovetkezo napok.
SharedUi.DashPanel {
    id: card

    property string location: ""
    property string temp: "--°"
    property string description: ""
    property var forecast: []

    // A backend "min°/max°" alakban adja a napi ertekeket.
    function bounds(entry) {
        var parts = entry && entry.temp ? entry.temp.split("/") : []
        return parts.length === 2 ? { "low": parts[0], "high": parts[1] } : null
    }

    function weekday(offset) {
        var date = new Date()
        date.setDate(date.getDate() + offset)
        return Qt.formatDate(date, "ddd")
    }

    function weatherIcon(text) {
        var lower = (text || "").toLowerCase()
        if (lower.indexOf("rain") !== -1 || lower.indexOf("shower") !== -1 || lower.indexOf("drizzle") !== -1) return "☂"
        if (lower.indexOf("cloud") !== -1 || lower.indexOf("fog") !== -1) return "☁"
        if (lower.indexOf("snow") !== -1) return "❄"
        if (lower.indexOf("storm") !== -1 || lower.indexOf("thunder") !== -1) return "ϟ"
        return "☼"
    }

    readonly property var today: forecast.length > 0 ? bounds(forecast[0]) : null
    readonly property var upcoming: forecast.slice(1, 5)

    title: "WEATHER"
    trailing: location

    Row {
        id: now

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 52
        spacing: 12

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: card.weatherIcon(card.description)
            color: card.accent
            font.pixelSize: 30
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: card.temp
            color: card.foreground
            font.pixelSize: 34
            font.weight: Font.Light
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: now.width - x
            spacing: 2

            Text {
                width: parent.width
                text: card.description || qsTr("Loading…")
                color: card.foreground
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: card.today !== null
                text: card.today ? qsTr("%1 / %2").arg(card.today.low).arg(card.today.high) : ""
                color: card.muted
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
    }

    Rectangle {
        id: divider

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: now.bottom
        anchors.topMargin: 12
        height: 1
        color: Qt.rgba(1, 1, 1, 0.06)
    }

    Row {
        id: days

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: divider.bottom
        anchors.topMargin: 12
        visible: card.upcoming.length > 0

        Repeater {
            model: card.upcoming

            Column {
                id: day

                required property int index
                required property var modelData
                readonly property var range: card.bounds(modelData)

                width: days.width / Math.max(1, card.upcoming.length)
                spacing: 4

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: card.weekday(day.index + 1)
                    color: card.muted
                    font.pixelSize: 10
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: day.modelData.icon
                    color: card.foreground
                    font.pixelSize: 15
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: day.range ? day.range.high : day.modelData.temp
                    color: card.foreground
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: day.range !== null
                    text: day.range ? day.range.low : ""
                    color: card.muted
                    font.pixelSize: 10
                }
            }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: divider.bottom
        anchors.topMargin: 16
        visible: card.upcoming.length === 0
        text: qsTr("Forecast unavailable")
        color: card.muted
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
    }
}

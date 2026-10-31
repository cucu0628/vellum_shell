import QtQuick
import "../../ui" as SharedUi

// Az idojaras kinagyitott nezete. Balra a mostani allapot minden merese es a
// napfeny (napkelte-napnyugta kozti sav a nap helyzetevel), jobbra az ot napos
// elorejelzes kozos skalan, hogy a napok egymashoz merhetok legyenek.
SharedUi.DashPanel {
    id: card

    property string location: ""
    property string temp: "--°"
    property string feels: ""
    property string description: ""
    property string humidity: "--%"
    property string wind: "-- km/h"
    property string pressure: "-- hPa"
    property string precip: "--%"
    property string sunrise: "--:--"
    property string sunset: "--:--"
    property var forecast: []
    property var now: new Date()

    readonly property color lineBg: Qt.rgba(1, 1, 1, 0.07)

    function weatherIcon(text) {
        var lower = (text || "").toLowerCase()
        if (lower.indexOf("rain") !== -1 || lower.indexOf("shower") !== -1 || lower.indexOf("drizzle") !== -1) return "☂"
        if (lower.indexOf("cloud") !== -1 || lower.indexOf("fog") !== -1) return "☁"
        if (lower.indexOf("snow") !== -1) return "❄"
        if (lower.indexOf("storm") !== -1 || lower.indexOf("thunder") !== -1) return "ϟ"
        return "☼"
    }

    // "min°/max°" -> {low, high} szamokkal.
    function range(entry) {
        var parts = entry && entry.temp ? entry.temp.split("/") : []
        if (parts.length !== 2) return null
        var low = parseInt(parts[0], 10)
        var high = parseInt(parts[1], 10)
        return isNaN(low) || isNaN(high) ? null : { "low": low, "high": high }
    }

    function weekday(offset) {
        if (offset === 0) return qsTr("Today")
        var date = new Date()
        date.setDate(date.getDate() + offset)
        return Qt.formatDate(date, "dddd")
    }

    // "HH:MM" -> perc az ejfel ota.
    function minutes(clock) {
        var parts = (clock || "").split(":")
        if (parts.length !== 2) return -1
        var h = parseInt(parts[0], 10)
        var m = parseInt(parts[1], 10)
        return isNaN(h) || isNaN(m) ? -1 : h * 60 + m
    }

    readonly property int sunriseMinutes: minutes(sunrise)
    readonly property int sunsetMinutes: minutes(sunset)
    readonly property int nowMinutes: now.getHours() * 60 + now.getMinutes()
    readonly property bool hasSun: sunriseMinutes >= 0 && sunsetMinutes > sunriseMinutes
    readonly property real dayProgress: hasSun
        ? Math.max(0, Math.min(1, (nowMinutes - sunriseMinutes) / (sunsetMinutes - sunriseMinutes)))
        : 0
    readonly property string daylightText: {
        if (!hasSun) return ""
        if (nowMinutes < sunriseMinutes) return qsTr("Sunrise in %1").arg(duration(sunriseMinutes - nowMinutes))
        if (nowMinutes > sunsetMinutes) return qsTr("After sunset")
        return qsTr("%1 of daylight left").arg(duration(sunsetMinutes - nowMinutes))
    }

    function duration(total) {
        var h = Math.floor(total / 60)
        var m = total % 60
        return h > 0 ? h + "h " + m + "m" : m + "m"
    }

    // A kozos skala az osszes nap minimuma es maximuma.
    readonly property var tempScale: {
        var low = 1000
        var high = -1000
        for (var i = 0; i < forecast.length; i++) {
            var r = range(forecast[i])
            if (!r) continue
            low = Math.min(low, r.low)
            high = Math.max(high, r.high)
        }
        return high > low ? { "low": low, "high": high } : { "low": 0, "high": 1 }
    }

    title: "WEATHER"
    trailing: location
    closable: true

    Row {
        anchors.fill: parent
        spacing: 20

        // -- most ---------------------------------------------------------
        Column {
            id: nowColumn

            width: Math.round((parent.width - 21) * 0.46)
            spacing: 14

            Row {
                spacing: 14

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.weatherIcon(card.description)
                    color: card.accent
                    font.pixelSize: 40
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.temp
                    color: card.foreground
                    font.pixelSize: 46
                    font.weight: Font.Light
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: card.description || qsTr("Loading…")
                        color: card.foreground
                        font.pixelSize: 13
                    }

                    Text {
                        text: card.feels
                        color: card.muted
                        font.pixelSize: 11
                        visible: text !== ""
                    }
                }
            }

            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 12
                rowSpacing: 10

                Repeater {
                    model: [
                        { "icon": "󰖎", "label": qsTr("Humidity"), "value": card.humidity },
                        { "icon": "󰖝", "label": qsTr("Wind"), "value": card.wind },
                        { "icon": "󰏈", "label": qsTr("Pressure"), "value": card.pressure },
                        { "icon": "󰖗", "label": qsTr("Precipitation"), "value": card.precip }
                    ]

                    Rectangle {
                        required property var modelData

                        width: (parent.width - 12) / 2
                        height: 44
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.04)

                        Text {
                            id: readingIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.icon
                            color: card.muted
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 15
                        }

                        Column {
                            anchors.left: readingIcon.right
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                text: modelData.label
                                color: card.muted
                                font.pixelSize: 10
                            }

                            Text {
                                text: modelData.value
                                color: card.foreground
                                font.pixelSize: 13
                            }
                        }
                    }
                }
            }

            // Napfeny: napkelte es napnyugta kozott a nap mostani helye.
            Column {
                width: parent.width
                spacing: 6
                visible: card.hasSun

                Item {
                    width: parent.width
                    height: 14

                    Text {
                        anchors.left: parent.left
                        text: qsTr("Sunrise %1").arg(card.sunrise)
                        color: card.muted
                        font.pixelSize: 10
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: card.daylightText
                        color: card.foreground
                        font.pixelSize: 10
                    }

                    Text {
                        anchors.right: parent.right
                        text: qsTr("Sunset %1").arg(card.sunset)
                        color: card.muted
                        font.pixelSize: 10
                    }
                }

                Item {
                    width: parent.width
                    height: 10

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 4
                        radius: 2
                        color: card.lineBg

                        Rectangle {
                            width: parent.width * card.dayProgress
                            height: parent.height
                            radius: 2
                            color: card.accent
                            opacity: 0.6
                        }
                    }

                    Rectangle {
                        x: (parent.width - width) * card.dayProgress
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10
                        height: 10
                        radius: 5
                        color: card.accent
                        visible: card.nowMinutes >= card.sunriseMinutes && card.nowMinutes <= card.sunsetMinutes
                    }
                }
            }
        }

        Rectangle {
            width: 1
            height: parent.height
            color: card.lineBg
        }

        // -- elorejelzes ----------------------------------------------------
        Column {
            id: forecastColumn

            width: parent.width - nowColumn.width - 21 - parent.spacing * 2
            spacing: 4

            Repeater {
                model: card.forecast

                Item {
                    id: dayRow

                    required property int index
                    required property var modelData
                    readonly property var span: card.range(modelData)

                    width: forecastColumn.width
                    height: 40

                    Text {
                        id: dayName
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 92
                        text: card.weekday(dayRow.index)
                        color: dayRow.index === 0 ? card.foreground : card.muted
                        font.pixelSize: 12
                        font.weight: dayRow.index === 0 ? Font.Medium : Font.Normal
                        elide: Text.ElideRight
                    }

                    Text {
                        id: dayIcon
                        anchors.left: dayName.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        text: dayRow.modelData.icon
                        color: card.foreground
                        font.pixelSize: 15
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        id: lowText
                        anchors.left: dayIcon.right
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        text: dayRow.span ? dayRow.span.low + "°" : ""
                        color: card.muted
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignRight
                    }

                    // A nap min-max savja a kozos skalan.
                    Rectangle {
                        id: track
                        anchors.left: lowText.right
                        anchors.leftMargin: 10
                        anchors.right: highText.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        height: 4
                        radius: 2
                        color: card.lineBg

                        Rectangle {
                            readonly property real span: card.tempScale.high - card.tempScale.low
                            x: dayRow.span ? parent.width * (dayRow.span.low - card.tempScale.low) / span : 0
                            width: dayRow.span ? Math.max(6, parent.width * (dayRow.span.high - dayRow.span.low) / span) : 0
                            height: parent.height
                            radius: 2
                            color: card.accent
                        }
                    }

                    Text {
                        id: highText
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        text: dayRow.span ? dayRow.span.high + "°" : dayRow.modelData.temp
                        color: card.foreground
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            Text {
                visible: card.forecast.length === 0
                text: qsTr("Forecast unavailable")
                color: card.muted
                font.pixelSize: 11
            }
        }
    }
}

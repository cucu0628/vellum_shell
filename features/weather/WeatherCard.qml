import QtQuick
import "../../ui" as SharedUi

Item {
    id: card

    property var theme: null
    property var now: new Date()
    property string location: "Veszprem"
    property string temp: "33°"
    property string feels: "Feels like 33°"
    property string description: "Clear Sky"
    property string humidity: "27%"
    property string wind: "8 km/h"
    property string pressure: "992 hPa"
    property string precip: "0%"
    property string sunrise: "04:53"
    property string sunset: "20:47"
    property var forecast: []

    readonly property string panelBg: theme ? theme.background : "#11130f"
    readonly property string surface: theme && theme.surface ? theme.surface : "#191b16"
    readonly property string foreground: theme ? theme.foreground : "#e8ddc7"
    readonly property string accent: theme ? theme.accent : "#b7372f"
    readonly property string muted: theme && theme.muted ? theme.muted : "#958b7a"

    function two(value) {
        return value.toString().padStart(2, "0")
    }

    function weatherIcon(text) {
        var lower = (text || "").toLowerCase()
        if (lower.indexOf("rain") !== -1 || lower.indexOf("shower") !== -1) return "☂"
        if (lower.indexOf("cloud") !== -1 || lower.indexOf("overcast") !== -1) return "☁"
        if (lower.indexOf("snow") !== -1) return "❄"
        if (lower.indexOf("storm") !== -1 || lower.indexOf("thunder") !== -1) return "ϟ"
        return "☼"
    }

    Column {
        anchors.fill: parent
        spacing: 12

        Row {
            width: parent.width
            height: 172
            spacing: 12

            SharedUi.DashPanel {
                width: (parent.width - 12) * 0.56
                height: parent.height
                theme: card.theme
                title: "CONDITIONS"
                kanji: ""
                trailing: card.location.toUpperCase()
                editorial: true

                Text {
                    id: conditionGlyph
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.weatherIcon(card.description)
                    color: card.accent
                    font.pixelSize: 58
                    font.weight: Font.Light
                }

                Column {
                    anchors.left: conditionGlyph.right
                    anchors.leftMargin: 20
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        text: card.temp
                        color: card.foreground
                        font.pixelSize: 42
                        font.weight: Font.Light
                    }

                    Text {
                        width: parent.width
                        text: card.description
                        color: card.accent
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: card.feels
                        color: card.muted
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    Text {
                        text: card.now.getFullYear() + "." + card.two(card.now.getMonth() + 1) + "." + card.two(card.now.getDate()) + "  /  " + card.two(card.now.getHours()) + ":" + card.two(card.now.getMinutes())
                        color: card.muted
                        font.pixelSize: 9
                        font.letterSpacing: 1
                    }
                }
            }

            SharedUi.DashPanel {
                width: (parent.width - 12) * 0.44
                height: parent.height
                theme: card.theme
                title: "READINGS"
                kanji: ""
                editorial: true

                Grid {
                    anchors.fill: parent
                    columns: 2
                    rowSpacing: 8
                    columnSpacing: 8

                    Repeater {
                        model: [
                            { label: "HUMIDITY", value: card.humidity },
                            { label: "WIND", value: card.wind },
                            { label: "PRESSURE", value: card.pressure },
                            { label: "PRECIP", value: card.precip }
                        ]

                        SharedUi.DashTile {
                            width: (parent.width - 8) / 2
                            height: (parent.height - 8) / 2
                            theme: card.theme
                            value: modelData.value
                            label: modelData.label
                        }
                    }
                }
            }
        }

        Row {
            width: parent.width
            height: parent.height - 184
            spacing: 12

            SharedUi.DashPanel {
                width: 210
                height: parent.height
                theme: card.theme
                title: "SUN CYCLE"
                kanji: ""
                editorial: true

                Column {
                    anchors.fill: parent
                    spacing: 10

                    SharedUi.DashTile {
                        width: parent.width
                        height: (parent.height - 10) / 2
                        theme: card.theme
                        glyph: "☼"
                        value: card.sunrise
                        label: "RISE"
                    }

                    SharedUi.DashTile {
                        width: parent.width
                        height: (parent.height - 10) / 2
                        theme: card.theme
                        glyph: "☾"
                        value: card.sunset
                        label: "SET"
                    }
                }
            }

            SharedUi.DashPanel {
                width: parent.width - 222
                height: parent.height
                theme: card.theme
                title: "FORECAST"
                kanji: ""
                trailing: card.forecast.length > 0 ? card.forecast.length + " DAYS" : ""
                editorial: true

                Row {
                    id: forecastRow
                    anchors.fill: parent
                    spacing: 8

                    Repeater {
                        model: card.forecast

                        SharedUi.DashTile {
                            width: (forecastRow.width - forecastRow.spacing * Math.max(0, card.forecast.length - 1)) / Math.max(1, card.forecast.length)
                            height: forecastRow.height
                            theme: card.theme
                            heading: modelData.day
                            glyph: modelData.icon
                            value: modelData.temp
                        }
                    }
                }

                Text {
                    anchors.fill: parent
                    visible: card.forecast.length === 0
                    text: "Forecast unavailable"
                    color: card.muted
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}

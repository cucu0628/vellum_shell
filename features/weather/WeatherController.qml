import QtQuick

// Idojaras a Rust backend `weather` topicjabol.
//
// Korabban ez a fajl harom `curl` processzt inditott (hely, geokodolas,
// elorejelzes) minden panelnyitaskor. A backend egy HTTP klienst tart nyitva,
// a geokodolast es az elorejelzest is gyorsitotarazza.
//
// A megjelenitendo szoveg formazasa is a backendbe kerult, ezert ez a fajl mar
// tiszta binding. A publikus property-nevek valtozatlanok.
Item {
    id: weather

    required property var backend
    property bool active: false

    readonly property var topic: backend && backend.topics.weather ? backend.topics.weather : ({})

    readonly property string location: topic.location || "Budapest"
    readonly property string temp: topic.temp || "--°"
    readonly property string feels: topic.feels || ""
    readonly property string description: topic.description || ""
    readonly property string humidity: topic.humidity || "--%"
    readonly property string wind: topic.wind || "-- km/h"
    readonly property string pressure: topic.pressure || "-- hPa"
    readonly property string precip: topic.precip || "--%"
    readonly property string sunrise: topic.sunrise || "--:--"
    readonly property string sunset: topic.sunset || "--:--"
    readonly property var forecast: topic.forecast || []

    width: 0
    height: 0
    visible: false

    // Lazy topic: a backend csak akkor kerdezi le az API-t, ha valaki nezi.
    onActiveChanged: {
        if (!backend) return
        if (active) backend.subscribe("weather")
        else backend.unsubscribe("weather")
    }

    Component.onDestruction: if (backend && active) backend.unsubscribe("weather")

    // A backend maga frissit; ezek csak azert maradtak meg, hogy a korabbi
    // hivasi pontok ne torjenek el.
    function refresh() {}
    function loadLocation() {}
}

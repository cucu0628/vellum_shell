.pragma library

// A kepernyovedo temai. A "shapes" a shell temajanak szineit hasznalja, a
// tobbi sajat, felismerheto palettat. Az anyagok sorrendje a jelenet
// shaderjenek fejlecet koveti (shaders/<scene>.frag).
//
// A Settings (features/settings/SystemPage.qml) ugyanezeket az azonositokat
// irja a `screensaver-theme` fajlba; uj tema eseten ott is fel kell venni.

var seasonal = {
    "christmas": {
        background: "#080d18",
        light: "#fff7e3",
        highlight: 0.55,
        // fenyo, piros gomb, arany, torzs, ho
        palette: ["#2f9e5b", "#e0404f", "#f2c14e", "#9a6a45", "#dfe8f5"]
    },
    "newyear": {
        background: "#07060f",
        light: "#ffffff",
        highlight: 0.6,
        // epuletek, ablakok, arany, piros, turkiz, lila
        palette: ["#5b6178", "#f0c766", "#ffd36b", "#ff5a6a", "#4fd8e0", "#c48cff"]
    },
    "winter": {
        background: "#060a13",
        light: "#ffffff",
        highlight: 0.7,
        // jegkristaly, ho
        palette: ["#8ccaf5", "#d6e6f7"]
    },
    "valentine": {
        background: "#12070c",
        light: "#ffe3ea",
        highlight: 0.6,
        // sziv, lebego szivek
        palette: ["#e8355e", "#f58fb0"]
    },
    "easter": {
        background: "#0b0d0b",
        light: "#fffaf0",
        highlight: 0.45,
        // tojas savjai (rozsaszin, menta, sarga, lila), pottyok es sziromok, fu
        palette: ["#f2789f", "#5fcf9c", "#f4cf4f", "#a283f0", "#fff3ea", "#6fae5c"]
    },
    "summer": {
        background: "#0d0a12",
        light: "#fff4d6",
        highlight: 0.55,
        // nap, tenger, hullamtaraj, csillogas, siralyok
        palette: ["#ffa53d", "#2e86b8", "#8fdcf0", "#ffd479", "#cfc8d8"]
    },
    // Monitorokon atnyulo jelenet; az evszak-naptar nem valasztja.
    "orbit": {
        background: "#05060c",
        light: "#fff8e8",
        highlight: 0.55,
        // bolygo, gyuru, hold, csillagok, ustokos
        palette: ["#e0ae68", "#c9b393", "#aeb9cc", "#7e88a0", "#9fe8ff"]
    },
    "autumn": {
        background: "#0c0806",
        light: "#fff0c2",
        highlight: 0.5,
        // tok, szar, belso feny, levelek, denever
        palette: ["#e8742a", "#6f8a3a", "#ffc94a", "#c8562a", "#7a6a8c"]
    }
}

// Ev kozbeni idoszakok: honap (1-12) es nap, ameddig az adott tema tart.
// Az elso illeszkedo nyer; a sorrend az ev sorrendje.
var calendar = [
    { until: [1, 6], theme: "newyear" },
    { until: [2, 6], theme: "winter" },
    { until: [2, 15], theme: "valentine" },
    { until: [3, 19], theme: "winter" },
    { until: [5, 31], theme: "easter" },
    { until: [8, 31], theme: "summer" },
    { until: [11, 30], theme: "autumn" },
    { until: [12, 26], theme: "christmas" },
    { until: [12, 31], theme: "newyear" }
]

function known(name) {
    return name === "shapes" || seasonal.hasOwnProperty(name)
}

function seasonFor(date) {
    var month = date.getMonth() + 1
    var day = date.getDate()
    for (var i = 0; i < calendar.length; i++) {
        var until = calendar[i].until
        if (month < until[0] || (month === until[0] && day <= until[1])) return calendar[i].theme
    }
    return "shapes"
}

// A beallitott ertekbol a tenylegesen futo jelenet; ismeretlen ertek eseten
// az alapjelenet.
function resolve(setting, date) {
    if (setting === "auto") return seasonFor(date)
    return known(setting) ? setting : "shapes"
}

// A jelenet szinei. A shell temaja csak a "shapes" jelenetet szinezi.
function colors(scene, shellTheme) {
    if (seasonal.hasOwnProperty(scene)) return seasonal[scene]
    return {
        background: shellTheme.background,
        light: shellTheme.foreground,
        highlight: 1,
        palette: [shellTheme.accent, shellTheme.outline]
    }
}

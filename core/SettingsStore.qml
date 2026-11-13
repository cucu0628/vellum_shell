import QtQuick
import Quickshell.Io

// A shell felhasznaloi beallitasai egyetlen `settings.json`-ban, szekciokra
// bontva (weather, lockScreen, screensaver, media, bar). A fo shell egy
// peldanyt hoz letre es adja tovabb; csak az ir, igy a szekciok nem irjak felul
// egymast. A fajlt figyeljuk, ezert a scriptek (`lockscreen-monitor set`,
// `weather-location`) vagy egy kezi szerkesztes is eloben megjelenik.
//
// A temat, a hatterkepet es a Hyprland-beallitasokat a daemon tranzakcioban
// irja; azok szandekosan kulon fajlban maradnak.
QtObject {
    id: store

    required property string shellDir
    // Csak a fo shell peldanya hozza at a regi, beallitasonkent kulon fajlokat.
    property bool migrateLegacy: false

    readonly property string path: shellDir !== "" ? shellDir + "/settings.json" : ""
    property var data: ({})
    property bool loaded: false
    // Hibas JSON eseten nem irunk: egy valtoztatas kulonben a teljes, kezzel
    // elrontott fajlt egyetlen kulcsra cserelne.
    property bool invalid: false

    signal saveFailed()

    function section(name) {
        var group = data[name];
        return group && typeof group === "object" && !Array.isArray(group) ? group : ({});
    }

    function value(sectionName, key, fallback) {
        var group = section(sectionName);
        var result = group[key];
        return result === undefined || result === null ? fallback : result;
    }

    function setValue(sectionName, key, nextValue) {
        var group = Object.assign({}, section(sectionName));
        group[key] = nextValue;
        setSection(sectionName, group);
    }

    function setSection(sectionName, group) {
        if (invalid || path === "") {
            saveFailed();
            return;
        }
        var next = Object.assign({}, data);
        next.version = 1;
        next[sectionName] = group;
        data = next;
        file.setText(JSON.stringify(next, null, 2) + "\n");
    }

    function reload() {
        file.reload();
    }

    function parse(text) {
        var trimmed = (text || "").trim();
        if (trimmed === "") {
            data = {};
            invalid = false;
        } else {
            try {
                var parsed = JSON.parse(trimmed);
                if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
                    throw new Error("not an object");
                data = parsed;
                invalid = false;
            } catch (error) {
                console.warn("Vellum: a settings.json nem ertelmezheto:", error);
                invalid = true;
            }
        }
        loaded = true;
    }

    property FileView file: FileView {
        path: store.path
        atomicWrites: true
        watchChanges: true
        printErrors: false
        onLoaded: store.parse(text())
        onFileChanged: reload()
        // Hianyzo fajl: minden alapertelmezett, az elso valtoztatas hozza letre.
        onLoadFailed: {
            store.data = {};
            store.invalid = false;
            store.loaded = true;
        }
        onSaveFailed: store.saveFailed()
    }

    property Process migration: Process {
        command: [store.shellDir + "/scripts/settings-migrate"]
        // Egy nem letezo fajl letrejottet a figyelo nem latja, ezert kezzel olvasunk.
        onExited: (exitCode) => {
            if (exitCode === 0)
                store.reload();
        }
    }

    Component.onCompleted: if (migrateLegacy && shellDir !== "") migration.running = true
}

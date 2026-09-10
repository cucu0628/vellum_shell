import QtQuick

// A shell es a kulso segedprogramok kozos utvonalai. A telepitesi helyet csak
// itt szamoljuk ki, igy az athelyezett checkout ugyanugy mukodik minden
// feature-ben.
QtObject {
    required property string homeDir
    property string configHomeOverride: ""
    property string stateHomeOverride: ""
    property string cacheHomeOverride: ""
    property string shellDirOverride: ""

    readonly property string configHome: configHomeOverride || (homeDir + "/.config")
    readonly property string stateHome: stateHomeOverride || (homeDir + "/.local/state")
    readonly property string cacheHome: cacheHomeOverride || (homeDir + "/.cache")
    readonly property string shellDir: shellDirOverride
        || (configHome + "/quickshell/vellum_shell")
    readonly property string scriptsDir: shellDir + "/scripts"
    readonly property string shellEntry: shellDir + "/shell.qml"
}

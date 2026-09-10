import QtQuick
import QtTest
import "../../core" as Core

TestCase {
    name: "Paths"

    Core.Paths {
        id: paths
        homeDir: "/home/test user"
    }

    function test_xdg_defaults_follow_home() {
        compare(paths.configHome, "/home/test user/.config")
        compare(paths.stateHome, "/home/test user/.local/state")
        compare(paths.cacheHome, "/home/test user/.cache")
        compare(paths.shellDir, "/home/test user/.config/quickshell/vellum_shell")
    }

    function test_explicit_shell_directory_is_shared_verbatim() {
        paths.shellDirOverride = "/opt/vellum shell"
        compare(paths.shellDir, "/opt/vellum shell")
        compare(paths.scriptsDir, "/opt/vellum shell/scripts")
        compare(paths.shellEntry, "/opt/vellum shell/shell.qml")
        paths.shellDirOverride = ""
    }
}

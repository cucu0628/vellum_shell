import QtQuick
import QtTest
import "../../features/launcher" as Launcher

TestCase {
    name: "LauncherActions"

    Launcher.LauncherActions {
        id: actions
        homeDir: "/home/test user"
        shellDir: "/opt/vellum shell"
    }

    function action(name) {
        for (var i = 0; i < actions.items.length; i++) {
            if (actions.items[i].name === name)
                return actions.items[i]
        }
        return null
    }

    function test_paths_remain_single_arguments() {
        compare(action("settings").command,
            ["quickshell", "ipc", "--path", "/opt/vellum shell/shell.qml", "call", "settings", "toggle"])
        compare(action("files").command, ["xdg-open", "/home/test user"])
        compare(action("install package").command,
            ["/opt/vellum shell/scripts/floating-terminal", "/opt/vellum shell/scripts/pkg-install"])
    }

    function test_power_actions_are_argv_arrays() {
        compare(action("suspend").command, ["systemctl", "suspend"])
        compare(action("logout").command, ["hyprctl", "dispatch", "hl.dsp.exit()"])
    }
}

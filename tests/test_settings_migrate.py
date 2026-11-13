"""A regi, kulon beallitasfajlok `settings.json`-ba emelesenek tesztjei."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "scripts/settings-migrate"


@unittest.skipUnless(shutil.which("jq"), "jq is required")
class SettingsMigrateTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.base = Path(self.directory.name)

    def tearDown(self):
        self.directory.cleanup()

    def write(self, name, text):
        (self.base / name).write_text(text)

    def migrate(self):
        return subprocess.run(
            [str(HELPER)],
            env={**os.environ, "VELLUM_SHELL_DIR": str(self.base)},
            capture_output=True, text=True, timeout=10)

    def settings(self):
        return json.loads((self.base / "settings.json").read_text())

    def test_legacy_files_are_merged_and_removed(self):
        self.write("current-weather-location", " Veszprem \n")
        self.write("lockscreen-monitor", "HDMI-A-1\n")
        self.write("lock-idle-minutes", "10\n")
        self.write("screensaver-idle-minutes", "05\n")
        self.write("screensaver-theme", "orbit\n")
        self.write("media-ignore", "Mozilla zen\n# comment\n\nMozilla zen\nspotify\n")
        self.write("bar-layout.json", json.dumps({
            "version": 1, "left": ["clock"], "center": [], "right": ["tray"], "hidden": ["battery"]}))

        result = self.migrate()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.settings(), {
            "version": 1,
            "weather": {"location": "Veszprem"},
            "lockScreen": {"monitor": "HDMI-A-1", "idleMinutes": 10},
            "screensaver": {"idleMinutes": 5, "theme": "orbit"},
            "media": {"ignoredPlayers": ["Mozilla zen", "spotify"]},
            "bar": {"left": ["clock"], "center": [], "right": ["tray"], "hidden": ["battery"]},
        })
        self.assertEqual(sorted(path.name for path in self.base.iterdir()), ["settings.json"])

    def test_existing_settings_win_over_legacy_files(self):
        self.write("settings.json", json.dumps({"version": 1, "screensaver": {"theme": "auto"}}))
        self.write("screensaver-theme", "orbit\n")
        self.write("screensaver-idle-minutes", "3\n")

        result = self.migrate()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.settings()["screensaver"], {"theme": "auto", "idleMinutes": 3})
        self.assertFalse((self.base / "screensaver-theme").exists())

    def test_nothing_to_migrate_writes_nothing(self):
        result = self.migrate()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(list(self.base.iterdir()), [])

    def test_invalid_settings_keep_legacy_files(self):
        self.write("settings.json", "{broken")
        self.write("screensaver-theme", "orbit\n")

        result = self.migrate()

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.base / "settings.json").read_text(), "{broken")
        self.assertTrue((self.base / "screensaver-theme").exists())

    def test_invalid_bar_layout_is_left_for_repair(self):
        self.write("bar-layout.json", "{broken")
        self.write("lock-idle-minutes", "abc\n")

        result = self.migrate()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.settings(), {"version": 1})
        self.assertTrue((self.base / "bar-layout.json").exists())
        self.assertFalse((self.base / "lock-idle-minutes").exists())


if __name__ == "__main__":
    unittest.main()

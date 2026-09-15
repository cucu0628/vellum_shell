"""A disztribuciofuggetlen energia-profil seged tesztjei."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "scripts/power-profile"


class PowerProfileTests(unittest.TestCase):
    def run_helper(self, scripts, *arguments):
        with tempfile.TemporaryDirectory() as directory:
            bindir = Path(directory)
            for name in ("bash", "grep", "sed"):
                (bindir / name).symlink_to(Path("/usr/bin") / name)
            for name, contents in scripts.items():
                command = bindir / name
                command.write_text("#!/usr/bin/bash\nset -euo pipefail\n" + contents)
                command.chmod(0o755)

            log = bindir / "log"
            result = subprocess.run(
                [str(HELPER), *arguments],
                env={"PATH": str(bindir), "VELLUM_COMMAND_LOG": str(log)},
                capture_output=True, text=True, timeout=5)
            return result, log.read_text() if log.exists() else ""

    def test_powerprofilesctl_is_used_when_available(self):
        command = """
case ${1:-} in
  get) printf 'balanced\\n' ;;
  list) printf '  power-saver:\\n* balanced:\\n  performance:\\n' ;;
  set) printf '%s\\n' "$*" >> "$VELLUM_COMMAND_LOG" ;;
esac
"""
        listed, _ = self.run_helper({"powerprofilesctl": command}, "list")
        self.assertEqual(listed.returncode, 0, listed.stderr)
        self.assertEqual(
            listed.stdout,
            "active:balanced\nname:power-saver\nname:balanced\nname:performance\n")

        changed, log = self.run_helper({"powerprofilesctl": command}, "set", "performance")
        self.assertEqual(changed.returncode, 0, changed.stderr)
        self.assertEqual(log, "set performance\n")

    def test_standard_dbus_api_supports_tuned_ppd(self):
        command = """
printf '%s\\n' "$*" >> "$VELLUM_COMMAND_LOG"
case $* in
  *ActiveProfile*) printf \"(<'balanced'>,)\\n\" ;;
  *Profiles*) printf \"(<[{'Profile': <'power-saver'>}, {'Profile': <'balanced'>}, {'Profile': <'performance'>}]>,)\\n\" ;;
esac
"""
        listed, _ = self.run_helper({"gdbus": command}, "list")
        self.assertEqual(listed.returncode, 0, listed.stderr)
        self.assertEqual(
            listed.stdout,
            "active:balanced\nname:power-saver\nname:balanced\nname:performance\n")

        changed, log = self.run_helper({"gdbus": command}, "set", "power-saver")
        self.assertEqual(changed.returncode, 0, changed.stderr)
        self.assertIn("org.freedesktop.DBus.Properties.Set", log)
        self.assertIn("ActiveProfile <'power-saver'>", log)

    def test_unknown_profile_is_rejected_before_dbus(self):
        changed, log = self.run_helper({"gdbus": "exit 0\n"}, "set", "turbo")
        self.assertEqual(changed.returncode, 2)
        self.assertEqual(log, "")


if __name__ == "__main__":
    unittest.main()

"""Csak a generator Python reszet futtatja; nincs hyprctl, telepites vagy X11."""
import contextlib
import io
import json
from pathlib import Path
import shlex
import subprocess
import sys
import unittest
from unittest.mock import patch


SOURCE = (Path(__file__).resolve().parents[1] / "scripts/sddm-layout").read_text()
GENERATOR = SOURCE.split("<<'PY'\n", 1)[1].split("\nPY\n", 1)[0]


def generate(key, name="DP-1"):
    edid = bytearray(128)
    edid[54:59] = b"\x00\x00\x00\xff\x00"
    edid[59:72] = key.encode("ascii").ljust(13, b" ")
    monitors = [{"name": name, "width": 1920, "height": 1080,
                 "x": 0, "y": 0, "focused": True}]
    output = io.StringIO()
    with patch.object(sys, "argv", ["-", "", json.dumps(monitors)]), \
         patch("glob.glob", return_value=["fake-edid"]), \
         patch("builtins.open", return_value=io.BytesIO(edid)), \
         contextlib.redirect_stdout(output):
        exec(compile(GENERATOR, "sddm-layout-generator", "exec"), {})
    return output.getvalue()


class LayoutSecurityTests(unittest.TestCase):
    def test_edid_shell_metacharacters_remain_one_argument(self):
        for key in ["';echo PWN;#", "$(echo PWN)", "`echo PWN`", "tab\there"]:
            with self.subTest(key=key):
                commands = generate(key)
                expected = [key, "DP-1", "1920x1080", "0x0", "1"]
                self.assertEqual(shlex.split(commands), ["place", *expected])
                # Az Xsetup place fuggvenye helyett csak kiirjuk az argumentumokat.
                result = subprocess.run(
                    ["sh", "-c", "place() { printf '%s\\0' \"$@\"; };\n" + commands],
                    check=True, capture_output=True, timeout=5)
                self.assertEqual(result.stdout, b"".join(
                    arg.encode() + b"\0" for arg in expected))

    def test_missing_edid_keeps_primary_in_the_fifth_argument(self):
        self.assertEqual(shlex.split(generate("")),
                         ["place", "", "DP-1", "1920x1080", "0x0", "1"])

    def test_connector_name_is_quoted_too(self):
        name = "DP-1';echo PWN;#\nnext"
        self.assertEqual(shlex.split(generate("serial", name)),
                         ["place", "serial", name, "1920x1080", "0x0", "1"])


if __name__ == "__main__":
    unittest.main()

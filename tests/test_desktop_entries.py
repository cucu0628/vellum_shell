"""A desktop-mezo escape-elok tesztje; telepitot nem futtat."""
from pathlib import Path
import subprocess
import unittest


LIB = Path(__file__).resolve().parents[1] / "scripts/lib.sh"


def escape(function, value):
    return subprocess.run(
        ["bash", "-c", 'source "$1"; "$2" "$3"', "bash", str(LIB), function, value],
        capture_output=True, text=True, check=True, timeout=5).stdout


def decode_string(value):
    escapes = {"n": "\n", "r": "\r", "t": "\t", "s": " ", "\\": "\\"}
    result = []
    chars = iter(value)
    for char in chars:
        result.append(escapes[next(chars)] if char == "\\" else char)
    return "".join(result)


class DesktopEntryTests(unittest.TestCase):
    def test_metadata_cannot_add_keys_or_sections(self):
        for value in ["App\nExec=sh", "Icon\r\n[Desktop Action injected]", "a\\nb\tc"]:
            with self.subTest(value=value):
                encoded = escape("desktop_string", value)
                self.assertNotIn("\n", encoded)
                self.assertNotIn("\r", encoded)
                self.assertEqual(decode_string(encoded), value)

    def test_url_roundtrip_as_one_literal_argument(self):
        values = ['https://example.test/a%20b?x=%f&y=$HOME',
                  'https://example.test/";echo INJECTED;#',
                  'https://example.test/$(echo INJECTED)`echo INJECTED`\\tail']
        for value in values:
            with self.subTest(value=value):
                encoded = escape("desktop_exec_arg", value)
                self.assertNotIn("\n", encoded)
                quoted = decode_string(encoded)
                self.assertTrue(quoted.startswith('"') and quoted.endswith('"'))
                # A shell dupla idezese ugyanazt a negy metakaraktert oldja
                # fel. Itt csak printf fut, a szazalek-mezokodot utana oldjuk.
                result = subprocess.run(
                    ["sh", "-c", "printf '%s' " + quoted],
                    capture_output=True, text=True, check=True, timeout=5)
                self.assertEqual(result.stdout.replace("%%", "%"), value)


if __name__ == "__main__":
    unittest.main()

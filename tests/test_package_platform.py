"""Disztribuciofelismeres es csomagkezelo-diszpatch elo rendszer modositas nelkul."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "scripts/lib.sh"
INSTALLER = ROOT / "install.sh"


class PackagePlatformTests(unittest.TestCase):
    def os_release(self, directory, distro_id, id_like=""):
        path = Path(directory) / "os-release"
        path.write_text(f"ID={distro_id}\nID_LIKE=\"{id_like}\"\n")
        return path

    def platform(self, os_release):
        return subprocess.run(
            ["bash", "-c", 'source "$1"; vellum_platform', "bash", str(LIB)],
            env={**os.environ, "VELLUM_OS_RELEASE": str(os_release)},
            capture_output=True, text=True, check=True, timeout=5).stdout.strip()

    def fake_command(self, bindir, name):
        command = Path(bindir) / name
        command.write_text(
            "#!/usr/bin/env bash\n"
            "printf '%s\\0' \"$(basename \"$0\")\" \"$@\" >> \"$VELLUM_COMMAND_LOG\"\n")
        command.chmod(0o755)

    def run_helper(self, script, os_release, *arguments, commands=("sudo",)):
        with tempfile.TemporaryDirectory() as bindir:
            log = Path(bindir) / "commands"
            for command in commands:
                self.fake_command(bindir, command)
            env = {
                **os.environ,
                "PATH": f"{bindir}:/usr/bin:/bin",
                "VELLUM_OS_RELEASE": str(os_release),
                "VELLUM_COMMAND_LOG": str(log),
            }
            subprocess.run(
                [str(ROOT / "scripts" / script), *arguments], env=env,
                input="", capture_output=True, text=True, check=True, timeout=5)
            return log.read_bytes().split(b"\0")[:-1]

    def test_arch_and_fedora_are_detected_from_id_or_id_like(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(self.platform(self.os_release(directory, "cachyos", "arch")), "arch")
            self.assertEqual(self.platform(self.os_release(directory, "fedora")), "fedora")

    def test_official_package_install_uses_native_manager(self):
        with tempfile.TemporaryDirectory() as directory:
            fedora = self.os_release(directory, "fedora")
            self.assertEqual(
                self.run_helper("pkg-install", fedora, "ripgrep"),
                [b"sudo", b"dnf", b"install", b"ripgrep"])

            arch = self.os_release(directory, "cachyos", "arch")
            self.assertEqual(
                self.run_helper("pkg-install", arch, "ripgrep"),
                [b"sudo", b"pacman", b"-S", b"--needed", b"ripgrep"])

    def test_package_remove_uses_native_manager(self):
        with tempfile.TemporaryDirectory() as directory:
            fedora = self.os_release(directory, "fedora")
            self.assertEqual(
                self.run_helper("pkg-remove", fedora, "ripgrep"),
                [b"sudo", b"dnf", b"remove", b"ripgrep"])

            arch = self.os_release(directory, "arch")
            self.assertEqual(
                self.run_helper("pkg-remove", arch, "ripgrep"),
                [b"sudo", b"pacman", b"-Rns", b"ripgrep"])

    def test_community_install_uses_aur_or_copr(self):
        with tempfile.TemporaryDirectory() as directory:
            fedora = self.os_release(directory, "fedora")
            self.assertEqual(
                self.run_helper("community-install", fedora, "owner/project", "tool",
                                commands=("sudo", "dnf")),
                [b"dnf", b"copr", b"--help",
                 b"sudo", b"dnf", b"copr", b"enable", b"owner/project",
                 b"sudo", b"dnf", b"install", b"tool"])

            arch = self.os_release(directory, "arch")
            self.assertEqual(
                self.run_helper("community-install", arch, "tool", commands=("paru",)),
                [b"paru", b"-S", b"--needed", b"tool"])

    def test_fedora_installer_preserves_the_power_profile_provider(self):
        installer = INSTALLER.read_text()
        fedora_packages = installer.split("fedora_packages=(", 1)[1].split("\n)", 1)[0]

        self.assertNotIn("power-profiles-daemon", fedora_packages)
        self.assertNotIn("tuned-ppd", fedora_packages)
        self.assertNotIn("satty", fedora_packages)
        self.assertIn("rpm -q --whatprovides ppd-service", installer)
        self.assertIn("sudo dnf install tuned-ppd", installer)

    def test_fedora_hyprland_repo_is_accepted_and_refreshed(self):
        installer = INSTALLER.read_text()

        self.assertIn("sudo dnf -y copr enable lionheartp/Hyprland", installer)
        self.assertIn("sudo dnf install --refresh --setopt=install_weak_deps=False", installer)
        self.assertIn("xdg-desktop-portal-hyprland", installer)

    def test_fedora_installer_does_not_pull_another_shell(self):
        installer = INSTALLER.read_text()
        fedora_packages = installer.split("fedora_packages=(", 1)[1].split("\n)", 1)[0]

        self.assertNotIn("dolphin", fedora_packages)
        self.assertNotIn("wofi", fedora_packages)
        self.assertNotIn("nwg-panel", fedora_packages)
        self.assertEqual(installer.count("--setopt=install_weak_deps=False"), 2)


if __name__ == "__main__":
    unittest.main()

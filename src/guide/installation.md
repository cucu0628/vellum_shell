---
title: Installation
description: What Vellum needs, how the setup script installs it, the optional parts, and how to remove it cleanly.
group: Get started
order: 2
---

## Requirements

### Core

- A Wayland session running **Hyprland 0.55 or newer**. Vellum uses its native Lua configuration API (`hl.config(...)`, `hl.bind(...)`, `hl.dsp.*`).
- **Quickshell** with Hyprland, PipeWire, MPRIS, notifications, system tray, PAM, Polkit, UPower and Wayland support. Fedora 44 and newer ship it directly.
- **PipeWire**, **NetworkManager** and **udisks2**.
- **Rust** (`cargo`) to build the backend. The shell starts without it, but with no theming and no system state.
- A Nerd Font for the shell icons, preferably `Symbols Nerd Font Mono`.
- `bash`, `hyprctl` and `jq`. The backend uses `nmcli` for Wi-Fi scanning and connection changes; `jq` is used by the screenshot and lock-screen helper scripts.

The backend reads NetworkManager and udisks2 over D-Bus, so `ip`, `lsblk`, `udisksctl`, `curl` and `matugen` are not needed.

### Optional, per feature

Some features keep working without their tool; others need it.

| Feature | Commands |
| --- | --- |
| Launcher calculator | `qalc` |
| Media position control | `gdbus` |
| Sound card profiles in Settings | `pw-dump`, `wpctl` |
| Moving an application to another output | `pactl` (`libpulse` on Arch, `pulseaudio-utils` on Fedora) |
| VPN plugin password prompts (OpenVPN, OpenConnect) | `nm-applet` (not started by default) |
| Audio visualisation | `cava` |
| Battery status | UPower daemon |
| AI usage panel | `codex` and/or `claude` CLI with an active subscription login |
| Weather | Internet access to Open-Meteo (the backend makes the request) |
| Google Calendar | A browser for sign-in and a one-time Desktop OAuth client |
| Screenshot capture | `grim`, `slurp`, `magick`, `hyprctl`, `jq`; `wayfreeze` or `hyprpicker` freeze the screen during selection if present |
| Screenshot extras | `snip` (editor), `wl-copy`, `notify-send`, `xdg-user-dir` |
| Interactive utility scripts | `fzf`, Kitty |
| Package management | `pacman` plus `paru`/`yay` on Arch; `dnf` and its COPR plugin on Fedora |
| Power profiles | `powerprofilesctl` or a compatible PPD D-Bus service |
| Default applications | `xdg-mime` from `xdg-utils`; `xdg-terminal-exec` so GLib apps honour the default terminal |
| User services page | A reachable systemd user manager |
| Bluetooth settings | `blueman-manager`, Blueberry or KDE System Settings |
| Removable devices | `util-linux`, `udisks2`, `xdg-utils` |

## Install

Clone the repository to the path the shell expects:

```bash
git clone https://github.com/cucu0628/vellum_shell.git \
  "$HOME/.config/quickshell/vellum_shell"
cd "$HOME/.config/quickshell/vellum_shell"
```

See what the setup would do first. It checks every prerequisite up front and prints its plan without changing anything:

```bash
./setup.sh --dry-run
```

Then run it:

```bash
./setup.sh
```

The setup installs the packages, creates the state directories, sets up PAM and the external themes, enables the required services, builds and installs the backend, and installs the Hyprland Lua modules under `~/.config/hypr/`.

!!! note "Your own Hyprland files are kept"
    If you already have your own `~/.config/hypr/bindings.lua` or `autostart.lua`, the setup keeps them and skips Vellum's versions. The shell will then come up without its key bindings or without starting automatically. The preflight reports this, and the notice is repeated at the end of the run.

The same preflight runs before a real install, so a missing Rust toolchain or an unusable Hyprland config stops the setup before it has touched the system.

### Options

| Option | What it adds |
| --- | --- |
| `--dry-run` | Prints the plan and the preflight result, changes nothing |
| `--with-greeter` | Installs the Vellum login screen and makes greetd the display manager. See [Lock and login screen](/guide/lock-screen.html#login-screen-greetd) |
| `--with-zen` | Adds the generated Vellum chrome theme to an existing Zen Browser profile. Opt-in because it changes `user.js` |
| `--skip-packages` | Skips package installation, for Fedora Atomic once the packages are layered |

### Fedora notes

Both `setup.sh` and the package-only `install.sh` detect Arch/CachyOS and Fedora automatically. On Fedora they use DNF and enable the `lionheartp/Hyprland` COPR recommended by Hyprland upstream.

- An existing PPD-compatible power-profile service is kept; otherwise Fedora's default `tuned-ppd` is installed.
- DNF weak dependencies are disabled, so the Hyprland package cannot pull in another panel or launcher such as nwg-panel or Wofi.
- Only missing RPMs are passed to DNF, which avoids an unrelated desktop or KDE upgrade during setup.

## Wallpapers

The setup keeps a valid existing wallpaper selection. If there is none, put an image in the wallpaper directory and the shell picks the first one:

```bash
mkdir -p ~/Pictures/wallpapers
cp your-wallpaper.png ~/Pictures/wallpapers/
```

Choose between them later in the [Appearance Studio](/guide/appearance.html).

## Starting and restarting

The setup installs `~/.config/hypr/autostart.lua`. It starts the shell immediately in a running Hyprland session and automatically on later logins.

Restart a running instance with:

```bash
~/.config/quickshell/vellum_shell/scripts/theme-refresh
```

`nm-applet` is no longer started: the shell is NetworkManager's secret agent and asks for Wi-Fi, 802.1X and PPPoE passwords in its own dialog. VPN plugins with their own password dialog (OpenVPN, OpenConnect) are left to `nm-applet`; uncomment its line in `autostart.lua` if you use one.

### The backend on its own

The setup builds the backend for you. To rebuild and reinstall only the daemon, for example after pulling changes:

```bash
scripts/backend-install   # build, install and enable the user service
vellum ping               # which binary and git revision is running
```

## Removing it again

`scripts/uninstall` reverses what the setup installed: the systemd user service and the `vellum` binary, the generated Hyprland modules, the `require` lines it appended, the include and import lines it added to `kitty.conf`, `gtk.css` and `btop.conf`, the qt6ct palette and portal environment, and the generated Neovim colorscheme with its LazyVim spec.

```bash
scripts/uninstall --dry-run     # show what would be removed
scripts/uninstall               # remove it
scripts/uninstall --with-greeter --purge-state
```

The script is also the ownership manifest: anything not listed there was yours before the install and is left alone, including the repository, your wallpapers and your screenshots. Config files you modified yourself, such as your own `bindings.lua` or a `colors.lua` that is not Vellum's, are reported and kept.

# Vellum Shell

Vellum Shell is an ink-inspired desktop shell for
[Quickshell](https://quickshell.outfoxxed.me/) and Hyprland. It provides a
multi-monitor top bar, application launcher, notification center, media
dashboard, system controls, appearance management, and a separate Wayland
session lock.

The project targets Arch Linux or CachyOS with Hyprland 0.55 or newer. It uses
Hyprland's native Lua configuration API and assumes Kitty for terminal helpers.

## Preview

![Vellum Shell desktop preview](assets/Overview.png)

## Features

- Per-monitor wallpaper layers and top bars with Hyprland workspaces.
- MPRIS media status, Cava visualization, clock, network, VPN, audio,
  notifications, system tray, system monitor, optional battery status, and
  power controls.
- Application launcher with desktop-entry search and frecency ranking.
- Launcher modes for calculator (`=`), shell commands (`>`), web search (`?`),
  and emoji search (`:`).
- Clipboard history with text and image previews, activation, and deletion.
- Notification server with toasts, history, actions, unread state, and DND.
- Notification center grouping per application, with collapsible groups,
  per-group unread counts, and per-group clearing.
- Media dashboard with playback, weather, calendar, and system statistics.
- PipeWire audio mixer, NetworkManager controls, volume OSD, and Polkit agent.
- Removable-device popup with mount, unmount, open, and safe power-off actions.
- Appearance Studio for matching shell themes and wallpapers, including optional
  Matugen-generated palettes.
- Screenshot modes for smart selection, windows, workspaces, and regions.
- Multi-monitor Wayland lock screen with PAM authentication.
- Utility menu for Arch packages, AUR packages, web apps, TUI launchers,
  Bluetooth, power profiles, Hyprland keybindings, and shell configuration.

Popups are loaded on demand and coordinated so that overlapping shell surfaces
do not remain open at the same time.

## Requirements

### Core

- A Wayland session running Hyprland.
- Quickshell with Hyprland, PipeWire, MPRIS, notifications, system tray, PAM,
  Polkit, UPower, and Wayland support.
- PipeWire, NetworkManager, and udisks2.
- Rust (`cargo`) to build the backend. The shell starts without it, but with no
  theming and no system state.
- A Nerd Font for the shell icons, preferably `Symbols Nerd Font Mono`.
- Standard command-line tools such as `bash` and `hyprctl`. The backend talks to
  NetworkManager and udisks2 over D-Bus, so `nmcli`, `ip`, `lsblk`, `udisksctl`,
  `curl`, `jq`, and `matugen` are no longer needed.

### Feature dependencies

Some features remain usable when their optional tool is missing, while others
require the corresponding command:

| Feature | Commands |
| --- | --- |
| Clipboard | `cliphist`, `wl-paste`, `wl-copy` |
| Launcher calculator | `qalc` |
| Media position control | `gdbus` |
| Audio control panel | `pavucontrol` |
| Audio visualization | `cava` (optional) |
| Battery status | UPower daemon (optional) |
| AI usage panel | `codex` and/or `claude` CLI with an active subscription login |
| Weather | `curl` and internet access to Open-Meteo |
| Screenshot capture | `grim`, `slurp`, `wayfreeze`, `magick`, `hyprctl`, `jq` |
| Screenshot extras | `satty`, `wl-copy`, `notify-send`, `xdg-user-dir` |
| Interactive utility scripts | `fzf`, Kitty |
| Package management | `pacman`; `paru` or `yay` for AUR packages |
| Power profiles | `powerprofilesctl` |
| Bluetooth settings | `blueman-manager`, Blueberry, or KDE System Settings |
| Removable devices | `util-linux`, `udisks2`, `xdg-utils` |

The package helpers are Arch-specific. Hyprland integration uses the native
Lua API introduced in Hyprland 0.55 (`hl.config(...)`, `hl.bind(...)`, and
`hl.dsp.*`).

## Installation

Clone the repository to the path expected by the shell:

```bash
git clone https://git.asked.hu/asked/qs.git \
  "$HOME/.config/quickshell/vellum_shell"
```

Run the complete setup. It installs dependencies, creates state directories,
sets up PAM and external themes, enables required services, and installs the
Hyprland Lua modules under `~/.config/hypr/`:

```bash
cd "$HOME/.config/quickshell/vellum_shell"
./setup.sh
```

To install and activate the bundled SDDM theme as well:

```bash
./setup.sh --with-sddm
```

Use `./setup.sh --with-zen` to modify an existing Zen Browser profile and add
the generated Vellum chrome theme. It is opt-in because it changes `user.js`.

The setup preserves a valid existing wallpaper selection. If none exists, put
an image in the wallpaper directory; the shell selects the first image:

```bash
cp your-wallpaper.png "$HOME/Pictures/wallpapers/"
```

The setup installs `~/.config/hypr/autostart.lua`. It starts the shell
immediately in a running Hyprland session and automatically on later sessions.

Restart an already running instance with:

```bash
~/.config/quickshell/vellum_shell/scripts/theme-refresh
```

`install.sh` remains available as a package-only installer. `setup.sh` is the
recommended entry point for a fresh system.

## Usage

Bar items open their related surfaces on the selected monitor. Every major
surface is also exposed through Quickshell IPC, making it straightforward to
bind shell actions in Hyprland.

The general command format is:

```bash
quickshell ipc --path ~/.config/quickshell/vellum_shell/shell.qml call TARGET METHOD
```

### IPC reference

| Target | Methods |
| --- | --- |
| `menu` | `toggle`, `open`, `close` |
| `launcher` | `toggle`, `open`, `close` |
| `clipboard` | `toggle`, `open`, `close` |
| `style` | `theme`, `wallpaper`, `close` |
| `power` | `toggle`, `open`, `close` |
| `notifications` | `toggle`, `dnd`, `close`, `clear`, `grouping`, `expand`, `collapse` |
| `audio` | `toggle`, `open`, `close` |
| `network` | `toggle`, `open`, `close` |
| `removable` | `toggle`, `open`, `close` |
| `about` | `toggle`, `open`, `close` |
| `screenshot` | `capture`, `window`, `workspace`, `region` |

The setup installs these bindings in `~/.config/hypr/bindings.lua` using the
native Hyprland Lua API:

```lua
local shell = [[quickshell ipc --path "$HOME/.config/quickshell/vellum_shell/shell.qml" call]]
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd(shell .. " launcher toggle"))
hl.bind("SUPER + V", hl.dsp.exec_cmd(shell .. " clipboard toggle"))
hl.bind("SUPER + N", hl.dsp.exec_cmd(shell .. " notifications toggle"))
hl.bind("SUPER + P", hl.dsp.exec_cmd(shell .. " menu toggle"))
```

### Lock screen

The lock screen is hosted by the main shell and activated over IPC:

```bash
quickshell ipc --path ~/.config/quickshell/vellum_shell/shell.qml call lock lock
```

It creates a secure `WlSessionLock` surface on every monitor. One monitor shows
the password input and the others use an ambient view. Select the input monitor
through the shell menu or directly:

```bash
~/.config/quickshell/vellum_shell/scripts/lockscreen-monitor list
~/.config/quickshell/vellum_shell/scripts/lockscreen-monitor set HDMI-A-1
```

Authentication uses the dedicated PAM service named `vellum-shell`. The setup
installs `/etc/pam.d/vellum-shell`; no external lock-screen package is used.

### Login screen (SDDM)

`sddm/vellum-ink/` is an SDDM greeter theme that reuses the lock-screen visual
language: the same ensō background, shoji shutter, seal, panel, and palette.
It adds the greeter-only controls: user picker, session picker, keyboard
layout, and the power actions.

```bash
~/.config/quickshell/vellum_shell/scripts/sddm-install --preview            # test run, no root
sudo ~/.config/quickshell/vellum_shell/scripts/sddm-install --default --layout
```

`scripts/sddm-theme` regenerates `theme.conf` from the active shell palette and
runs as part of the theme switch, so the greeter follows the selected theme
automatically. It writes both the repository copy and the installed one at
`/usr/share/sddm/themes/vellum-ink/theme.conf`, which `sddm-install` chowns to the
installing user for exactly that purpose. Everything else in the installed
theme stays root-owned; re-run `sudo sddm-install` after changing the QML.

SDDM must be the active display manager. Arch installs that use
`plasma-login-manager` (`plasmalogin.service`) cannot use SDDM themes at all:

```bash
sudo systemctl disable plasmalogin.service
sudo systemctl enable sddm.service
```

### Greeter monitors

The greeter opens one window per output and the theme decides which one gets
the login card; the rest show the ambient view. The choice comes from
`inputScreen` in `theme.conf`, which `scripts/sddm-theme` fills in from
`lockscreen-monitor`, so the greeter and the lock screen use the same monitor.
An empty or unplugged name falls back to the primary screen, so exactly one
window always shows the card.

Do not rely on SDDM's own primary-screen notion for this: under the Wayland
greeter it follows the compositor's output order. Keyboard focus does follow
it, though, and that is not something the theme can move, so the ambient view
also accepts typing and Enter — the password can be entered from either
monitor.

For X11 greeters only (`DisplayServer=x11`), SDDM starts its own X server that
knows nothing about the compositor's layout, so outputs can land in the wrong
order or position. `scripts/sddm-layout` reads the live Hyprland layout and
writes an `Xsetup` that replays it through `xrandr`; `sddm-install --layout`
installs it as `/etc/sddm/Xsetup` behind a `[X11] DisplayCommand` drop-in.
Arch's `zz-wayland.conf` default (`DisplayServer=wayland`) makes this a no-op.

## Appearance

Keshiki Studio reads wallpapers from `$HOME/Pictures/wallpapers` and themes
from `themes/`. Selecting a scene writes the current choices and regenerates
the supported external application palettes.

### State files

| File | Purpose |
| --- | --- |
| `current-theme` | Active theme slug |
| `current-wallpaper` | Absolute path to the active wallpaper |
| `current-weather-location` | Location passed to Open-Meteo geocoding |
| `lockscreen-monitor` | Preferred monitor for password input |

Weather configuration uses the following precedence:

1. `WEATHER_LOCATION`
2. `current-weather-location`
3. `Budapest`

Set `WEATHER_COORDS=latitude,longitude` to bypass location geocoding.

### Themes

Each `themes/<slug>/theme.conf` defines six values:

```ini
NAME="Kanagawa Wave"
BACKGROUND="#1f1f28"
FOREGROUND="#dcd7ba"
ACCENT="#7e9cd8"
SURFACE="#2a2a37"
MUTED="#727169"
```

Included palettes are Catppuccin Mocha, Dynamic Matugen, Gruvbox Material,
Japanese Ink, Kanagawa Wave, Rose Pine, Sakura Blossom, and Tokyo Night.

Dynamic mode uses `matugen` and `jq` when available. It falls back to a fixed
palette if color generation fails.

Theme scripts generate:

- `kitty-theme.conf` for Kitty.
- `gtk-theme.css` for GTK 3 and GTK 4.
- `~/.config/hypr/colors.lua` for Hyprland's native Lua configuration.
- `vellum-theme.css` in the active Zen Browser profile, imported by `userChrome.css`.
- A `btop` theme in the user's btop configuration.
- A matching Vellum logo, plus a Fastfetch configuration when a local
  `config.template.jsonc` is present.

These files are generated, not automatically imported by every application.
Add the relevant include or import to each application's configuration.

## Project structure

```text
vellum_shell/
├── shell.qml              Main shell entry point and composition
├── LockShell.qml          Standalone lock-screen compatibility entry point
├── app/                   Popup lifecycle, coordination, and public IPC
├── core/                  Platform and shared state controllers
├── features/              Self-contained shell features and surfaces
├── ui/                    Reusable feature-independent QML components
├── backend/               Rust backend: theme engine and state daemon
│   ├── src/modules/       One file per capability (theme, network, vpn, ...)
│   ├── templates/         Theme output templates, editable without rebuilding
│   └── tests/             Golden comparison against the previous bash output
├── systemd/               User service that starts the backend at login
├── scripts/               Interactive helpers and installers
├── sddm/                  SDDM greeter theme matching the lock screen
├── themes/                Declarative color palettes
└── assets/                Static visual assets
```

The intended dependency direction is:

```text
shell.qml -> app, core, features
features  -> core, ui
core      -> Quickshell, and the backend through core/Backend.qml
ui        -> QtQuick
```

## Backend

System state and theming live in a Rust daemon rather than in shell scripts and
per-tick `Process` calls. It listens on `$XDG_RUNTIME_DIR/vellum-shell.sock` and
speaks newline-delimited JSON.

The shell keeps working when the daemon is down: `core/Backend.qml` falls back to
built-in defaults and reconnects with backoff, so nothing blocks or crashes.

```bash
scripts/backend-install        # build, install, and enable the user service
vellum ping                    # which binary and git revision is running
vellum describe                # every topic and method the daemon offers
vellum theme apply rose-pine   # works with or without the daemon running
vellum watch network vpn       # live state on stdout
```

`describe` is the contract: clients discover what exists instead of hardcoding
it, which is what makes a separate settings app possible later.

Topics are lazy. A module's loop only runs while something is subscribed, so an
idle daemon costs no CPU and about 7 MB of memory.

| Topic | Source | Replaces |
| --- | --- | --- |
| `theme` | `themes/*/theme.conf`, native Material You | 9 chained bash scripts, `matugen`, `jq` |
| `network` | NetworkManager D-Bus | `nmcli` and `ip -4 -j` polling |
| `vpn` | NetworkManager D-Bus, `protonvpn` for details | `protonvpn status` on every tick |
| `removable` | udisks2 D-Bus | `lsblk --json` every 2.5 s, `udisksctl` |
| `privacy` | `/proc` scan for `/dev/video*` handles | resident `camera-usage` bash loop |
| `sysstats` | `/proc`, `statvfs` | `df -P /` |
| `weather` | Open-Meteo | three `curl` calls per panel open |

PipeWire, UPower, Bluetooth, MPRIS, notifications, the system tray, and PAM stay
in QML: Quickshell already exposes them as event-driven C++ services.

See [`layout.md`](layout.md) for the detailed architecture and migration notes.

## Development

Run QML static checks from the repository root:

```bash
qmllint shell.qml LockShell.qml app/*.qml core/*.qml ui/*.qml features/*/*.qml
```

Validate shell scripts when ShellCheck is installed:

```bash
shellcheck scripts/*
```

The shell has not yet been covered by an automated integration test in a
nested Wayland session. Test changes on a non-critical session before using the
lock screen or power actions as daily-driver controls.

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
- Application launcher with desktop-entry search and frecency ranking. One
  prefix-free field searches applications, shell actions (lock, shutdown,
  appearance, screenshot) and emoji at once, and evaluates anything that looks
  like a maths expression.
- Launcher project mode (`>`) for directories under `~/Projects`.
- Terminal desktop entries (`Terminal=true`, such as Neovim or btop) open in a
  kitty window instead of being started without a TTY.
- Clipboard history with text and image previews, activation, and deletion.
- Notification server with toasts, history, actions, unread state, and DND.
- Notification center grouping per application, with collapsible groups,
  per-group unread counts, and per-group clearing.
- Media dashboard with playback, weather, calendar, and system statistics.
- PipeWire audio mixer, NetworkManager controls, volume OSD, and Polkit agent.
- Removable-device popup with mount, unmount, open, and safe power-off actions.
- Full-screen Appearance Studio for matching shell themes and wallpapers,
  including optional wallpaper-derived palettes. The whole screen is the preview:
  selections apply live while you browse, and are written out once you settle.
- Screenshot modes for smart selection, windows, workspaces, and regions.
- Multi-monitor Wayland lock screen with PAM authentication.
- Settings application in a real resizable window, with Hyprland display
  arrangement, tiling and decoration, input devices, a drag-and-drop top-bar
  layout editor, default applications, system diagnostics, XDG autostart
  entries, systemd user services, desktop preferences, and searchable
  keybindings. Every bar module can be reordered, moved between the left,
  center and right zones, or hidden.
- Searchable Launcher actions for guided package, AUR, web app, and terminal
  app installation and removal.

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
- Standard command-line tools such as `bash`, `hyprctl`, and `jq`. The backend
  reads NetworkManager and udisks2 over D-Bus, so `ip`, `lsblk`, `udisksctl`,
  `curl`, and `matugen` are no longer needed. Two tools are still required:
  `nmcli` drives the Wi-Fi panel's scanning and connecting, and `jq` is used by
  the screenshot and lock-screen helper scripts.

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
| Weather | Internet access to Open-Meteo (the backend does the request) |
| Screenshot capture | `grim`, `slurp`, `wayfreeze`, `magick`, `hyprctl`, `jq` |
| Screenshot extras | `satty`, `wl-copy`, `notify-send`, `xdg-user-dir` |
| Interactive utility scripts | `fzf`, Kitty |
| Package management | `pacman`; `paru` or `yay` for AUR packages |
| Power profiles | `powerprofilesctl` |
| Settings default applications | `xdg-mime` from `xdg-utils` |
| Settings user services | A reachable systemd user manager |
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

To see what it would do first — the setup checks every prerequisite up front and
prints its plan without changing anything:

```bash
./setup.sh --dry-run
```

The same preflight runs before a real install, so a missing Rust toolchain or an
unusable Hyprland config stops the setup before it has touched the system. It
also reports what it will *not* do: if you already have your own
`~/.config/hypr/bindings.lua` or `autostart.lua`, those are kept and Vellum's
versions are skipped, so the shell would come up without its key bindings. The
notice is repeated at the end of the run.

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

### Removing it again

`scripts/uninstall` reverses what the setup installed: the systemd user service
and the `vellum` binary, the generated Hyprland modules, the `require` lines it
appended, the include/import lines it added to `kitty.conf`, `gtk.css`, and
`btop.conf`, the qt6ct palette and portal environment, and the generated Neovim
colorscheme with its LazyVim spec. It is also the ownership manifest — anything not listed there was
yours before the install and is left alone, including the repository, your
wallpapers, and your screenshots.

```bash
scripts/uninstall --dry-run     # show what would be removed
scripts/uninstall               # remove it
scripts/uninstall --with-sddm --purge-state
```

Config files you had modified yourself (your own `bindings.lua`, a `colors.lua`
that is not ours) are reported and kept.

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
| `settings` | `toggle`, `open`, `close` |
| `menu` | `toggle`, `open`, `close` (alias of `settings`) |
| `launcher` | `toggle`, `open`, `close` |
| `clipboard` | `toggle`, `open`, `close` |
| `style` | `theme`, `wallpaper`, `close` |
| `power` | `toggle`, `open`, `close` (alias of `settings`) |
| `notifications` | `toggle`, `dnd`, `close`, `clear`, `grouping`, `expand`, `collapse` |
| `audio` | `toggle`, `open`, `close` |
| `media` | `toggle`, `open`, `overview`, `player`, `weather`, `close` |
| `network` | `toggle`, `open`, `close` |
| `bluetooth` | `toggle`, `open`, `close` |
| `vpn` | `toggle`, `open`, `close`, `connect`, `disconnect`, `app` |
| `removable` | `toggle`, `open`, `close` |
| `lock` | `lock` |
| `about` | `toggle`, `open`, `close` |
| `screenshot` | `capture`, `window`, `workspace`, `region` |

Every overlay opens on the focused monitor and closes the others, because they
all go through `app/PopupCoordinator.qml`.

The setup installs these bindings in `~/.config/hypr/bindings.lua` using the
native Hyprland Lua API:

```lua
local shell = [[quickshell ipc --path "$HOME/.config/quickshell/vellum_shell/shell.qml" call]]
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd(shell .. " launcher toggle"))
hl.bind("SUPER + V", hl.dsp.exec_cmd(shell .. " clipboard toggle"))
hl.bind("SUPER + N", hl.dsp.exec_cmd(shell .. " notifications toggle"))
hl.bind("SUPER + P", hl.dsp.exec_cmd(shell .. " settings toggle"))
```

### Lock screen

The lock screen is hosted by the main shell and activated over IPC:

```bash
quickshell ipc --path ~/.config/quickshell/vellum_shell/shell.qml call lock lock
```

It creates a secure `WlSessionLock` surface on every monitor. Locking blurs the
current desktop wallpaper behind a themed scrim instead of cutting to black, so
the transition stays continuous in both directions; without a wallpaper the
shell palette and the ensō watermark stand in. One monitor shows the clock and
the password card, the others use an ambient view that echoes the typed
characters. Select the input monitor on the Settings app's System page, or
directly:

```bash
~/.config/quickshell/vellum_shell/scripts/lockscreen-monitor list
~/.config/quickshell/vellum_shell/scripts/lockscreen-monitor set HDMI-A-1
```

Authentication uses the dedicated PAM service named `vellum-shell`. The setup
installs `/etc/pam.d/vellum-shell`; no external lock-screen package is used.

### Login screen (SDDM)

`sddm/vellum-ink/` is an SDDM greeter theme in the same visual language as the
lock screen and on the same palette, with its own copies of the components under
`sddm/vellum-ink/Ink*.qml`. It adds the greeter-only controls: user picker,
session picker, keyboard layout, and the power actions.

The greeter cannot read the wallpaper from `$HOME` (that directory is normally
`0700` and the greeter runs as `sddm`), so the theme engine writes a downscaled
copy next to the theme as `background.jpg` and points `theme.conf` at it. The
install chowns that file to you, the same way it does with `theme.conf`, so
later theme changes refresh the greeter background without root. Re-run the
install once after updating the theme so the file exists:

```bash
~/.config/quickshell/vellum_shell/scripts/sddm-install --preview            # test run, no root
sudo ~/.config/quickshell/vellum_shell/scripts/sddm-install --default --layout
```

The backend's `sddm` theme generator regenerates `theme.conf` from the active
shell palette on every theme switch, so the greeter follows the selected theme
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
`inputScreen` in `theme.conf`, which the generator fills in from
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

The Appearance Studio reads wallpapers from `$HOME/Pictures/wallpapers` and
themes from `themes/`. It is a dock at the bottom of the screen and nothing
else — there is no mock interface, because your own desktop is the preview.
Selecting recolours the running shell and swaps the real wallpaper in place, so
the actual bar, the dock itself, and the wallpaper all show the candidate theme.

Double-clicking the desktop wallpaper opens it, on the monitor you clicked.

`←`/`→` move through wallpapers, `↑`/`↓` through palettes, `D` jumps to the
wallpaper-derived palette, `Space` collapses the dock to a thin edge, and the
wheel steps through wallpapers.

Browsing touches nothing on disk: the shell recolours in process and the
wallpaper swap is a texture change. `Enter` closes the dock and applies the
theme everywhere — the state files plus every external application palette
(GTK, kitty, btop, Neovim, icons, Zen, SDDM). `Esc` closes and restores what you
started with.

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

Dynamic mode derives a Material You palette from the wallpaper inside the
backend, so no external tool is involved. A wallpaper with no usable hue keeps a
neutral palette instead of being given an invented colour.

The backend generates:

- `kitty-theme.conf` for Kitty.
- `gtk-theme.css` for GTK 3 and GTK 4.
- `~/.config/qt6ct/colors/vellum.conf` for Qt 6 applications and the Hyprland
  screen-sharing picker (through a service-specific portal environment).
- `~/.config/hypr/colors.lua` for Hyprland's native Lua configuration.
- `vellum-theme.css` in the active Zen Browser profile, imported by `userChrome.css`.
- A `btop` theme in the user's btop configuration.
- `~/.local/share/nvim/site/colors/vellum.lua`, a full Neovim colorscheme.
- A matching Vellum logo and Fastfetch configuration. A local
  `~/.config/fastfetch/config.template.jsonc` overrides the bundled layout.

### Neovim and LazyVim

The Neovim colorscheme is generated into `~/.local/share/nvim/site/colors/vellum.lua`.
That directory is on Neovim's runtime path, so `:colorscheme vellum` works from
any configuration and nothing generated ends up inside the user's own nvim
config repository. The generator only runs when Neovim is present on the machine.

`nvim/vellum.lua` is the LazyVim side. `setup.sh` copies it to
`~/.config/nvim/lua/plugins/vellum.lua` when a LazyVim layout exists, leaving an
existing file of that name alone. The spec sets `colorscheme = "vellum"` and
watches the generated file, so a theme switch in the Appearance Studio recolours
running Neovim instances without a restart.

`nvim/vellum-keys/` is a small local plugin that keeps the base keymaps of the
current mode visible in a corner of the editor: file manager, new tab, delete,
save, buffer and window motions, LSP actions. Unlike which-key it needs no
leading key press — it is always on screen and follows the mode, so normal,
insert, visual and terminal each show their own list. `<leader>uk` and
`:VellumKeys on|off|toggle` hide it, and it steps aside on its own in a narrow
terminal, on the dashboard, and while a picker or the Lazy UI has focus. Its
colours are `default`-linked to the float highlights, so it follows the palette
with everything else, and the key list is data in `lua/vellum_keys/keys.lua`
(or `setup({ groups = ... })` from your own spec).

`nvim/vellum-keys.lua` is the spec that loads it from the repository, so a
`git pull` updates the hint list without copying anything into the nvim config.

The output formats live in `backend/templates/`, so they can be adjusted without
rebuilding. A missing template falls back to the version compiled into the
binary, which means theming cannot break by editing one.

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
├── nvim/                  LazyVim specs: generated colorscheme and the key hints
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
it, which is what the Settings app is built on.

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
| `hypr` | `hyprctl`, `/sys/class/drm` EDID | hand-edited Hyprland config files |

### Hyprland settings

The Settings app never edits your own Hyprland files. What it changes is stored
in `~/.config/hypr/vellum-settings.json`, rendered into two generated modules,
and applied live with `hyprctl eval` through the native Lua API, so the change
is visible without a reload:

```text
~/.config/hypr/vellum_display.lua   hl.monitor() per configured display
~/.config/hypr/vellum_tuning.lua    hl.config() for gaps, decoration, input
```

`setup.sh` appends both to the `require` list in `hyprland.lua`, after your own
modules, so their values win. Deleting the JSON store (or the System page's
"Reset Hyprland settings") drops every override and falls back to your config.

The top-bar editor stores its independent layout in `bar-layout.json` in the
Vellum directory. It is shared by every monitor and applied live; deleting the
file restores the built-in module order on the next shell start.

Display changes go through a transaction owned by the daemon, because a bad mode
or position can leave a screen the user can no longer click on:

```text
hypr.previewMonitors   validate, apply live, arm a 12 s auto-revert; returns a token
hypr.confirmMonitors   cancel the timer and persist the layout
hypr.revertMonitors    restore the previous layout right away
```

Nothing reaches `vellum-settings.json` until it is confirmed, and the timer lives
in the daemon, so closing the Settings window — or losing the shell entirely —
still restores the previous layout. `previewMonitors` rejects a layout before it
touches the compositor: unknown outputs, unsupported resolutions, out-of-range
scale, transform or VRR values, overlapping displays, and turning off the last
active output. `setMonitors` remains for non-interactive callers and now saves
only after the live apply succeeds.

PipeWire, UPower, Bluetooth, MPRIS, notifications, the system tray, and PAM stay
in QML: Quickshell already exposes them as event-driven C++ services.

See [`layout.md`](layout.md) for the detailed architecture and migration notes.

## Development

One command runs every static check — Rust formatting, Clippy, the test suite,
`qmllint`, and ShellCheck — skipping whatever is not installed:

```bash
./scripts/check
```

The same gates run in CI (`.github/workflows/checks.yml`). To run a single piece:

```bash
cargo fmt --manifest-path backend/Cargo.toml --check
cargo clippy --manifest-path backend/Cargo.toml --all-targets -- -D warnings
cargo test --manifest-path backend/Cargo.toml
qmllint shell.qml LockShell.qml app/*.qml core/*.qml ui/*.qml features/*/*.qml
shellcheck setup.sh install.sh scripts/*
```

`qmllint` warns on a clean tree because it does not know the Quickshell types, so
the gate fails on errors only.

The shell has not yet been covered by an automated integration test in a
nested Wayland session. Test changes on a non-critical session before using the
lock screen or power actions as daily-driver controls.

---
title: Using the shell
nav: Using the shell
description: The bar, the launcher, the media dashboard, notifications, clipboard, screenshots and the system popups, and the keys that open them.
group: Using Vellum
order: 3
---

## Default keys

The setup installs these bindings in `~/.config/hypr/bindings.lua`. They call the shell over IPC, so you can rebind any of them. See [IPC and keybindings](/guide/ipc.html).

| Keys | Action |
| --- | --- |
| <kbd>Super</kbd> + <kbd>Space</kbd> | Launcher |
| <kbd>Super</kbd> + <kbd>V</kbd> | Clipboard history |
| <kbd>Super</kbd> + <kbd>N</kbd> | Notification centre |
| <kbd>Super</kbd> + <kbd>P</kbd> | Settings |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>L</kbd> | Lock screen |
| <kbd>Print</kbd> | Screenshot (smart selection) |
| <kbd>Shift</kbd> + <kbd>Print</kbd> | Region screenshot |
| Volume keys | Output volume in 5% steps, capped at 100% |
| <kbd>Ctrl</kbd> + volume keys | The active player's own volume |
| Media keys | Play/pause, next and previous on the active player |
| Brightness keys | Built-in display brightness in 5% steps |

The volume keys call `wpctl` directly and the brightness keys call `vellum call brightness step`, so both keep working while the shell restarts. Media, volume and brightness keys also work on the lock screen. `playerctl` and `brightnessctl` are not needed.

## The bar

Every monitor gets its own bar and wallpaper layer. Clicking a bar item opens its surface on that monitor.

| Module | What it shows and opens |
| --- | --- |
| Workspaces | Hyprland workspaces of that monitor |
| Privacy | Camera and microphone use |
| Clock / media | Date, time and the playing track; opens the [media dashboard](#media-dashboard) |
| System tray | StatusNotifier items |
| Network / VPN | Connection state; opens the network and VPN popups |
| Bluetooth | Adapter state and devices |
| Removable drives | Mount, unmount, open and safely power off |
| Audio | Volume; opens the mixer |
| Notifications | Unread count and Do Not Disturb; opens the [notification centre](#notifications) |
| AI usage | Codex/Claude subscription usage, if the CLIs are logged in |
| System monitor | CPU, memory and disk |
| Battery | Hidden by default; shown when UPower reports a battery |

Rearrange, move or hide modules on the **Top bar** page of [Settings](/guide/settings.html#top-bar).

Every overlay opens on the focused monitor and closes the others, so two surfaces never stay open on top of each other.

## Launcher

![The launcher searching for "fire": an emoji, Firefox and the firewall settings](/media/shots/launcher.jpg)

One prefix-free field searches applications, shell actions and emoji at once, and calculates anything that looks like a maths expression (with `qalc` installed).

- **Applications** come from desktop entries and are ranked by frecency: how often and how recently you opened them.
- **Shell actions** include settings, appearance, palette, clipboard, audio, notifications, Do Not Disturb, screenshot, terminal, files, browser, refresh shell, about, lock, screensaver, suspend, logout, reboot and shutdown.
- **Package workflows**: install a package, a community package (AUR through `paru`/`yay` on Arch, a selected COPR on Fedora), a web app or a terminal app, and remove them again. They open a guided terminal.
- **Emoji**: type a word such as `fire` and press <kbd>Enter</kbd> to copy it.
- **Projects**: start with `>` to search directories under `~/Projects`. <kbd>Tab</kbd> switches between the two modes.

Desktop entries with `Terminal=true`, such as Neovim or btop, open in your default terminal instead of being started without a TTY. Choose the terminal on the **Default apps** page of Settings. It is stored as the first line of `~/.config/xdg-terminals.list`, the list `xdg-terminal-exec` reads; without one, Kitty is used.

## Media dashboard

![The media dashboard: player, calendar, weather and system statistics](/media/shots/dashboard.jpg)

Click the clock, or bind `media toggle`. The dashboard shows:

- **An album-art player** for the active MPRIS player, with seeking, shuffle, repeat and the player's own volume. Players you never want to see can be hidden on the **Top bar** settings page.
- **A calendar** with dots for your [Google Calendar](/guide/settings.html#google-calendar) events. The expanded view lists the selected day's events; clicking one opens it in Google Calendar.
- **Weather** from Open-Meteo, with a four-day forecast. The location is set on the **System** settings page.
- **System statistics**: a CPU graph, memory and disk use, and uptime.

`media calendar` and `media weather` open the dashboard with that card already expanded.

## Notifications

![The notification centre grouped by application](/media/shots/notifications.jpg)

Vellum is the notification server, so no other daemon such as mako or dunst is needed.

- **Toasts** appear in the top-right corner with their actions.
- **The centre** groups notifications per application, with collapsible groups, per-group unread counts and per-group clearing.
- **Do Not Disturb** silences toasts but keeps history.
- **History and Do Not Disturb survive a shell restart.** They are kept in `$XDG_RUNTIME_DIR`, so they are gone after logging out. Restored entries have no actions.

User-provided text is always rendered as plain text, never as markup.

## Clipboard

![Clipboard history with text and an image entry](/media/shots/clipboard.jpg)

The backend records the clipboard over Wayland's data-control protocol, even while no panel is open. Open the history with <kbd>Super</kbd> + <kbd>V</kbd>.

- Text and images, with image previews.
- <kbd>Enter</kbd> puts an entry back on the clipboard, <kbd>Ctrl</kbd> + <kbd>P</kbd> pins it, <kbd>Del</kbd> removes it.
- The latest 100 entries are kept, plus up to 25 pinned ones. Anything over 5 MB is skipped.
- Content that a password manager marks as secret (`x-kde-passwordManagerHint`) is never stored.

History lives in `$XDG_STATE_HOME/vellum-shell/clipboard/`: `index.json` describes the entries, `blobs/` holds the content and `thumbs/` the previews.

## Screenshots

| IPC call | Mode |
| --- | --- |
| `screenshot capture` | Smart selection: click a window or drag a region |
| `screenshot window` | The active window |
| `screenshot workspace` | The whole monitor |
| `screenshot region` | A dragged region |

The selection freezes the screen with `wayfreeze` or, failing that, `hyprpicker`, and still works without either. Results are saved to `~/Pictures/Screenshots` (the `xdg-user-dir` pictures directory) and copied to the clipboard. With `snip` installed, clicking the notification opens the shot in the editor.

## System popups

- **Audio**: default output and input, per-application volume, and switching devices. The full mixer, with moving applications between outputs and sound card profiles, is the **Sound** page of Settings.
- **Network**: the active connection, Wi-Fi networks and VPN. When NetworkManager needs a Wi-Fi, WEP, 802.1X or PPPoE password, the shell asks in its own dialog. Passwords saved for this user only go to the keyring under the same attributes `nm-applet` uses, so existing ones keep working.
- **Bluetooth**: paired devices first, then devices discovered nearby, with pairing and connecting in place. Bluetooth settings open `blueman-manager`, Blueberry or KDE System Settings.
- **Removable drives**: mount, unmount, open in the file manager and power off safely.
- **Polkit**: authentication prompts for system actions appear in the shell.
- **Volume and brightness OSD**: shown for every change, including the media keys.
- **About**: a floating kitty window running Fastfetch with the theme's logo, rather than a QML panel that would re-render the same facts.

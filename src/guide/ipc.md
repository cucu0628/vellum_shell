---
title: IPC and keybindings
nav: IPC and keybindings
description: Every shell surface you can open or control from a keybinding or a script, and the backend's command-line client.
group: Reference
order: 8
---

## Calling the shell

Every major surface is exposed through Quickshell IPC, which makes it easy to bind shell actions in Hyprland or call them from scripts:

```bash
quickshell ipc --path ~/.config/quickshell/vellum_shell/shell.qml call TARGET METHOD
```

For example, `… call launcher toggle` or `… call notifications dnd`.

## Targets

| Target | Methods |
| --- | --- |
| `launcher` | `toggle`, `open`, `close` |
| `clipboard` | `toggle`, `open`, `close` |
| `settings` | `toggle`, `open`, `close` |
| `menu`, `power` | `toggle`, `open`, `close`; aliases of `settings`, kept for compatibility |
| `style` | `theme`, `wallpaper`, `close`: the [Appearance Studio](/guide/appearance.html) |
| `notifications` | `toggle`, `dnd`, `close`, `clear`, `grouping`, `expand`, `collapse` |
| `audio` | `toggle`, `open`, `close`, `volumeUp`, `volumeDown` (5% steps), `mute`, `micMute` |
| `brightness` | `up`, `down`: 5% steps on the built-in display; nothing without a backlight |
| `media` | `toggle`, `open`, `close`, `calendar`, `weather` (open with that card expanded), `playPause`, `next`, `previous`, `volumeUp`, `volumeDown` (the active player's own volume); `overview` and `player` are aliases of `open` |
| `network` | `toggle`, `open`, `close` |
| `bluetooth` | `toggle`, `open`, `close` |
| `vpn` | `toggle`, `open`, `close`, `connect`, `disconnect`, `app` |
| `removable` | `toggle`, `open`, `close` |
| `lock` | `lock`, `suspend` (locks first and waits for the compositor's confirmation) |
| `screenshot` | `capture`, `window`, `workspace`, `region` |
| `screensaver` | `start`, `stop`, `toggle` |
| `about` | `toggle`, `open`, `close`: a floating kitty window running Fastfetch |

Every overlay opens on the focused monitor and closes the others, because they all go through one popup coordinator. `about` is the one exception: it is a real window, so opening it closes only the overlays that would cover it.

## Keybindings

The setup installs `~/.config/hypr/bindings.lua` with the native Hyprland Lua API:

```lua
local shell = [[quickshell ipc --path "$HOME/.config/quickshell/vellum_shell/shell.qml" call]]

hl.bind("SUPER + SPACE", hl.dsp.exec_cmd(shell .. " launcher toggle"), { description = "Vellum launcher" })
hl.bind("SUPER + V", hl.dsp.exec_cmd(shell .. " clipboard toggle"), { description = "Vellum clipboard" })
hl.bind("SUPER + N", hl.dsp.exec_cmd(shell .. " notifications toggle"), { description = "Vellum notifications" })
hl.bind("SUPER + P", hl.dsp.exec_cmd(shell .. " settings toggle"), { description = "Vellum settings" })
hl.bind("SUPER + SHIFT + L", hl.dsp.exec_cmd(shell .. " lock lock"), { description = "Vellum lock screen" })
hl.bind("PRINT", hl.dsp.exec_cmd(shell .. " screenshot capture"), { description = "Vellum screenshot" })
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd(shell .. " screenshot region"), { description = "Vellum region screenshot" })
```

The same file binds the media, volume and brightness keys with `locked = true`, so they work on the lock screen too. Volume goes straight to `wpctl` (capped at 100%) and brightness through `vellum call brightness step`, so both keep working while the shell restarts. The shell shows the OSD from the change itself.

### Adding your own

Add bindings in the same style, for example the theme picker and the weather card:

```lua
hl.bind("SUPER + T", hl.dsp.exec_cmd(shell .. " style theme"), { description = "Vellum themes" })
hl.bind("SUPER + W", hl.dsp.exec_cmd(shell .. " media weather"), { description = "Vellum weather" })
```

The `description` shows up on the **Keybindings** page of Settings.

## The `vellum` command

The backend binary is also its own client. It talks to the running daemon over `$XDG_RUNTIME_DIR/vellum-shell.sock`:

```bash
vellum ping                    # which binary and git revision is running
vellum describe                # every topic and method the daemon offers
vellum theme apply rose-pine   # works with or without the daemon running
vellum watch network vpn       # live state on stdout
vellum call clipboard copy '{"id":12}'          # put a history entry back on the clipboard
vellum call brightness step '{"delta":5}'       # what the brightness keys run
```

`describe` is the contract: clients discover what exists instead of hard-coding it, which is what the Settings app is built on. The protocol is described in [How it works](/guide/architecture.html#the-backend).

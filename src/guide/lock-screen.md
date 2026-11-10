---
title: Lock and login screen
nav: Lock and login screen
description: The multi-monitor Wayland lock screen, locking before sleep and after inactivity, crash recovery, and the greetd login screen.
group: Using Vellum
order: 6
---

<figure>
<video autoplay muted loop playsinline preload="metadata" poster="/media/video/lock.jpg">
<source src="/media/video/lock.webm" type="video/webm">
<source src="/media/video/lock.mp4" type="video/mp4">
</video>
<figcaption>Locking blurs the desktop into the clock instead of cutting to black.</figcaption>
</figure>

## The lock screen

The lock screen is hosted by the main shell and activated over IPC, by <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>L</kbd>, or by the *lock* launcher action:

```bash
quickshell ipc --path ~/.config/quickshell/vellum_shell/shell.qml call lock lock
```

It creates a secure `WlSessionLock` surface on every monitor. Locking blurs the current wallpaper behind a themed scrim, so the transition stays continuous in both directions; without a wallpaper the shell palette and the logo watermark stand in. Every monitor sets a large serif clock in the lower-left corner. The input monitor adds the user name and password field beneath it; the others echo the typed characters and name the input monitor.

### Choosing the input monitor

Pick the monitor that takes the password on the **System** page of [Settings](/guide/settings.html#system), or directly:

```bash
~/.config/quickshell/vellum_shell/scripts/lockscreen-monitor list
~/.config/quickshell/vellum_shell/scripts/lockscreen-monitor set HDMI-A-1
```

### Authentication

Authentication uses the dedicated PAM service `vellum-shell`, which the setup installs as `/etc/pam.d/vellum-shell`. No external lock-screen package is used.

When that file is missing, for example after a manual install without `sudo`, the lock screen falls back to the system `login` service instead of refusing every password, so a locked session can always be unlocked.

## Locking before sleep

The screen also locks when something else suspends the machine: closing the lid, `systemctl suspend`, or an idle daemon. While the shell runs, the backend holds a logind delay inhibitor, locks on `PrepareForSleep`, and lets the suspend continue once the compositor has confirmed the lock surface, or after 4.5 seconds if the shell does not answer. Without the daemon, only `lock suspend` locks first.

## Locking when idle

`loginctl lock-session` locks the Vellum lock screen too, and the shell reports its state to logind (`LockedHint`). An idle daemon such as hypridle can therefore use:

```ini
lock_cmd = loginctl lock-session
```

Without an idle daemon, **Settings → System → Lock after inactivity** locks the screen after 1 to 30 minutes without input (off by default). Fullscreen video and other idle inhibitors keep it awake.

## If the shell crashes while locked

`scripts/shell-run`, which `shell-start` and `theme-refresh` use, restarts the shell after a crash, and the new instance locks again straight away. `vellum_tuning.lua` sets Hyprland's `misc.allow_session_lock_restore`, so the restarted shell can take the lock back instead of leaving the session on Hyprland's fallback screen. The supervisor gives up after five crashes within a minute.

## Login screen (greetd)

The login screen is the lock screen's own QML running as a greetd greeter: `GreeterShell.qml` → `features/lock/GreeterRoot.qml`. It reuses the lock background, clock, password field and ambient view, and adds the greeter-only controls: a user picker, a session picker (Wayland sessions from `/usr/share/wayland-sessions`), the keyboard layout, and sleep, restart and shut down. No X server is started and SDDM is not involved.

greetd runs a minimal Hyprland as the greeter user with `greeter/hyprland.lua`, which starts Quickshell and exits the compositor when the greeter quits. Because it is the same compositor as your desktop, connector names match and the greeter gets the real multi-monitor layout:

- every output gets a surface; the password field is on the `lockscreen-monitor` output and the others show the ambient view, which mirrors the typed characters;
- only the input output takes the keyboard, so typing always lands there;
- monitor modes, positions, scale, rotation and the keyboard layout are copied from your live session.

### Installing it

```bash
# Preview in your session, no root needed; Esc quits.
~/.config/quickshell/vellum_shell/scripts/greeter-install --preview

# Install and make greetd the display manager.
~/.config/quickshell/vellum_shell/scripts/greeter-install --enable
```

Run it as your user; it asks for `sudo` itself. It copies the QML to `/usr/share/vellum-greeter/`, plus the Symbols Nerd Font because the greeter user cannot read `~/.local/share/fonts`. It creates `/var/lib/vellum-greeter/` for state and `/var/cache/vellum-greeter/` for the greeter's own cache and the remembered user and session.

With `--enable` it also writes `/etc/greetd/config.toml` (the previous file is kept as `config.toml.before-vellum-*`), disables other display managers and enables `greetd.service`. The switch takes effect at the next boot or logout. Re-run it after changing the greeter QML. `./setup.sh --with-greeter` does the same as part of the setup.

### What the greeter reads

The greeter cannot read your home directory, so everything it needs lives in `/var/lib/vellum-greeter/`. The directory is owned by root and its files are owned by you, so the backend refreshes them without root:

| File | Written by |
| --- | --- |
| `theme.json`, `background.jpg` | The theme generator, on every theme or wallpaper change |
| `layout.conf` | The backend's `hypr` module, at start and after every confirmed display change |
| `input-screen` | `scripts/lockscreen-monitor set` |

`layout.conf` is data, not Lua: the root-owned `greeter/hyprland.lua` parses it line by line and drops anything that does not match the expected pattern, so a user-writable file cannot run code in the greeter. Outputs that are unplugged when the layout is captured keep their previous line.

PAM uses greetd's own `/etc/pam.d/greetd`.

!!! warning "Test on a real boot"
    Signing in, the power actions and the multi-monitor layout need a real greetd boot to test. The preview never authenticates or powers anything off.

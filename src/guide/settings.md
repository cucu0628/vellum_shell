---
title: Settings
description: The Settings application page by page, where Vellum keeps its state, and how to set up weather and Google Calendar.
group: Using Vellum
order: 5
---

## The Settings application

Open it with <kbd>Super</kbd> + <kbd>P</kbd>, the *settings* launcher action, or `settings toggle` over IPC. It is a real, resizable window with a searchable sidebar.

| Keys | Action |
| --- | --- |
| <kbd>Ctrl</kbd> + <kbd>Tab</kbd>, <kbd>Ctrl</kbd> + <kbd>PgDown</kbd> | Next page |
| <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>Tab</kbd>, <kbd>Ctrl</kbd> + <kbd>PgUp</kbd> | Previous page |
| <kbd>Ctrl</kbd> + <kbd>F</kbd> | Search settings |

### Desktop

#### Display

![Settings, Display page](/media/shots/settings-display.jpg)

Arrange your displays by dragging them, and set each one's mode, refresh rate, scale, rotation and variable refresh rate.

Display changes are a transaction owned by the daemon, because a bad mode or position can leave a screen you can no longer click on:

1. **Preview**: the layout is validated, applied live, and a 12-second auto-revert is armed.
2. **Confirm** within that time to keep it, or **revert** at once.

Nothing is saved until you confirm. The timer runs in the daemon, so closing the window or even losing the shell still restores the previous layout. A layout is rejected before it reaches the compositor if it names unknown outputs, uses an unsupported resolution, has an out-of-range scale, transform or VRR value, overlaps displays, or turns off the last active output.

#### Windows

![Settings, Windows page](/media/shots/settings-windows.jpg)

**Tiling and geometry**: inner and outer gaps, border width, the dwindle or master layout, and resizing on borders. **Visual treatment**: corner rounding, active and inactive opacity, and shadows. **Compositor effects**: blur strength and passes, and animations.

#### Input

**Keyboard**: layout, variant, repeat rate and delay. **Pointer**: sensitivity and focus-follows-mouse behaviour. **Touchpad**: tap to click and natural scrolling.

#### Sound

Default output and input with volume and mute, which application plays on which device, and sound card profiles: HDMI or analog, stereo or surround, Bluetooth codecs. Profiles need `pw-dump` and `wpctl`; moving applications needs `pactl`.

### Shell

#### Top bar

![Settings, Top bar page](/media/shots/settings-topbar.jpg)

Drag modules between the **Left**, **Center** and **Right** zones, reorder them, or drop them on **Hidden**. The layout is shared by every monitor and applied live. It is stored in `bar-layout.json` in the Vellum directory; deleting the file restores the built-in order on the next start.

**Media players** lists players to keep out of the bar and the dashboard.

#### Calendar

Connects Google Calendar. See [Google Calendar](#google-calendar) below.

#### Keybindings

Every shortcut Hyprland currently has bound, searchable, with the descriptions from your configuration.

### System

#### Default apps

![Settings, Default apps page](/media/shots/settings-defaultapps.jpg)

The application that opens each kind of file and link (web, mail, calendar, music, video, images and more) through `xdg-mime`, and the default terminal.

The terminal is stored as the first line of `~/.config/xdg-terminals.list`, the list `xdg-terminal-exec` reads. GLib launchers such as `xdg-open` and file managers only honour it through `xdg-terminal-exec`; without it they fall back to their own order. Vellum's floating helpers (btop, installers, About) stay on Kitty.

#### Autostart

XDG autostart entries, each with an on/off switch, and your systemd user services.

#### System

![Settings, System page](/media/shots/settings-system.jpg)

- **Shell services**: weather location, power profile, the [lock screen's input display](/guide/lock-screen.html#choosing-the-input-monitor), lock after inactivity, [screensaver](/guide/screensaver.html) after inactivity, screensaver theme and a preview.
- **System diagnostics**: a snapshot of the session and the Vellum backend, including failed user services and the state of every backend module, with a report you can copy.
- **External tools**: open the NetworkManager connection editor or the Hyprland configuration folder.
- **Maintenance**: **Reset Hyprland settings** drops every override the Settings app made.

## How Hyprland settings are stored

The Settings app never edits your own Hyprland files. Its changes are stored in `~/.config/hypr/vellum-settings.json`, rendered into two generated modules, and applied live with `hyprctl eval` through the native Lua API:

```text
~/.config/hypr/vellum_display.lua   hl.monitor() per configured display
~/.config/hypr/vellum_tuning.lua    hl.config() for gaps, decoration, input
```

The setup appends both to the `require` list in `hyprland.lua`, after your own modules, so their values win. Deleting the JSON store, or **Reset Hyprland settings** on the System page, drops every override and falls back to your configuration.

## State files

Small state files live in the Vellum directory, `~/.config/quickshell/vellum_shell/`:

| File | Purpose |
| --- | --- |
| `current-theme` | Active theme slug |
| `current-wallpaper` | Absolute path to the active wallpaper |
| `current-weather-location` | Location passed to Open-Meteo geocoding |
| `lockscreen-monitor` | Preferred monitor for the password field |
| `lock-idle-minutes` | Minutes of inactivity before the screen locks; `0` or missing means never |
| `screensaver-idle-minutes` | Minutes of inactivity before the screensaver starts; `0` or missing means never |
| `screensaver-theme` | Screensaver scene: `shapes` (default), `auto`, or a scene name |
| `bar-layout.json` | Top bar module zones and order |

Elsewhere:

| Path | Contents |
| --- | --- |
| `$XDG_STATE_HOME/vellum-shell/clipboard/` | Clipboard history |
| `$XDG_RUNTIME_DIR` | Notification history and Do Not Disturb, until you log out |
| `~/.config/hypr/vellum-settings.json` | Hyprland overrides made in Settings |
| `/var/lib/vellum-greeter/` | What the login screen needs, see [Lock and login screen](/guide/lock-screen.html#login-screen-greetd) |

## Weather

The weather card uses Open-Meteo through the backend. The location is chosen in this order:

1. the `WEATHER_LOCATION` environment variable;
2. `current-weather-location`, which the System page writes;
3. `Budapest`.

Set `WEATHER_COORDS=latitude,longitude` to skip geocoding entirely.

## Google Calendar

**Settings → Calendar → Sign in with Google** opens the browser. After you approve read-only access, your events show up as dots in the calendar card, and the expanded calendar lists the selected day's events. The Calendar page also chooses which of your calendars are shown.

### One-time setup

Google requires every desktop application to have its own OAuth client, so the first sign-in needs a short setup in [Google Cloud Console](https://console.cloud.google.com/auth/clients):

1. Create a project and enable the **Google Calendar API**.
2. In **Google Auth Platform**, fill in *Branding*, then publish the app under *Audience* (**In production**). In *Testing* status Google expires the sign-in after seven days. An unverified personal app shows a warning on the consent screen; continue through *Advanced*.
3. Under *Clients*, create a **Desktop app** client and paste its ID and secret on the Calendar page.

The client can also come from `VELLUM_GOOGLE_CLIENT_ID` and `VELLUM_GOOGLE_CLIENT_SECRET`, in the daemon's environment or at build time. The downloaded `client_secret_*.json` file is accepted as `google-oauth.json` too.

### What is stored, and where

The daemon signs in with the loopback-redirect and PKCE flow and requests only `calendar.readonly`. The refresh token is kept encrypted in the system keyring through the Secret Service API (GNOME Keyring or KWallet); signing in fails with a clear message when no keyring is running. The plain files hold nothing that grants access, and are created with `0600` permissions:

| File | Contents |
| --- | --- |
| `$XDG_CONFIG_HOME/vellum-shell/google-oauth.json` | The OAuth client ID and secret, which identify the app but grant no access |
| `$XDG_STATE_HOME/vellum-shell/calendar/google.json` | The account email and which calendars are shown |

Access tokens and events are kept only in memory. Events sync every ten minutes while the panel or the settings page is open, covering two months back and a year ahead. **Sign out** revokes the token at Google and removes it from the keyring.

!!! tip "Locked keyring"
    A background sync never opens a password dialog. When the keyring is locked, the Calendar page shows **Unlock**, which asks for the keyring password once. Give the keyring the same password as your login and `pam_gnome_keyring` unlocks it when you sign in.

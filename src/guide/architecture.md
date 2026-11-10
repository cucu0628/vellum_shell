---
title: How it works
description: The QML layers, the Rust daemon and its lazy topics, how the shell survives without the daemon, and where everything lives in the repository.
group: Reference
order: 9
---

## Two processes

Vellum is two cooperating programs:

- **The shell** is QML running in Quickshell. It draws every surface and talks directly to the services Quickshell already exposes as event-driven C++ objects: PipeWire, UPower, Bluetooth, MPRIS, notifications, the system tray and PAM.
- **The backend** is a Rust daemon, `vellum daemon`, started as a systemd user service at login. It owns system state and theming, instead of shell scripts and per-tick `Process` calls.

They speak newline-delimited JSON over `$XDG_RUNTIME_DIR/vellum-shell.sock`.

## The shell's layers

```text
shell.qml      composition: creates services and features, wires their signals
  ├── app/      popup coordination and the public IPC surface
  ├── core/     platform state: Hyprland, PipeWire, MPRIS, the backend client
  └── features/ one directory per user-facing feature
        └── ui/ reusable, feature-independent visual components
```

The dependency direction is strict: a lower layer never imports a higher one.

| Layer | Owns | Never |
| --- | --- | --- |
| `shell.qml` | Creating core services and feature roots, wiring signals to the coordinators | Long delegates, data parsing or polling |
| `app/` | Rules across features: popup exclusion, monitor choice, the IPC targets | Platform polling or drawing |
| `core/` | Hyprland, PipeWire, MPRIS and backend state behind small property APIs. `core/Backend.qml` is the only file that talks to the socket | Knowing how popups look |
| `features/` | A popup, its controller, its store and delegates, together | Referring to another feature's internals |
| `ui/` | Visual primitives fed by properties and signals | Importing `core/` or `features/` |

### One popup at a time

Every overlay opens through `app/PopupCoordinator.qml`, which picks the focused monitor and closes whatever else is open. Popups are loaded on demand (`app/LazyPopup.qml`), so their object tree only exists while they are shown.

## The backend

### Lazy topics

The daemon is organised in modules, one file per capability under `backend/src/modules/`. Each module publishes a **topic** (live state) and **methods** (actions). Topics are lazy: a module's loop only runs while something is subscribed, so an idle daemon costs no CPU and about 7 MB of memory.

The one exception is `clipboard`: history has to be recorded even while the shell is not looking, so that module runs from start-up.

| Topic | Source | Replaces |
| --- | --- | --- |
| `theme` | `themes/*/theme.conf`, native Material You | 9 chained bash scripts, `matugen`, `jq` |
| `clipboard` | Wayland `wlr-data-control`, history on disk | `cliphist`, two `wl-paste --watch` loops, ImageMagick thumbnails |
| `network` | NetworkManager D-Bus; bounded `nmcli` calls for Wi-Fi actions | QML-side `nmcli` and `ip -4 -j` polling |
| `netsecrets` | NetworkManager secret agent, registered only while subscribed | `nm-applet` |
| `vpn` | NetworkManager D-Bus, `protonvpn` for details | `protonvpn status` on every tick |
| `removable` | udisks2 D-Bus | `lsblk --json` every 2.5 s, `udisksctl` |
| `privacy` | `/proc` scan for `/dev/video*` handles | A resident `camera-usage` bash loop |
| `session` | logind `PrepareForSleep` with a delay inhibitor, `Lock` signal, `LockedHint` | — |
| `brightness` | `/sys/class/backlight` notifications; set through logind | `brightnessctl` |
| `sysstats` | `/proc`, `statvfs` | `df -P /` |
| `weather` | Open-Meteo | Three `curl` calls per panel open |
| `calendar` | Google Calendar API, OAuth sign-in through the browser | — |
| `hypr` | `hyprctl`, `/sys/class/drm` EDID | Hand-edited Hyprland config files |
| `audio` (calls only) | `pw-dump`, `wpctl set-profile`, `pactl move-sink-input` | `pavucontrol` |

### The contract

`vellum describe` prints every topic, method and parameter. Clients discover what exists instead of hard-coding it, and the Settings app is built on that. The socket path, the protocol version (`v: 1`) and the topic and method names are a compatibility contract; `backend/tests/ipc_contract.rs` records the surface and fails on purpose when it changes.

A call that the daemon accepts but never answers fails with a `timeout` error after 60 seconds.

### Theme transactions

A theme switch renders every output from the templates in `backend/templates/` and writes all of them or none, so applications are never left half-recoloured. The generators' output is checked by golden tests, and a missing template falls back to the copy compiled into the binary.

### Display transactions

Monitor changes are `previewMonitors` → `confirmMonitors` or `revertMonitors`. The 12-second auto-revert timer lives in the daemon, so it fires even if the Settings window or the whole shell goes away. See [Settings](/guide/settings.html#display).

## Graceful degradation

The shell keeps working when the daemon is down. `core/Backend.qml` falls back to built-in defaults and reconnects with backoff, so nothing blocks or crashes. Until the daemon answers, the palette is read from `current-theme` and the matching `theme.conf`, so the shell still starts in your theme.

The same rule applies to optional tools: a missing `qalc`, `cava` or `snip` turns off one feature, not the shell. The System page of Settings shows what is available.

## Repository layout

```text
vellum_shell/
├── shell.qml              Main entry point and composition
├── LockShell.qml          Standalone lock-screen compatibility entry point
├── GreeterShell.qml       greetd login screen entry point
├── app/                   Popup lifecycle, coordination and public IPC
├── core/                  Platform and shared state controllers
├── features/              Self-contained shell features and surfaces
├── ui/                    Reusable feature-independent QML components
├── backend/               Rust backend: theme engine and state daemon
│   ├── src/modules/       One file per capability
│   ├── templates/         Theme output templates, editable without rebuilding
│   └── tests/             Golden output, IPC contract and theme transaction tests
├── nvim/                  LazyVim specs: the colorscheme and the key hints
├── systemd/               User service that starts the backend at login
├── scripts/               Installers and interactive helpers
├── greeter/               Hyprland config for the greetd login screen
├── themes/                Declarative colour palettes
└── assets/                Static visual assets
```

The repository's `layout.md` documents every file, in Hungarian.

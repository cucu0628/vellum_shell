---
title: Introduction
nav: Introduction
description: What Vellum Shell is, what it replaces on a Hyprland desktop, and how the pieces fit together.
group: Get started
order: 1
---

Vellum Shell is an ink-inspired desktop shell for [Hyprland](https://hypr.land), written in QML on top of [Quickshell](https://quickshell.outfoxxed.me/). A small Rust daemon sits behind it, keeping system state and writing the colour theme of every application you use.

![Vellum Shell with the media dashboard open, in the Japanese Ink theme](/media/themes/japanese-ink.jpg)

## What you get

Installing Vellum gives a Hyprland session everything a desktop environment would otherwise provide, drawn in one visual language:

- **A top bar on every monitor**: workspaces, clock, media, network, VPN, Bluetooth, audio, notifications, system tray, system monitor and optional battery. Every module can be reordered, moved between zones or hidden.
- **A launcher** that searches applications, shell actions and emoji in one field and evaluates maths. See [Using the shell](/guide/using.html#launcher).
- **A media dashboard** with an album-art player, calendar with Google Calendar events, weather and system statistics.
- **Notifications, clipboard history, a volume OSD, a Polkit agent** and NetworkManager password prompts, all inside the shell.
- **The Appearance Studio**, where themes preview live on the running desktop and are written out to GTK, Qt, kitty, btop, Neovim, Hyprland, Zen Browser, Fastfetch and the login screen at once. See [Themes and wallpapers](/guide/appearance.html).
- **A real settings application** for displays, windows, input, sound, the bar layout, default apps and services. See [Settings](/guide/settings.html).
- **A Wayland lock screen** on every monitor, and the same QML as a **greetd login screen**. See [Lock and login screen](/guide/lock-screen.html).
- **An ASCII screensaver** rendered by fragment shaders, with seasonal scenes. See [Screensaver](/guide/screensaver.html).

## How it fits together

```text
Hyprland ──── runs ────▶ Quickshell (shell.qml)
                           │  bar, popups, lock screen, notifications…
                           │
                           │  newline-delimited JSON over a Unix socket
                           ▼
                         vellum daemon (Rust)
                           │  NetworkManager, udisks2, logind, Wayland clipboard,
                           │  weather, calendar, Hyprland monitors
                           ▼
                         theme engine ──▶ GTK · Qt · kitty · btop · Neovim · Hyprland · Zen · Fastfetch · greeter
```

- **Quickshell** draws everything you see and talks directly to the services it already wraps well: PipeWire, MPRIS, notifications, the system tray, UPower, Bluetooth and PAM.
- **The `vellum` daemon** owns everything else. It is started as a systemd user service, keeps state such as the network or removable drives, and is the only place that writes theme files.
- **The shell degrades gracefully.** If the daemon is not running, the shell still starts in your theme with built-in defaults and reconnects when the daemon comes back.

[How it works](/guide/architecture.html) goes into the details.

## Supported systems

| | |
| --- | --- |
| Distributions | Arch Linux, CachyOS, Fedora Linux (Fedora Atomic needs the packages layered first) |
| Compositor | Hyprland **0.55 or newer**, with its native Lua configuration |
| Terminal | Kitty for the built-in helpers; your own default terminal for apps |
| Session | Wayland only |

## Where to go next

- New here? Start with [Installation](/guide/installation.html).
- Already running it? [Using the shell](/guide/using.html) lists what every part does, and [IPC and keybindings](/guide/ipc.html) everything you can bind.
- Want to make it yours? Read [Themes and wallpapers](/guide/appearance.html) and [Settings](/guide/settings.html).

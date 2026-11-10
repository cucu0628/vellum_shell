---
title: Themes and wallpapers
nav: Themes and wallpapers
description: The Appearance Studio, how a theme is defined, the dynamic palette, and every file a theme switch writes.
group: Using Vellum
order: 4
---

## The Appearance Studio

<figure>
<video autoplay muted loop playsinline preload="metadata" poster="/media/video/studio-themes.jpg">
<source src="/media/video/studio-themes.webm" type="video/webm">
<source src="/media/video/studio-themes.mp4" type="video/mp4">
</video>
<figcaption>Browsing themes: each step recolours the running shell, and Esc puts the old palette back.</figcaption>
</figure>

The Appearance Studio is a full-screen overlay below the bar with two pickers that share one skewed carousel. **Wallpaper** reads images from `~/Pictures/wallpapers`, **Theme** reads palettes from `themes/`.

Open it with:

- `style theme` or `style wallpaper` over [IPC](/guide/ipc.html), or the *appearance* and *palette* launcher actions;
- a double click on the desktop wallpaper, which opens the wallpaper picker on that monitor.

| Key | Action |
| --- | --- |
| <kbd>←</kbd> <kbd>→</kbd>, <kbd>H</kbd> <kbd>L</kbd>, mouse wheel | Move through the carousel; wraps at the ends |
| <kbd>Home</kbd> / <kbd>End</kbd> | First / last card |
| <kbd>Tab</kbd> | Switch between wallpapers and themes |
| <kbd>Ctrl</kbd> + <kbd>F</kbd> or <kbd>/</kbd> | Filter wallpapers by name |
| <kbd>Enter</kbd> or a click on the centred card | Apply |
| <kbd>Esc</kbd> or a click on empty space | Close |

### Preview first, write once

**Browsing wallpapers changes nothing.** **Browsing themes recolours only the running shell**, in process, so the bar above the overlay shows the candidate palette.

<kbd>Enter</kbd> writes the choice out:

- a wallpaper goes to the state file and the login screen's copy;
- a theme goes to the state files and every external application palette at once (see [what gets generated](#what-a-theme-switch-writes)).

Closing the theme picker any other way restores the palette you started with.

The two pickers commit independently: picking a wallpaper does not change the theme, and picking a theme does not change the wallpaper. The one exception is the dynamic theme: while it is active, a new wallpaper also re-derives the palette.

### The theme cards

Each theme card is a small desktop drawn in that theme: a bar, a terminal whose sample code uses the theme's terminal colours, a type specimen with an accent button and switch, and the surface colours as paint bands. The centred card types its code in, and the dynamic theme's card shows your current wallpaper. Behind the carousel, the focused theme's accent glows.

<figure>
<video autoplay muted loop playsinline preload="metadata" poster="/media/video/studio-wallpapers.jpg">
<source src="/media/video/studio-wallpapers.webm" type="video/webm">
<source src="/media/video/studio-wallpapers.mp4" type="video/mp4">
</video>
<figcaption>The wallpaper picker uses the same carousel.</figcaption>
</figure>

## Included themes

Catppuccin Mocha, Dynamic Matugen, Gruvbox Material, Japanese Ink, Kanagawa Wave, Monochrome, Rose Pine, Sakura Blossom, Tokyo Night and Varnished Horizon. The [theme gallery](/#themes) on the front page shows each of them on a real desktop.

### The dynamic theme

**Dynamic / Matugen** is not a fixed palette: the backend derives a Material You palette from the current wallpaper, natively, with no external tool. A wallpaper with no usable hue keeps a neutral palette instead of being given an invented colour.

## Writing your own theme

A theme is a directory under `themes/` with one `theme.conf`. The directory name is the slug used everywhere else (`vellum theme apply my-theme`).

```ini
NAME=Japanese Ink
MODE=dark

ACCENT=#b7372f
SELECTION=#302520
MUTED=#958b7a

BACKGROUND=#11130f
DARK_BACKGROUND=#0b0d0a
DARKER_BACKGROUND=#070806
LIGHTER_BACKGROUND=#191b16

FOREGROUND=#e8ddc7
DARK_FOREGROUND=#6f685c
LIGHT_FOREGROUND=#cfc3ad
BRIGHT_FOREGROUND=#fff4dc

RED=#b7372f
YELLOW=#c6a15b
ORANGE=#c9693f
GREEN=#788c5d
CYAN=#6f9690
BLUE=#7189a6
MAGENTA=#9a7185
BROWN=#8b5e4a

BRIGHT_RED=#df5549
BRIGHT_YELLOW=#e3bd70
BRIGHT_GREEN=#98ad73
BRIGHT_CYAN=#8db8b1
BRIGHT_BLUE=#91a9c7
BRIGHT_MAGENTA=#bd8da5

SURFACE=#191b16
ICON_THEME=Yaru-red-dark
```

| Keys | Used for |
| --- | --- |
| `BACKGROUND`, `SURFACE`, the `*_BACKGROUND` shades | Panels, cards, the bar and window backgrounds |
| `FOREGROUND`, `MUTED`, the `*_FOREGROUND` shades | Primary text, supporting text, dimmed and bright text |
| `ACCENT`, `SELECTION` | Active, selected and focused states; text selection |
| `RED` … `BROWN`, `BRIGHT_*` | The terminal palette, syntax colours in Neovim, and status colours |
| `ICON_THEME` | The icon theme set alongside the palette, or `auto` |

The keys are a compatibility contract: the generators' output is checked by golden tests against fixed reference output, so existing themes keep producing the same files.

The new theme appears in the Appearance Studio straight away. Apply it from the command line with `vellum theme apply my-theme`; that works with or without the daemon running.

## What a theme switch writes

The backend renders every output from templates in `backend/templates/`, and writes all of them or none, so a failed switch never leaves applications half-recoloured.

| Output | For |
| --- | --- |
| `kitty-theme.conf` (in the shell directory) | Kitty |
| `gtk-theme.css` (in the shell directory) | GTK 3 and GTK 4 |
| `~/.config/qt6ct/colors/vellum.conf` | Qt 6 applications and the Hyprland screen-sharing picker, through a service-specific portal environment |
| `~/.config/hypr/colors.lua` | Hyprland borders and groups |
| `vellum-theme.css` in the active Zen Browser profile | Zen Browser, imported by `userChrome.css` |
| A `btop` theme in your btop configuration | btop |
| `~/.local/share/nvim/site/colors/vellum.lua` | A full Neovim colorscheme |
| The Vellum logo and a Fastfetch configuration | Fastfetch and the `about` window |
| `theme.json` and `background.jpg` in `/var/lib/vellum-greeter/` | The [login screen](/guide/lock-screen.html#login-screen-greetd) |

These files are generated, not automatically imported by every application. The setup adds the include and import lines for kitty, GTK and btop; add the relevant line yourself for anything else.

The templates can be edited without rebuilding. A missing template falls back to the version compiled into the binary, so theming cannot break by editing one.

A local `~/.config/fastfetch/config.template.jsonc` overrides the bundled Fastfetch layout.

## Neovim and LazyVim

The colorscheme is generated into `~/.local/share/nvim/site/colors/vellum.lua`. That directory is on Neovim's runtime path, so `:colorscheme vellum` works from any configuration, and nothing generated ends up inside your own nvim config repository. The generator only runs when Neovim is installed.

`nvim/vellum.lua` is the LazyVim side. The setup copies it to `~/.config/nvim/lua/plugins/vellum.lua` when a LazyVim layout exists, leaving an existing file of that name alone. The spec sets `colorscheme = "vellum"` and watches the generated file, so a theme switch recolours running Neovim instances without a restart.

### Key hints

`nvim/vellum-keys/` is a small local plugin that keeps the base keymaps of the current mode visible in a corner of the editor: file manager, new tab, delete, save, buffer and window motions, LSP actions. Unlike which-key, it needs no leading key press; normal, insert, visual and terminal mode each show their own list.

- `<leader>uk` and `:VellumKeys on|off|toggle` hide it.
- It steps aside on its own in a narrow terminal, on the dashboard, and while a picker or the Lazy UI has focus.
- The key list is data in `lua/vellum_keys/keys.lua`, or `setup({ groups = ... })` from your own spec.

`nvim/vellum-keys.lua` loads it from the repository, so a `git pull` updates the hints without copying anything into your nvim config.

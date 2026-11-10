# Vellum Shell website

This orphan branch holds the website served at <https://vellum.asked.hu>. It
shares no history with `main`; the shell itself never sees these files.

```text
build.py                 Builds docs/ from src/ and the shell on origin/main
src/
├── index.html           Front page: video hero, tour, theme gallery, install
├── guide.template.html  Layout of every guide page (nav, contents, pager)
├── guide/*.md           The guide, one Markdown file per page, with front matter
├── media/               Screenshots and videos recorded from a real shell
├── partials/            <head>, top bar and footer shared by every page
├── style.css            Layout and components; colours are CSS variables
├── theme.js             Palette as variables, remembered choice, no flash on load
├── site.js              Theme menu, gallery, videos, slider, guide navigation
├── 404.html
└── favicon.svg
docs/                    Built site that GitHub Pages serves (do not edit by hand)
```

## What comes from `main`

The build reads two paths from `origin/main` with `git archive`:

| Source on `main` | Becomes |
| --- | --- |
| `themes/*/theme.conf` | `docs/themes.js`, the palettes behind the theme switcher |
| `assets/` | `docs/assets/`, the screensaver previews and the logo |

A new theme on `main` shows up in the switcher after the next build. Its
screenshot for the gallery has to be recorded and added to `src/media/themes/`.

## Guide pages

Each `src/guide/<slug>.md` becomes `/guide/<slug>.html` (`index.md` is
`/guide/`). The front matter orders and groups the sidebar:

```markdown
---
title: Installation
nav: Installation          # optional shorter sidebar label
description: One sentence under the title and in search results.
group: Get started         # sidebar group, in order of first appearance
order: 2                   # position in the sidebar and the pager
---
```

Markdown supports tables, fenced code, `!!! note "Title"` admonitions and raw
HTML (for `<figure>` and `<video>`).

## Media

Everything in `src/media/` shows the real shell. It was recorded in a sandbox:
a headless KWin (`kwin_wayland --virtual`) running a nested Hyprland with its
own runtime directory, session bus and no system bus, a copy of the repository,
and a backend started with `VELLUM_SHELL_DIR`, `VELLUM_GREETER_DIR` and
`VELLUM_NO_SIDE_EFFECTS`. Frames were taken with `grim` and encoded to VP9 WebM
and H.264 MP4. The wallpapers are public-domain paintings. The player is a stand-in that
announces itself over MPRIS exactly like [Hibiki](https://github.com/cucu0628/Hibiki),
with a track and cover from its library; the notifications are made up.

## Building

```bash
python3 -m pip install --user markdown   # the only dependency
./build.py                               # fetch origin/main, rewrite docs/
python3 -m http.server -d docs           # preview on http://localhost:8000
```

`./build.py --no-fetch` uses the local `origin/main`; `--ref <branch>` builds
from another branch.

After a change, rebuild and commit:

```bash
./build.py && git add -A && git commit -m "Rebuild the site" && git push
```

## Pages settings

Settings → Pages: **Deploy from a branch**, branch `gh-pages`, folder `/docs`,
custom domain `vellum.asked.hu`, **Enforce HTTPS**. DNS: `vellum` CNAME
`cucu0628.github.io.`

## Themes on the site

The page uses the shell's palettes directly: `theme.js` turns the theme.conf
values into CSS variables. Text variants (`--muted-text`, `--accent-text`) are
pulled towards the foreground until they reach a 4.5:1 contrast, because a
desktop palette may use `MUTED` as a decoration colour. The choice is stored in
`localStorage`, followed by other open tabs, and `?theme=<slug>` previews a
theme without remembering it.

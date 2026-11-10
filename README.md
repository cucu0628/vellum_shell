# Vellum Shell website

This orphan branch holds the website served at <https://vellum.asked.hu>. It
shares no history with `main`; the shell itself never sees these files.

```text
build.py                 Builds docs/ from src/ and the shell on origin/main
src/
├── index.html           Front page: live mock-up, features, themes, screensaver, install
├── docs.template.html   Documentation page; the body is rendered from README.md
├── partials/            <head>, top bar and footer shared by every page
├── style.css            Layout and components; colours are CSS variables
├── theme.js             Palette as variables, remembered choice, no flash on load
├── site.js              Theme menu, theme carousel, mock-up, docs navigation
├── 404.html
└── favicon.svg
docs/                    Built site that GitHub Pages serves (do not edit by hand)
```

## What comes from `main`

The build reads three paths from `origin/main` with `git archive`, so the site
cannot drift from the code:

| Source on `main` | Becomes |
| --- | --- |
| `themes/*/theme.conf` | `docs/themes.js`, the palettes behind the theme switcher |
| `README.md` | `docs/docs.html`, with a contents sidebar built from its headings |
| `assets/` | `docs/assets/`, the screenshot and screensaver previews |

A new theme on `main` shows up in the switcher and the carousel after the next
build without touching this branch's sources.

## Building

```bash
python3 -m pip install --user markdown   # the only dependency
./build.py                               # fetch origin/main, rewrite docs/
python3 -m http.server -d docs           # preview on http://localhost:8000
```

`./build.py --no-fetch` uses the local `origin/main`; `--ref <branch>` builds
from another branch, e.g. to preview documentation before it is merged.

After a change on `main` (README, a theme, a new GIF), rebuild and commit:

```bash
./build.py && git add -A docs && git commit -m "Rebuild from main" && git push
```

## Pages settings

Settings → Pages → *Build and deployment*: **Deploy from a branch**, branch
`gh-pages`, folder `/docs`. Custom domain `vellum.asked.hu` (the build also
writes `docs/CNAME`), then **Enforce HTTPS** once the certificate is issued.

DNS at the `asked.hu` provider:

```text
vellum.asked.hu.   CNAME   cucu0628.github.io.
```

## Themes on the site

The page uses the shell's palettes directly: `theme.js` turns the theme.conf
values into CSS variables. Desktop palettes may use `MUTED` as a decoration
colour, so text variants (`--muted-text`, `--accent-text`) are pulled towards
the foreground until they reach a 4.5:1 contrast; the raw colours stay
available for swatches and decoration.

The carousel behaves like the Appearance Studio: browsing previews the theme on
the whole page, Enter or a click on the centred card keeps it, Esc restores the
kept one. The choice is stored in `localStorage` and followed by other open
tabs. `?theme=<slug>` previews a theme without remembering it, for links.

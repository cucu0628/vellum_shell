---
title: Development
description: Running the checks, what the tests cover, and the rules that keep the shell consistent.
group: Reference
order: 10
---

## One command for every check

`scripts/check` runs Rust formatting, Clippy, the test suites, `qmllint` and ShellCheck, skipping whatever is not installed:

```bash
./scripts/check
```

The same gates run in CI (`.github/workflows/checks.yml`). `scripts/check rust`, `scripts/check qml` and `scripts/check shell` run a single group, which is how CI calls them, with `VELLUM_CHECK_STRICT=1` so a missing tool fails the job instead of being skipped.

To run a single piece:

```bash
cargo fmt --manifest-path backend/Cargo.toml --check
cargo clippy --manifest-path backend/Cargo.toml --all-targets -- -D warnings
cargo test --manifest-path backend/Cargo.toml
qmllint shell.qml LockShell.qml GreeterShell.qml app/*.qml core/*.qml ui/*.qml features/*/*.qml
shellcheck setup.sh install.sh scripts/*
python3 -B -m unittest discover -s tests -p 'test_*.py'
node tests/notifications.js
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  /usr/lib/qt6/bin/qmltestrunner -import tests/qml/stubs -input tests/qml
```

On Fedora the Qt tools live in `/usr/lib64/qt6/bin/`, or on `PATH` as `qmllint-qt6` and `qmltestrunner-qt6`; `scripts/check` finds either layout.

`backend/rustfmt.toml` pins the two settings the tree was written against (`max_width = 100`, `use_small_heuristics = "Max"`), so the format check runs on stable Rust.

## What the tests cover

- **Rust**: golden output of every theme generator, the `vellum describe` IPC contract, and theme transactions (all outputs or none).
- **Security regressions**: isolated Unix sockets, mocked monitor metadata, and offscreen Qt components. They never register a notification server, run installers or touch the active desktop.
- **Python**: shell and Desktop Entry escaping.
- **Node**: the notification controller functions.
- **QML**: untrusted notification and clipboard text stays literal, following [Qt's guidance for untrusted text](https://doc.qt.io/qt-6/qml-qtquick-text.html#details). Quickshell's own QML modules are compiled into the `quickshell` binary, so `tests/qml/stubs` stands in for the few types the tested components use.

`qmllint` warns on a clean tree because it does not know the Quickshell types. The gate records the known categories and a warning budget, and rejects errors, new categories and a rising count, so new diagnostics cannot hide in that background noise.

!!! warning "No nested-session tests yet"
    The shell has no automated integration test in a nested Wayland session. Changes to the lock screen, authentication, display management, package installation or power actions need a manual test on a non-critical session before you rely on them.

## Working rules

The repository's `AGENTS.md` is the full contributor guide. The parts that matter most:

- **Keep the dependency direction.** `features` may use `core` and `ui`; `ui` imports nothing from the shell. Shared state belongs in `core/`, not in visual components.
- **Popups go through the coordinator** (`app/PopupCoordinator.qml`), and public calls through `app/ShellIpc.qml`.
- **Prefer events over polling.** Use a Quickshell service or a backend topic instead of a recurring `Process`.
- **The IPC is a contract.** Changing a topic, a method or a required parameter means updating the recorded contract test, the QML callers and the documentation together.
- **Degrade gracefully.** The shell must start when the daemon or an optional command is missing.
- **Don't hand-edit generated files** such as `current-theme`, `gtk-theme.css`, `kitty-theme.conf` or `zen-theme.css`. Change the palette, the template or the generator.

### UI style

| Rule | Detail |
| --- | --- |
| Four type tiers | Display 18–26 px (serif); section headings 13–17 px; body and controls 11–13 px; metadata 9–10 px |
| Fonts | Serif for display, sans-serif for labels and prose, monospace only for fixed-width values and key hints |
| Colour roles | `foreground` for content, `muted` for supporting text, `accent` for active, selected and actionable states; one dominant accent per panel |
| Spacing | A 4 px rhythm: 4, 8, 12, 16, 24 |
| Targets | Compact controls at least 28 px high; settings and list rows at least 44 px |
| Untrusted text | User, clipboard and notification content is always `Text.PlainText`, with explicit wrapping or elision |

When a pattern appears in two features, refine the shared component in `ui/` instead of styling each copy separately.

## This website

The site lives on the `gh-pages` branch, separate from the shell's history. Its build reads the palettes and the screensaver previews from `main`, so a new theme appears in the switcher after the next build. The screenshots and videos were recorded from a real shell in a sandboxed, headless compositor. Edit any guide page through the link at its bottom.

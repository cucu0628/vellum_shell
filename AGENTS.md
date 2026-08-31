# Vellum Shell contributor guide

## Project shape

Vellum Shell is a Quickshell/QtQuick desktop shell for Hyprland on Arch Linux and CachyOS. Keep the existing dependency direction intact:

```text
shell.qml -> app, core, features
features  -> core, ui
core      -> Quickshell and core/Backend.qml
ui        -> QtQuick only
```

- `shell.qml` composes the shell; `LockShell.qml` is the compatibility lock entry point.
- `app/` owns popup coordination and public IPC.
- `core/` contains shared platform controllers and the Rust-backend client.
- `features/<name>/` owns one user-facing feature. Keep feature-specific UI and state here.
- `ui/` is for reusable, feature-independent QML components.
- `backend/` is the Rust daemon, IPC implementation, and theme engine.
- `scripts/` contains small installers and interactive helpers; do not move daemon-owned state polling back into scripts.

Read `README.md` for supported behavior and `layout.md` for the detailed architecture before changing cross-cutting code.

## Working rules

- Preserve graceful degradation: the QML shell must still start when the Rust daemon or an optional command is unavailable.
- Keep popup lifecycle changes behind `app/PopupCoordinator.qml` and public shell calls in `app/ShellIpc.qml`.
- Prefer event-driven Quickshell services or backend topics over recurring `Process` polling.
- Treat the newline-delimited JSON IPC described by `vellum describe` as a compatibility contract. Update both producer and consumer when it changes.
- Keep `ui/` free of feature imports. Shared state belongs in `core/`, not in visual components.
- Follow the local style: four spaces in QML, `set -euo pipefail` in Bash, and `cargo fmt` output in Rust. `backend/rustfmt.toml` pins the two settings the tree was written against (`max_width = 100`, `use_small_heuristics = "Max"`), so the check runs on stable without a nightly toolchain. Existing comments are often Hungarian; match the surrounding file.
- Do not hand-edit generated runtime files such as `current-theme`, `gtk-theme.css`, `kitty-theme.conf`, `zen-theme.css`, or `sddm/vellum-ink/theme.conf` unless the task is specifically about generated output. Edit the palette, template, or generator instead.
- Do not run `setup.sh`, `install.sh`, `scripts/backend-install`, package helpers, power actions, or lock-screen actions as routine validation: they modify the live desktop or system.

## Validation

Run the checks relevant to the files changed:

```bash
# Rust backend
cargo fmt --manifest-path backend/Cargo.toml --check
cargo test --manifest-path backend/Cargo.toml

# QML (from the repository root)
qmllint shell.qml LockShell.qml app/*.qml core/*.qml ui/*.qml features/*/*.qml

# Bash, when ShellCheck is installed
shellcheck setup.sh install.sh scripts/*
```

For executable Python helpers, first use a temporary cache/config directory and exercise their JSON output. Provider-backed scripts may require the matching CLI login and network access. Confirm that stdout remains exactly one JSON document because `StdioCollector` parses it directly.

The QML shell has no nested-Wayland integration suite. For changes involving session lock, authentication, display management, package installation, or power operations, report the manual test still required instead of exercising it on the user's active session.

Theme generator changes must keep `cargo test --manifest-path backend/Cargo.toml` green. Do not regenerate `backend/tests/golden/` casually; `backend/tests/capture-golden.sh` is historical and depends on removed Bash generators.

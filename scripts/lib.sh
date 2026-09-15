#!/usr/bin/env bash
set -euo pipefail

die() {
  printf 'error: %s\n' "$*" >&2
  if [[ -t 0 ]]; then pause; fi
  exit 1
}

has() {
  command -v "$1" >/dev/null 2>&1
}

# Az installerek es a launcher ugyanebbol a helybol dontik el, melyik
# csomagkezelot kell hasznalniuk. Az ID_LIKE miatt az Arch- es Fedora-alapu
# valtozatok is a megfelelo agat kapjak; ismeretlen rendszeren nem talalgatunk.
vellum_platform() {
  local os_release=${VELLUM_OS_RELEASE:-/etc/os-release}
  [[ -r $os_release ]] || return 1

  (
    ID=""
    ID_LIKE=""
    # shellcheck disable=SC1090
    . "$os_release"
    case " ${ID,,} ${ID_LIKE,,} " in
      *" arch "*) printf '%s\n' arch ;;
      *" fedora "*) printf '%s\n' fedora ;;
      *) exit 1 ;;
    esac
  )
}

vellum_platform_name() {
  case "${1:-$(vellum_platform 2>/dev/null || true)}" in
    arch) printf '%s\n' "Arch Linux / CachyOS" ;;
    fedora) printf '%s\n' "Fedora Linux" ;;
    *) printf '%s\n' "ismeretlen Linux disztribucio" ;;
  esac
}

vellum_package_hint() {
  local platform=$1 package=$2
  case "$platform" in
    arch) printf 'sudo pacman -S %s\n' "$package" ;;
    fedora)
      if [[ $package == rust ]]; then
        printf '%s\n' 'sudo dnf install rust cargo'
      else
        printf 'sudo dnf install %s\n' "$package"
      fi
      ;;
    *) printf 'telepitsd ezt a csomagot: %s\n' "$package" ;;
  esac
}

# A repo helye. A VELLUM_SHELL_DIR nyer -- ugyanaz a szabaly, mint a backend
# `theme::paths::shell_dir()`-jeben --, kulonben ennek a fajlnak a szulomappaja.
# Igy a scriptek akkor is jo helyre mutatnak, ha a repo nem a kanonikus uton van.
vellum_shell_dir() {
  if [[ -n ${VELLUM_SHELL_DIR:-} ]]; then
    printf '%s\n' "$VELLUM_SHELL_DIR"
  else
    (cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
  fi
}

fzf_theme_args() {
  local title=${1:-"Select entries"}
  local theme_file
  theme_file="$(vellum_shell_dir)/kitty-theme.conf"
  local background="#1e1e2e"
  local foreground="#cdd6f4"
  local surface="#313244"
  local muted="#9399b2"
  local accent="#cba6f7"
  local key value

  if [[ -r $theme_file ]]; then
    while read -r key value _; do
      [[ $value =~ ^#[[:xdigit:]]{6}$ ]] || continue
      case "$key" in
        background) background=$value ;;
        foreground) foreground=$value ;;
        inactive_tab_background) surface=$value ;;
        inactive_border_color) muted=$value ;;
        active_border_color) accent=$value ;;
      esac
    done < "$theme_file"
  fi

  printf '%s\0' \
    --height=100% \
    --layout=reverse \
    --no-border \
    --prompt='› ' \
    --pointer='▌ ' \
    --marker='● ' \
    --scrollbar='│' \
    --info=inline-right \
    --padding=1,2 \
    --margin=0 \
    --header="$title  ·  Tab: select  ·  Ctrl-P: details  ·  Esc: close" \
    --header-first \
    --preview-window=right:55%:wrap:hidden:border-left \
    --bind='ctrl-p:toggle-preview' \
    --color="bg:$background,bg+:$surface,fg:$foreground,fg+:$foreground" \
    --color="hl:$accent,hl+:$accent,query:$foreground,disabled:$muted" \
    --color="prompt:$accent,pointer:$accent,marker:$accent,spinner:$accent" \
    --color="info:$muted,header:$muted,border:$muted,separator:$muted" \
    --color="preview-bg:$background,preview-fg:$foreground,preview-border:$muted,label:$accent"
}

pause() {
  printf '\nPress Enter to close...'
  read -r _ || true
}

prompt() {
  local label=$1
  local value=${2:-}
  if [[ -n $value ]]; then
    printf '%s [%s]: ' "$label" "$value" >&2
  else
    printf '%s: ' "$label" >&2
  fi
  local input
  read -r input || true
  printf '%s' "${input:-$value}"
}

choose_one() {
  local prompt_text=$1
  if has fzf; then
    mapfile -d '' args < <(fzf_theme_args "$prompt_text")
    fzf "${args[@]}"
  else
    local tmp choice line
    tmp=$(mktemp)
    cat > "$tmp"
    nl -w1 -s') ' "$tmp" | sed -n '1,40p' >&2
    printf '%s number/name: ' "$prompt_text" >/dev/tty
    read -r choice </dev/tty || true
    if [[ $choice =~ ^[0-9]+$ ]]; then
      line=$(sed -n "${choice}p" "$tmp")
    else
      line=$choice
    fi
    rm -f "$tmp"
    printf '%s' "$line"
  fi
}

choose_many() {
  local prompt_text=$1
  if has fzf; then
    mapfile -d '' args < <(fzf_theme_args "$prompt_text")
    fzf --multi "${args[@]}"
  else
    local tmp choices choice line
    tmp=$(mktemp)
    cat > "$tmp"
    nl -w1 -s') ' "$tmp" | sed -n '1,40p' >&2
    printf '%s numbers/names (space-separated): ' "$prompt_text" >/dev/tty
    read -r choices </dev/tty || true
    for choice in $choices; do
      if [[ $choice =~ ^[0-9]+$ ]]; then
        line=$(sed -n "${choice}p" "$tmp")
        [[ -n $line ]] && printf '%s\n' "$line"
      else
        printf '%s\n' "$choice"
      fi
    done
    rm -f "$tmp"
  fi
}

require_fzf() {
  has fzf || die "fzf is required for this menu action"
}

fzf_many() {
  local prompt_text=$1
  local preview_cmd=${2:-}
  local args
  mapfile -d '' args < <(fzf_theme_args "$prompt_text")
  if [[ -n $preview_cmd ]]; then
    fzf --multi "${args[@]}" --preview="$preview_cmd"
  else
    fzf --multi "${args[@]}"
  fi
}

fzf_one() {
  local prompt_text=$1
  local preview_cmd=${2:-}
  local args
  mapfile -d '' args < <(fzf_theme_args "$prompt_text")
  if [[ -n $preview_cmd ]]; then
    fzf "${args[@]}" --preview="$preview_cmd"
  else
    fzf "${args[@]}"
  fi
}

desktop_safe_id() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-' | sed 's/^-//; s/-$//'
}

# Desktop Entry string: a kulso szoveg nem kezdhet uj kulcsot vagy csoportot.
desktop_string() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '%s' "$value"
}

# Az Exec argumentum eloszor parancssori idezest, majd Desktop Entry string
# escape-elest kap. Ez nem shell-parancs; a szazalek is literal adat.
desktop_exec_arg() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//\$/\\$}
  value=${value//\`/\\\`}
  value=${value//%/%%}
  desktop_string "\"$value\""
}

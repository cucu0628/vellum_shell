#!/usr/bin/env bash
set -euo pipefail

if (( EUID == 0 )); then
  printf 'Hiba: ne futtasd sudo-val; a script szükség esetén maga kér jogosultságot.\n' >&2
  exit 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib.sh
. "$SCRIPT_DIR/scripts/lib.sh"

platform=$(vellum_platform 2>/dev/null || true)
if [[ -z $platform ]]; then
  printf 'Hiba: ez a telepítő Arch Linux, CachyOS és Fedora Linux rendszert támogat.\n' >&2
  exit 1
fi

# Runtime tools for every built-in shell feature and bundled integration.
#
# A `rust` is itt van, nem opcionalisan: a setup.sh a backendet forrasbol epiti,
# es a temazas mar csak abban letezik. Korabban a telepito nem hozta be, a setup
# viszont megkovetelte -- egy friss gepen ezen allt meg elsore.
arch_repo_packages=(
  base-devel
  bash
  bluez
  bluez-utils
  blueman
  btop
  brightnessctl
  cava
  cliphist
  coreutils
  curl
  desktop-file-utils
  dolphin
  fastfetch
  findutils
  fzf
  gawk
  git
  glib2
  grep
  grim
  hyprland
  imagemagick
  inetutils
  iproute2
  jq
  kconfig
  kitty
  libnotify
  libqalculate
  network-manager-applet
  networkmanager
  noto-fonts-emoji
  pam
  pavucontrol
  pipewire
  pipewire-pulse
  playerctl
  polkit
  power-profiles-daemon
  procps-ng
  python
  qt6ct
  quickshell
  rust
  satty
  sddm
  sed
  slurp
  sudo
  ttf-nerd-fonts-symbols-mono
  udisks2
  util-linux
  upower
  wireplumber
  wl-clipboard
  xdg-desktop-portal-gtk
  xdg-desktop-portal-hyprland
  xdg-user-dirs
  xdg-utils
  xorg-xrandr
)

arch_aur_packages=(
  wayfreeze-git
  yaru-icon-theme
)

install_arch_packages() {
  local aur_helper
  command -v pacman >/dev/null 2>&1 || {
    printf 'Hiba: Arch/CachyOS rendszeren nem található a pacman.\n' >&2
    exit 1
  }

  printf 'Repository-csomagok ellenőrzése és telepítése...\n'
  sudo pacman -S --needed "${arch_repo_packages[@]}"

  if command -v paru >/dev/null 2>&1; then
    aur_helper=paru
  elif command -v yay >/dev/null 2>&1; then
    aur_helper=yay
  elif pacman -Si paru >/dev/null 2>&1; then
    printf 'A paru telepítése a rendszer repository-jából...\n'
    sudo pacman -S --needed paru
    aur_helper=paru
  else
    printf 'A paru felépítése AUR-ból...\n'
    (
      build_dir=$(mktemp -d)
      trap 'rm -rf "$build_dir"' EXIT
      git clone https://aur.archlinux.org/paru.git "$build_dir/paru"
      cd "$build_dir/paru"
      makepkg -si
    )
    aur_helper=paru
  fi

  printf 'AUR-csomagok ellenőrzése és telepítése...\n'
  "$aur_helper" -S --needed "${arch_aur_packages[@]}"
}

fedora_packages=(
  ImageMagick
  NetworkManager
  NetworkManager-applet
  bash
  bluez
  bluez-tools
  blueman
  btop
  brightnessctl
  cargo
  cava
  cliphist
  coreutils
  curl
  desktop-file-utils
  dolphin
  fastfetch
  findutils
  fontconfig
  fontconfig-devel
  fzf
  gawk
  gcc
  git
  glib2
  grep
  grim
  gtk4-devel
  hyprland
  iproute
  jq
  kitty
  libadwaita-devel
  libepoxy-devel
  libnotify
  libqalculate
  libxkbcommon-devel
  pam
  pavucontrol
  pipewire
  pipewire-pulseaudio
  pkgconf-pkg-config
  playerctl
  polkit
  power-profiles-daemon
  procps-ng
  python3
  qt6ct
  quickshell
  rust
  satty
  sddm
  sed
  slurp
  sudo
  tar
  udisks2
  util-linux
  upower
  wireplumber
  wl-clipboard
  xdg-desktop-portal-gtk
  xdg-desktop-portal-hyprland
  xdg-user-dirs
  xdg-utils
  xrandr
  xz
  yaru-icon-theme
)

install_fedora_copr_plugin() {
  if dnf copr --help >/dev/null 2>&1; then
    return 0
  fi

  printf 'A DNF COPR bővítmény telepítése...\n'
  if ! sudo dnf install dnf5-plugins; then
    sudo dnf install dnf-plugins-core
  fi
  dnf copr --help >/dev/null 2>&1 || {
    printf 'Hiba: a DNF COPR parancs a bővítmény telepítése után sem érhető el.\n' >&2
    exit 1
  }
}

install_nerd_symbols() {
  local font_archive font_dir
  if fc-match 'Symbols Nerd Font Mono' 2>/dev/null | grep -Fqi 'Symbols Nerd Font'; then
    return 0
  fi

  printf 'A Symbols Nerd Font telepítése a felhasználói betűkészletek közé...\n'
  font_archive=$(mktemp --suffix=.tar.xz)
  font_dir="$HOME/.local/share/fonts/NerdFontsSymbolsOnly"
  mkdir -p "$font_dir"
  curl -fL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.tar.xz \
    -o "$font_archive"
  tar -xJf "$font_archive" -C "$font_dir"
  rm -f "$font_archive"
  fc-cache -f "$font_dir" >/dev/null
}

install_fedora_source_tools() {
  if ! command -v wayfreeze >/dev/null 2>&1 && [[ ! -x $HOME/.local/bin/wayfreeze ]]; then
    printf 'A wayfreeze felépítése forrásból...\n'
    (
      wayfreeze_src=$(mktemp -d)
      trap 'rm -rf "$wayfreeze_src"' EXIT
      git clone --depth 1 https://github.com/Jappie3/wayfreeze.git "$wayfreeze_src"
      cargo install --locked --path "$wayfreeze_src" --root "$HOME/.local"
    )
  fi

  if ! command -v satty >/dev/null 2>&1 && [[ ! -x $HOME/.local/bin/satty ]]; then
    printf 'A Satty telepítése a Rust csomagtárból...\n'
    cargo install --locked --root "$HOME/.local" satty
  fi
}

install_fedora_packages() {
  local enabled_repos required_command
  local -a missing_commands
  command -v dnf >/dev/null 2>&1 || {
    printf 'Hiba: Fedora rendszeren nem található a dnf. Az Atomic kiadások rpm-ostree telepítését ez a script nem módosítja.\n' >&2
    exit 1
  }

  install_fedora_copr_plugin

  # A Vellum Hyprland 0.55+ Lua konfiguraciojat hasznalja. A Fedora szamara a
  # Hyprland sajat telepitesi dokumentacioja ezt a COPR-t ajanlja.
  enabled_repos=$(dnf repolist --enabled 2>/dev/null || true)
  if ! grep -Eqi 'lionheartp.*hyprland' <<<"$enabled_repos"; then
    printf 'A Hyprland Fedora COPR engedélyezése...\n'
    sudo dnf copr enable lionheartp/Hyprland
  fi

  printf 'Fedora csomagok ellenőrzése és telepítése...\n'
  # A satty nem minden támogatott Fedora kiadásban van csomagolva. Ilyenkor a
  # DNF átugorja, és lent Cargo telepíti; a többi csomag ugyanúgy felkerül.
  sudo dnf install --skip-unavailable "${fedora_packages[@]}"
  install_nerd_symbols
  install_fedora_source_tools

  missing_commands=()
  for required_command in cargo hyprctl jq nmcli quickshell; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
      missing_commands+=("$required_command")
    fi
  done
  if ! command -v wayfreeze >/dev/null 2>&1 && [[ ! -x $HOME/.local/bin/wayfreeze ]]; then
    missing_commands+=("wayfreeze")
  fi
  if (( ${#missing_commands[@]} > 0 )); then
    printf 'Hiba: a Fedora telepítés után is hiányzik: %s\n' "${missing_commands[*]}" >&2
    printf 'Ellenőrizd, hogy támogatott Fedora kiadást használsz, és a COPR/DNF tranzakció sikeres volt.\n' >&2
    exit 1
  fi
}

case "$platform" in
  arch) install_arch_packages ;;
  fedora) install_fedora_packages ;;
esac

printf '\nMinden Vellum Shell-függőség telepítve van.\n'
printf 'A teljes rendszerkonfigurációhoz futtasd a setup.sh scriptet.\n'

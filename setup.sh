#!/usr/bin/env bash
set -euo pipefail

if (( EUID == 0 )); then
  printf 'Hiba: ne futtasd sudo-val; a script maga ker jogosultsagot.\n' >&2
  exit 1
fi

install_packages=true
install_sddm=false
theme_zen=false

usage() {
  cat <<'EOF'
Hasznalat: ./setup.sh [opciok]

  --skip-packages  Ne futtassa a csomagtelepitot.
  --with-sddm      Telepitse es aktivalja a Vellum Ink SDDM temat is.
  --with-zen       Alkalmazza a temat a meglevo Zen Browser profilra is.
  -h, --help       Mutassa ezt a sugot.
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --skip-packages) install_packages=false ;;
    --with-sddm) install_sddm=true ;;
    --with-zen) theme_zen=true ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Ismeretlen opcio: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

command -v pacman >/dev/null 2>&1 || {
  printf 'Hiba: ez a setup csak Arch Linux/CachyOS rendszeren hasznalhato.\n' >&2
  exit 1
}

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
target_dir="$HOME/.config/quickshell/vellum_shell"

if [[ $source_dir != "$target_dir" ]]; then
  mkdir -p "$(dirname "$target_dir")"
  if [[ -e $target_dir || -L $target_dir ]]; then
    if [[ $(readlink -f "$target_dir") != "$source_dir" ]]; then
      printf 'Hiba: a celhely mar letezik es nem erre a repora mutat: %s\n' "$target_dir" >&2
      exit 1
    fi
  else
    ln -s "$source_dir" "$target_dir"
  fi
fi

if [[ $install_packages == true ]]; then
  "$source_dir/install.sh"
fi

sudo install -Dm644 "$source_dir/pam/vellum-shell" /etc/pam.d/vellum-shell

chmod +x "$source_dir/install.sh" "$source_dir/setup.sh" "$source_dir/scripts/"*

# A Rust backend. Ha nincs cargo, a shell ettol meg elindul: a QML kliens
# degradaltan mukodik es a hatterben ujraprobalkozik.
backend_installed=false
if command -v cargo >/dev/null 2>&1; then
  "$source_dir/scripts/backend-install"
  backend_installed=true
else
  printf 'Figyelmeztetes: nincs cargo, a Rust backend kimarad. Telepitsd a rust csomagot, majd futtasd ujra.\n' >&2
fi

xdg-user-dirs-update >/dev/null 2>&1 || true
mkdir -p \
  "$HOME/.config/hypr" \
  "$HOME/.config/kitty" \
  "$HOME/.config/gtk-3.0" \
  "$HOME/.config/gtk-4.0" \
  "$HOME/.config/btop/themes" \
  "$HOME/.config/fastfetch" \
  "$HOME/.local/state/quickshell/vellum-shell/cliphist-images" \
  "$HOME/.local/state/quickshell/vellum-shell/cliphist-thumbnails" \
  "$HOME/.local/share/applications/vellum-tui" \
  "$HOME/.local/share/applications/vellum-webapps" \
  "$HOME/.cache/quickshell" \
  "$HOME/.cache/vellum-shell" \
  "$HOME/Pictures/wallpapers" \
  "$HOME/Pictures/Screenshots" \
  "$HOME/Projects"

current_theme=""
[[ -r "$target_dir/current-theme" ]] && current_theme=$(<"$target_dir/current-theme")
if [[ -z $current_theme || ! -d "$target_dir/themes/$current_theme" ]]; then
  printf '%s\n' japanese-ink > "$target_dir/current-theme"
fi

current_wallpaper=""
[[ -r "$target_dir/current-wallpaper" ]] && current_wallpaper=$(<"$target_dir/current-wallpaper")
if [[ ! -r $current_wallpaper ]]; then
  shopt -s nullglob nocaseglob
  wallpapers=("$HOME/Pictures/wallpapers/"*.png "$HOME/Pictures/wallpapers/"*.jpg "$HOME/Pictures/wallpapers/"*.jpeg "$HOME/Pictures/wallpapers/"*.webp "$HOME/Pictures/wallpapers/"*.gif)
  shopt -u nullglob nocaseglob
  if (( ${#wallpapers[@]} > 0 )); then
    printf '%s\n' "${wallpapers[0]}" > "$target_dir/current-wallpaper"
  fi
fi

hypr_main="$HOME/.config/hypr/hyprland.lua"
if [[ ! -e $hypr_main ]]; then
  if [[ ! -r /usr/share/hypr/hyprland.lua ]]; then
    printf 'Hiba: a Hyprland Lua alapkonfiguracio nem talalhato. Hyprland 0.55+ szukseges.\n' >&2
    exit 1
  fi
  cp /usr/share/hypr/hyprland.lua "$hypr_main"
fi

backup_suffix="vellum-backup-$(date +%Y%m%d-%H%M%S)"
install_user_file() {
  local source=$1 target=$2
  if [[ -e $target ]]; then
    if ! cmp -s "$source" "$target"; then
      printf 'Meglevo Hyprland modul megorizve: %s\n' "$target"
    fi
    return 0
  fi
  install -m 644 "$source" "$target"
}

install_user_file "$source_dir/hypr/bindings.lua" "$HOME/.config/hypr/bindings.lua"
install_user_file "$source_dir/hypr/autostart.lua" "$HOME/.config/hypr/autostart.lua"

hypr_additions=()
if ! grep -Fq -- '-- Vellum Shell modules' "$hypr_main"; then
  hypr_additions+=("-- Vellum Shell modules")
fi
for module in colors bindings autostart; do
  if ! grep -Eq "^[[:space:]]*require\\([\"']$module[\"']\\)" "$hypr_main"; then
    hypr_additions+=("require(\"$module\")")
  fi
done
if (( ${#hypr_additions[@]} > 0 )); then
  cp -a "$hypr_main" "$hypr_main.$backup_suffix"
  printf '\n%s\n' "${hypr_additions[@]}" >> "$hypr_main"
fi

if ! grep -Fq "$target_dir/kitty-theme.conf" "$HOME/.config/kitty/kitty.conf" 2>/dev/null; then
  printf '\n# Vellum Shell theme\ninclude %s/kitty-theme.conf\n' "$target_dir" >> "$HOME/.config/kitty/kitty.conf"
fi

for gtk_version in 3.0 4.0; do
  gtk_css="$HOME/.config/gtk-$gtk_version/gtk.css"
  if ! grep -Fq "$target_dir/gtk-theme.css" "$gtk_css" 2>/dev/null; then
    printf '\n/* Vellum Shell theme */\n@import url("%s/gtk-theme.css");\n' "$target_dir" >> "$gtk_css"
  fi
done

current_theme=$(<"$target_dir/current-theme")
if [[ $backend_installed == true ]]; then
  # Egy hivas az osszes generatort lefuttatja. Ha a daemon mar fut, o vegzi el
  # (es azonnal ertesiti a shellt); ha nem, a binaris helyben futtatja le.
  zen_flag=(--no-zen)
  [[ $theme_zen == true ]] && zen_flag=()
  "$HOME/.local/bin/vellum" theme apply "$current_theme" "${zen_flag[@]}" >/dev/null
else
  for theme_script in kitty-theme gtk-theme icon-theme hyprland-theme btop-theme fastfetch-theme sddm-theme; do
    bash "$target_dir/scripts/$theme_script"
  done
  if [[ $theme_zen == true ]]; then
    bash "$target_dir/scripts/zen-theme"
  fi
fi

btop_config="$HOME/.config/btop/btop.conf"
if [[ -r $btop_config ]] && grep -Eq '^[[:space:]]*color_theme[[:space:]]*=' "$btop_config"; then
  sed -i -E 's|^[[:space:]]*color_theme[[:space:]]*=.*$|color_theme = "vellum"|' "$btop_config"
else
  printf '\ncolor_theme = "vellum"\n' >> "$btop_config"
fi

fc-cache -f >/dev/null 2>&1 || true
sudo systemctl enable --now NetworkManager.service bluetooth.service
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service || \
  printf 'Figyelmeztetes: a PipeWire felhasznaloi szolgaltatasokat a kovetkezo bejelentkezes inditja el.\n' >&2


if [[ $install_sddm == true ]]; then
  sudo "$target_dir/scripts/sddm-install" --default --layout
  if systemctl is-enabled plasmalogin.service >/dev/null 2>&1; then
    sudo systemctl disable plasmalogin.service
  fi
  sudo systemctl enable sddm.service
fi

if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  hyprctl reload
  if ! errors=$(hyprctl configerrors 2>&1); then
    printf 'A Hyprland konfiguracio ellenorzese sikertelen:\n%s\n' "$errors" >&2
    exit 1
  fi
  if [[ -n $errors ]]; then
    printf 'Hyprland konfiguracios hibak:\n%s\n' "$errors" >&2
    exit 1
  fi
  "$target_dir/scripts/theme-refresh"
fi

printf '\nA Vellum Shell setup kesz. A shell Hyprland alatt automatikusan elindul.\n'
if [[ ! -r "$target_dir/current-wallpaper" ]]; then
  printf 'Tegy egy kepet a %s mappaba; a shell automatikusan az elsot valasztja.\n' "$HOME/Pictures/wallpapers"
fi

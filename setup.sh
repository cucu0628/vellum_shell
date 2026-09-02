#!/usr/bin/env bash
set -euo pipefail

if (( EUID == 0 )); then
  printf 'Hiba: ne futtasd sudo-val; a script maga ker jogosultsagot.\n' >&2
  exit 1
fi

install_packages=true
install_sddm=false
theme_zen=false
dry_run=false

usage() {
  cat <<'EOF'
Hasznalat: ./setup.sh [opciok]

  --skip-packages  Ne futtassa a csomagtelepitot.
  --with-sddm      Telepitse es aktivalja a Vellum Ink SDDM temat is.
  --with-zen       Alkalmazza a temat a meglevo Zen Browser profilra is.
  --dry-run        Csak az ellenorzest es a tervet mutassa; ne modositson semmit.
  --plan           A --dry-run szinonimaja.
  -h, --help       Mutassa ezt a sugot.
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --skip-packages) install_packages=false ;;
    --with-sddm) install_sddm=true ;;
    --with-zen) theme_zen=true ;;
    --dry-run|--plan) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Ismeretlen opcio: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
target_dir="$HOME/.config/quickshell/vellum_shell"

# -- preflight ---------------------------------------------------------------
#
# Minden elofeltetel egyszerre derul ki, nem egyesevel, felig elvegzett
# telepites kozben. Ami csak figyelmeztetes, az nem allitja meg a setupot, de a
# vegen ujra elhangzik -- kulonben egy megorzott sajat bindings.lua mellett a
# setup sikeresnek latszana Vellum gyorsbillentyuk nelkul.

problems=()
warnings=()
plan=()

# "1.88" <= "1.98"? A sort -V a verziok rendezesere valo.
version_at_least() {
  local have=$1 want=$2
  [[ $have == "$want" ]] && return 0
  [[ $(printf '%s\n%s\n' "$want" "$have" | sort -V | head -n1) == "$want" ]]
}

required_rust() {
  sed -n 's/^rust-version = "\(.*\)"/\1/p' "$source_dir/backend/Cargo.toml" | head -n1
}

preflight() {
  command -v pacman >/dev/null 2>&1 || \
    problems+=("nincs pacman: ez a setup Arch Linux / CachyOS rendszerre valo")

  # A backend nem opcionalis: a temazas es a rendszerallapot mar csak benne
  # letezik. Az install.sh hozza a `rust` csomagot; --skip-packages mellett
  # viszont a felhasznalonak kell.
  local msrv
  msrv=$(required_rust)
  if command -v cargo >/dev/null 2>&1; then
    local have
    have=$(rustc --version 2>/dev/null | awk '{print $2}')
    if [[ -n $have && -n $msrv ]] && ! version_at_least "$have" "$msrv"; then
      problems+=("a Rust $have tul regi; a backendhez legalabb $msrv kell")
    fi
  elif [[ $install_packages == true ]]; then
    plan+=("Rust telepitese (a backend forrasbol epul)")
  else
    problems+=("nincs cargo, a --skip-packages miatt pedig nem is telepitjuk (sudo pacman -S rust)")
  fi

  if [[ ! -e "$HOME/.config/hypr/hyprland.lua" && ! -r /usr/share/hypr/hyprland.lua ]]; then
    problems+=("nincs Hyprland Lua alapkonfiguracio; Hyprland 0.55 vagy ujabb kell")
  fi

  if [[ -e $target_dir || -L $target_dir ]] \
    && [[ $(readlink -f "$target_dir") != "$source_dir" ]]; then
    problems+=("a celhely mar letezik es nem erre a repora mutat: $target_dir")
  fi

  # A sajat Hyprland moduljaidhoz nem nyulunk. Ha van sajat bindings.lua vagy
  # autostart.lua, a Vellum valtozata NEM kerul be -- ezt latni kell.
  local module target
  for module in bindings autostart; do
    target="$HOME/.config/hypr/$module.lua"
    if [[ -e $target ]] && ! cmp -s "$source_dir/hypr/$module.lua" "$target"; then
      warnings+=("sajat $module.lua marad ervenyben; a Vellum $module.lua NEM kerul be (vesd ossze: $source_dir/hypr/$module.lua)")
    else
      plan+=("$module.lua telepitese ide: $target")
    fi
  done

  if [[ $install_packages == true ]]; then
    plan+=("csomagok telepitese az install.sh-val")
  fi
  plan+=("PAM modul: /etc/pam.d/vellum-shell")
  plan+=("backend forditasa es telepitese (scripts/backend-install)")
  plan+=("Hyprland require sorok: colors, bindings, autostart, vellum_display, vellum_tuning")
  plan+=("kitty include es GTK @import bekotese")
  if [[ -d "$HOME/.config/nvim/lua/plugins" ]]; then
    plan+=("LazyVim specek: ~/.config/nvim/lua/plugins/vellum.lua, vellum-keys.lua")
  fi
  plan+=("tema alkalmazasa (zen: $theme_zen)")
  plan+=("NetworkManager, bluetooth es PipeWire szolgaltatasok engedelyezese")
  if [[ $install_sddm == true ]]; then
    plan+=("Vellum Ink SDDM tema telepitese es aktivalasa")
  fi

  if ! sudo -n true 2>/dev/null; then
    warnings+=("a setup sudo jelszot fog kerni (PAM, szolgaltatasok, SDDM)")
  fi
}

report_preflight() {
  local item
  if (( ${#problems[@]} > 0 )); then
    printf '\nMegoldando, mielott a setup futhatna:\n'
    for item in "${problems[@]}"; do printf '  - %s\n' "$item"; done
  fi
  if (( ${#warnings[@]} > 0 )); then
    printf '\nFigyelmeztetes:\n'
    for item in "${warnings[@]}"; do printf '  - %s\n' "$item"; done
  fi
}

preflight
if (( ${#problems[@]} > 0 )); then
  report_preflight >&2
  exit 1
fi

if [[ $dry_run == true ]]; then
  printf 'Terv (--dry-run: semmi nem modosul):\n'
  for item in "${plan[@]}"; do printf '  - %s\n' "$item"; done
  report_preflight
  exit 0
fi

report_preflight

# A celhely egyezeset a preflight mar ellenorizte.
if [[ $source_dir != "$target_dir" ]]; then
  mkdir -p "$(dirname "$target_dir")"
  if [[ ! -e $target_dir && ! -L $target_dir ]]; then
    ln -s "$source_dir" "$target_dir"
  fi
fi

# A futtathato bit meg az install.sh hivasa ELOTT kell: egy forrasarchivumbol
# kicsomagolt fan a jogosultsagok nem maradnak meg, es a hivas elhasalna.
chmod +x "$source_dir/install.sh" "$source_dir/setup.sh" "$source_dir/scripts/"*

if [[ $install_packages == true ]]; then
  "$source_dir/install.sh"
fi

sudo install -Dm644 "$source_dir/pam/vellum-shell" /etc/pam.d/vellum-shell

# A cargo meglete es verzioja a preflightban dolt el; a csomagtelepito ota
# viszont valtozhatott, ezert itt meg egyszer megnezzuk.
if ! command -v cargo >/dev/null 2>&1; then
  printf 'Hiba: nincs cargo. A backend nelkul nincs temazas. Telepitsd: sudo pacman -S rust\n' >&2
  exit 1
fi
"$source_dir/scripts/backend-install"

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

# A settings app generalja ezeket, de a Lua `require` hibaval all meg egy
# hianyzo modulon -- ezert egy ures valtozatnak mar most letezniuk kell.
for generated in vellum_display vellum_tuning; do
  target="$HOME/.config/hypr/$generated.lua"
  if [[ ! -e $target ]]; then
    printf -- '-- Generated by vellum_shell. Do not edit: use the Vellum settings app.\n' > "$target"
    chmod 644 "$target"
  fi
done

hypr_additions=()
if ! grep -Fq -- '-- Vellum Shell modules' "$hypr_main"; then
  hypr_additions+=("-- Vellum Shell modules")
fi
# A sorrend szamit: a generalt modulok a felhasznalo sajat moduljai utan
# jonnek, hogy az itt beallitott ertekek nyerjenek.
for module in colors bindings autostart vellum_display vellum_tuning; do
  if ! grep -Eq "^[[:space:]]*require\\([\"']${module}[\"']\\)" "$hypr_main"; then
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

# A CSS @import csak minden mas szabaly ELOTT ervenyes, ezert a fajl elejere
# kerul. Hozzafuzve a GTK csendben figyelmen kivul hagyna, ha a felhasznalonak
# mar volt sajat tartalma a gtk.css-ben.
for gtk_version in 3.0 4.0; do
  gtk_css="$HOME/.config/gtk-$gtk_version/gtk.css"
  if ! grep -Fq "$target_dir/gtk-theme.css" "$gtk_css" 2>/dev/null; then
    gtk_tmp=$(mktemp)
    printf '/* Vellum Shell theme */\n@import url("%s/gtk-theme.css");\n\n' "$target_dir" > "$gtk_tmp"
    [[ -r $gtk_css ]] && cat "$gtk_css" >> "$gtk_tmp"
    install -m 644 "$gtk_tmp" "$gtk_css"
    rm -f "$gtk_tmp"
  fi
done

# Egy hivas az osszes generatort lefuttatja. Ha a daemon mar fut, o vegzi el
# (es azonnal ertesiti a shellt); ha nem, a binaris helyben futtatja le.
current_theme=$(<"$target_dir/current-theme")
zen_flag=(--no-zen)
[[ $theme_zen == true ]] && zen_flag=()
"$HOME/.local/bin/vellum" theme apply "$current_theme" "${zen_flag[@]}" >/dev/null

# LazyVim: a colorscheme-et a backend generalja a Neovim site mappajaba, itt
# csak a plugin spec kerul a helyere. Sajat vellum.lua-t nem irunk felul.
nvim_plugins="$HOME/.config/nvim/lua/plugins"
if [[ -d $nvim_plugins ]]; then
  for nvim_module in vellum.lua vellum-keys.lua; do
    nvim_spec="$nvim_plugins/$nvim_module"
    if [[ ! -e $nvim_spec ]]; then
      install -m 644 "$source_dir/nvim/$nvim_module" "$nvim_spec"
    elif ! cmp -s "$source_dir/nvim/$nvim_module" "$nvim_spec"; then
      printf 'Figyelmeztetes: sajat %s marad ervenyben; a Vellum spec NEM kerul be.\n' "$nvim_spec" >&2
    fi
  done
fi

btop_config="$HOME/.config/btop/btop.conf"
if [[ -r $btop_config ]] && grep -Eq '^[[:space:]]*color_theme[[:space:]]*=' "$btop_config"; then
  sed -i -E 's|^[[:space:]]*color_theme[[:space:]]*=.*$|color_theme = "vellum"|' "$btop_config"
else
  printf '\ncolor_theme = "vellum"\n' >> "$btop_config"
fi

fc-cache -f >/dev/null 2>&1 || true
sudo systemctl enable --now NetworkManager.service
# A Bluetooth nem minden gepen letezik; a hianya nem allithatja meg a setupot.
sudo systemctl enable --now bluetooth.service || \
  printf 'Figyelmeztetes: a bluetooth.service nem indithato (nincs adapter?).\n' >&2
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
# A megorzott sajat modulokat itt is elmondjuk: a setup kulonben sikeresnek
# latszana Vellum gyorsbillentyuk nelkul.
report_preflight
if [[ ! -r "$target_dir/current-wallpaper" ]]; then
  printf 'Tegy egy kepet a %s mappaba; a shell automatikusan az elsot valasztja.\n' "$HOME/Pictures/wallpapers"
fi

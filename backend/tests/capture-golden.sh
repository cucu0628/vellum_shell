#!/usr/bin/env bash
# Rogziti a bash tema-generatorok kimenetet minden temara, hogy a Rust
# implementacio byte-ra osszehasonlithato legyen veluk.
#
# TORTENETI: a generatorok azota torlodtek, ezert ez a script csak olyan
# commiton fut le, ahol a scripts/*-theme meg letezik (a torles elotti allapot:
# `git stash` nelkul `git checkout <commit> -- scripts/`). A rogzitett baseline
# a backend/tests/golden/ alatt van, es a golden.rs teszt azt hasznalja.
#
# Egy homokozo HOME-ban fut, gsettings/systemctl/magick shimekkel, igy nem
# nyul az eles konfiguraciohoz. Futtatas:
#
#   backend/tests/capture-golden.sh
#
# Kimenet: backend/tests/golden/<slug>/<generator>
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
golden="$repo/backend/tests/golden"
sandbox=$(mktemp -d -t vellum-golden-XXXXXX)
trap 'rm -rf "$sandbox"' EXIT

home="$sandbox/home"
vs="$home/.config/quickshell/vellum_shell"
mkdir -p "$vs" "$sandbox/bin"

# A homokozo csak azt kapja meg, amire a generatoroknak szuksege van.
cp -r "$repo/scripts" "$repo/themes" "$repo/assets" "$vs/"
mkdir -p "$vs/sddm/vellum-ink"
[[ -r "$repo/lockscreen-monitor" ]] && cp "$repo/lockscreen-monitor" "$vs/"

# Mellekhatasok kiiktatasa: a shimek csak naploznak.
for cmd in gsettings systemctl kwriteconfig6 dconf magick; do
  cat > "$sandbox/bin/$cmd" <<SHIM
#!/usr/bin/env bash
printf '%s %s\n' "$cmd" "\$*" >> "\$VELLUM_SHIM_LOG"
exit 0
SHIM
  chmod +x "$sandbox/bin/$cmd"
done

# A generatorok es a kimeneteik. Az icon-theme nem ir fajlt, csak gsettings-t
# hiv -- annak a shim naploja a "kimenete".
declare -A outputs=(
  [kitty-theme]='kitty-theme.conf'
  [gtk-theme]='gtk-theme.css'
  [hyprland-theme]='@HOME@/.config/hypr/colors.lua'
  [btop-theme]='@HOME@/.config/btop/themes/vellum.theme'
  [fastfetch-theme]='@HOME@/.config/fastfetch/vellum.svg'
  [sddm-theme]='sddm/vellum-ink/theme.conf'
  [zen-theme]='zen-theme.css'
)

generators=(kitty-theme gtk-theme hyprland-theme btop-theme fastfetch-theme icon-theme sddm-theme zen-theme)

rm -rf "$golden"
mkdir -p "$golden"

for dir in "$repo"/themes/*/; do
  slug=$(basename "$dir")
  [[ -r "$dir/theme.conf" ]] || continue
  mkdir -p "$golden/$slug"
  printf '%s\n' "$slug" > "$vs/current-theme"

  for gen in "${generators[@]}"; do
    # Tiszta lap minden futas elott, hogy a "nem irt semmit" eset is latszodjon.
    rm -rf "$home/.config/hypr" "$home/.config/btop" "$home/.config/fastfetch"
    rm -f "$vs/kitty-theme.conf" "$vs/gtk-theme.css" "$vs/zen-theme.css" \
          "$vs/zen-content-theme.css" "$vs/sddm/vellum-ink/theme.conf"
    log="$sandbox/shim.log"
    : > "$log"

    if ! HOME="$home" VELLUM_SHIM_LOG="$log" PATH="$sandbox/bin:$PATH" \
         bash "$vs/scripts/$gen" "$vs/themes/$slug/theme.conf" >"$sandbox/stdout" 2>"$sandbox/stderr"; then
      printf 'FAIL %s / %s\n' "$slug" "$gen" >&2
      cp "$sandbox/stderr" "$golden/$slug/$gen.stderr"
      continue
    fi

    out=${outputs[$gen]:-}
    if [[ -n $out ]]; then
      path=${out/@HOME@/$home}
      [[ $path == /* ]] || path="$vs/$path"
      if [[ -r $path ]]; then
        cp "$path" "$golden/$slug/$gen"
      else
        printf 'MISSING %s / %s (%s)\n' "$slug" "$gen" "$path" >&2
      fi
    fi

    # A zen-theme ket CSS-t general.
    if [[ $gen == zen-theme && -r "$vs/zen-content-theme.css" ]]; then
      cp "$vs/zen-content-theme.css" "$golden/$slug/zen-content-theme"
    fi

    # A gsettings/kwriteconfig hivasok is a szerzodes resze.
    if [[ -s $log ]]; then
      cp "$log" "$golden/$slug/$gen.calls"
    fi
  done
done

printf 'Golden baseline: %s\n' "$golden"
find "$golden" -type f | wc -l | xargs printf '%s fajl rogzitve\n'

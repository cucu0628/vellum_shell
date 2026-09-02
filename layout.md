# Vellum Shell célstruktúra

Ez a dokumentum a shell végleges, feature-alapú szerkezetét írja le. A gyökérben csak a stabil belépési pontok, a felhasználói adatok és a külső segédprogramok maradnak. Az alkalmazás-összeállítás az `app/`, a platform- és állapotkezelés a `core/`, az újrahasznosítható vizuális elemek a `ui/`, az önálló felületek pedig a `features/` könyvtárba kerülnek.

## Célfa

```text
vellum_shell/
├── shell.qml                         # Stabil fő belépési pont, csak kompozíció
├── LockShell.qml                     # Stabil külön processzes lock belépési pont
├── layout.md                         # Architektúra és célstruktúra
├── README.md                         # Telepítés, használat és IPC dokumentáció
├── AGENTS.md                         # Közreműködői útmutató (a CLAUDE.md ide mutat)
├── CLAUDE.md                         # Az AGENTS.md betöltése Claude Code alatt
├── app/                              # Alkalmazásszintű összekötés
│   ├── LazyPopup.qml                 # Popup héj: az objektumfa csak nyitáskor épül fel
│   ├── PopupCoordinator.qml          # Popup kizárás, monitor és nyitási szabályok
│   └── ShellIpc.qml                  # Publikus Quickshell IPC felület
├── assets/                           # Logó és képernyőkép
│   ├── Overview.png
│   └── vellum-logo.svg               # A shell emblémája QML-en kívüli használatra
├── backend/
│   ├── src/
│   │   ├── ipc/
│   │   │   ├── client.rs             # CLI kliens ugyanahhoz a sockethez
│   │   │   ├── hub.rs                # Snapshotok, szétszórás és lazy topicok
│   │   │   ├── mod.rs
│   │   │   ├── protocol.rs           # Newline-delimited JSON protokoll
│   │   │   └── server.rs             # Unix socket szerver
│   │   ├── modules/
│   │   │   ├── health.rs             # Verzió, pid, uptime; a huzalozás próbája
│   │   │   ├── hypr.rs               # Hyprland monitorok és kompozitor-opciók
│   │   │   ├── mod.rs
│   │   │   ├── network.rs            # Aktív kapcsolat, LAN cím, VPN jelenlét
│   │   │   ├── privacy.rs            # Kamerát használó folyamatok
│   │   │   ├── removable.rs          # Cserélhető adathordozók udisks2-n
│   │   │   ├── sysstats.rs           # CPU, RAM és lemez
│   │   │   ├── theme.rs              # A paletta mint topic, a témaváltás mint parancs
│   │   │   ├── vpn.rs                # ProtonVPN állapot és vezérlés
│   │   │   └── weather.rs            # Open-Meteo lekérdezés és formázás
│   │   ├── theme/
│   │   │   ├── generators/
│   │   │   │   ├── btop.rs           # btop színséma
│   │   │   │   ├── fastfetch.rs      # Fastfetch konfiguráció és logó
│   │   │   │   ├── gtk.rs            # GTK3/GTK4 színváltozók
│   │   │   │   ├── hyprland.rs       # Ablakkeret-színek
│   │   │   │   ├── icon.rs           # Ikontéma választása
│   │   │   │   ├── kitty.rs          # kitty színséma
│   │   │   │   ├── mod.rs
│   │   │   │   ├── neovim.rs         # Neovim colorscheme (LazyVim)
│   │   │   │   ├── sddm.rs           # SDDM greeter theme.conf
│   │   │   │   └── zen.rs            # Zen Browser stíluslapok és profil-bekötés
│   │   │   ├── color.rs              # Színműveletek (mix, luminancia, árnyalat)
│   │   │   ├── material.rs           # Natív Material You paletta háttérképből
│   │   │   ├── mod.rs
│   │   │   ├── palette.rs            # A theme.conf olvasása
│   │   │   ├── paths.rs              # A backend által ismert útvonalak
│   │   │   └── render.rs             # Sablonmotor és atomikus fájlkiírás
│   │   ├── dbus.rs                   # Megosztott rendszerbusz-kapcsolat
│   │   ├── edid.rs                   # Monitor-azonosítás EDID-ből
│   │   ├── lib.rs                    # Könyvtár gyökér a teszteknek és a binárisnak
│   │   ├── main.rs                   # CLI és daemon belépési pont
│   │   ├── module.rs                 # A `Module` trait és a modul-önleírás
│   │   └── nm.rs                     # NetworkManager D-Bus proxyk
│   ├── templates/                    # Téma-sablonok ({{KULCS}} helyőrzőkkel)
│   │   ├── btop.theme.tmpl
│   │   ├── dynamic-theme.conf.tmpl
│   │   ├── gtk-theme.css.tmpl
│   │   ├── hyprland-colors.lua.tmpl
│   │   ├── kitty.conf.tmpl
│   │   ├── nvim-colors.lua.tmpl
│   │   ├── sddm-theme.conf.tmpl
│   │   ├── zen-content-theme.css.tmpl
│   │   └── zen-theme.css.tmpl
│   ├── tests/                        # Golden baseline és a rögzítő script
│   │   ├── golden/
│   │   ├── capture-golden.sh
│   │   └── golden.rs                 # Golden teszt a bash baseline ellen
│   ├── build.rs                      # Git revízió beégetése a binárisba
│   ├── Cargo.lock
│   ├── Cargo.toml
│   └── rustfmt.toml                  # A fa stílusához rögzített formázás
├── core/                             # UI-független shell szolgáltatások
│   ├── AudioSummaryController.qml    # Panel hangerőállapot
│   ├── Backend.qml
│   ├── BatteryStatusController.qml   # Opcionális rendszerakku állapot
│   ├── BluetoothStatusController.qml # Bluez adapter és eszközlista nézete
│   ├── CavaController.qml            # Hangvizualizáció, csak lejátszás közben fut
│   ├── MprisController.qml           # Aktív médialejátszó kiválasztása
│   ├── NetworkStatusController.qml   # Aktív kapcsolat a backend `network` topicjából
│   ├── PrivacyController.qml         # Mikrofon- és kamerahasználat figyelése
│   ├── RemovableDeviceController.qml # Cserélhető kötetek és mount műveletek
│   ├── ThemeStore.qml                # Paletta betöltése és frissítése
│   ├── VpnController.qml             # ProtonVPN állapot a backend `vpn` topicjából
│   ├── WallpaperController.qml       # Háttérkép állapot és monitorablakok
│   └── WorkspaceController.qml       # Hyprland workspace állapot
├── features/                         # Önálló shell funkciók
│   ├── about/
│   │   ├── AboutPopup.qml
│   │   ├── InfoRow.qml
│   │   ├── InfoSectionCard.qml
│   │   └── SystemInfoController.qml
│   ├── ai/
│   │   └── AiUsagePopup.qml          # Codex/Claude előfizetés-használat panel
│   ├── appearance/
│   │   ├── AppearanceController.qml
│   │   ├── AppearanceStudio.qml
│   │   ├── PaletteRail.qml           # Palettasáv a Studióban
│   │   ├── StudioDock.qml            # A Studio alsó dokkja
│   │   └── WallpaperRail.qml         # Háttérkép-sáv a Studióban
│   ├── audio/
│   │   ├── AudioPopup.qml
│   │   ├── CompactDeviceRow.qml
│   │   ├── DeviceCard.qml
│   │   ├── EmptyCard.qml
│   │   ├── PickerToggle.qml
│   │   ├── SectionHeader.qml         # Általános szekciófejléc
│   │   ├── StreamRow.qml
│   │   └── VolumeBar.qml
│   ├── bar/
│   │   ├── AiStatusItem.qml          # AI használat jelző a sávon
│   │   ├── AudioStatusItem.qml
│   │   ├── BarWindow.qml
│   │   ├── BatteryStatusItem.qml
│   │   ├── BluetoothStatusItem.qml
│   │   ├── BtopStatusItem.qml
│   │   ├── CenterClock.qml
│   │   ├── ConnectivityStatusItem.qml # Hálózat + VPN egyetlen modulban
│   │   ├── NotificationStatusItem.qml
│   │   ├── PrivacyStatusItem.qml     # Mikrofon/kamera jelző a workspacek mellett
│   │   ├── RemovableDeviceStatusItem.qml
│   │   ├── TrayGroup.qml
│   │   └── WorkspaceGroup.qml
│   ├── bluetooth/
│   │   └── BluetoothPopup.qml
│   ├── clipboard/
│   │   ├── ClipboardController.qml
│   │   ├── ClipboardPopup.qml
│   │   └── ClipboardResultRow.qml
│   ├── launcher/
│   │   ├── DesktopIconResolver.qml
│   │   ├── EmojiData.qml             # Emoji adatbázis a launchernek
│   │   ├── FrecencyStore.qml
│   │   ├── LauncherActions.qml       # Rendszerműveletek a launcherben
│   │   ├── LauncherPopup.qml
│   │   └── LauncherResultRow.qml
│   ├── lock/
│   │   ├── AmbientLockView.qml       # Többi monitor ambient nézete
│   │   ├── AuthenticationController.qml
│   │   ├── LockBackground.qml        # Elhomályosuló asztali háttérkép, fátyol, ensō vízjel
│   │   ├── LockCard.qml              # Beviteli monitor panelje
│   │   ├── LockClock.qml             # Óra, dátum, napi haladásjelző
│   │   ├── LockRoot.qml              # LockShell.qml belső implementációja
│   │   ├── LockScreenSettingsController.qml
│   │   ├── LockThemeController.qml   # Paletta és háttérkép a `theme` topicból
│   │   ├── PasswordField.qml
│   │   └── PowerStatusController.qml
│   ├── media/
│   │   ├── CalendarCard.qml
│   │   ├── MediaCard.qml
│   │   ├── MediaPopup.qml
│   │   ├── PlaybackPositionController.qml
│   │   ├── SystemStatsCard.qml
│   │   └── SystemStatsController.qml
│   ├── network/
│   │   ├── ConnectivityPopup.qml     # Közös Wi-Fi/VPN panel fülekkel
│   │   ├── NetworkPanel.qml          # Wi-Fi fül tartalma
│   │   └── ThroughputController.qml  # Le-/feltöltési sebesség a /proc/net/dev-ből
│   ├── notifications/
│   │   ├── NotificationCenter.qml
│   │   ├── NotificationEntryRow.qml  # Egyetlen értesítés sor akciógombokkal
│   │   ├── NotificationGroup.qml     # Alkalmazás szerinti csoport fejléccel és nyitható listával
│   │   ├── NotificationsController.qml
│   │   ├── NotificationsHost.qml
│   │   └── NotificationToast.qml
│   ├── osd/
│   │   └── VolumeOsd.qml             # Hangerő OSD
│   ├── polkit/
│   │   └── PolkitDialog.qml          # Polkit hitelesítési ügynök
│   ├── privacy/
│   │   └── PrivacyPopup.qml          # Mikrofont/kamerát használó appok listája
│   ├── removable/
│   │   └── RemovableDevicePopup.qml  # Mount, unmount, megnyitás és leválasztás
│   ├── screenshot/
│   │   └── ScreenshotController.qml  # Képernyőkép-módok indítása
│   ├── settings/
│   │   ├── ActionButton.qml          # Beállítások gomb
│   │   ├── DisplayPage.qml           # Monitorok, visszaszámlálós megerősítéssel
│   │   ├── InputPage.qml             # Bevitel oldal
│   │   ├── KeybindingsController.qml # Gyorsbillentyűk beolvasása
│   │   ├── KeybindingsPage.qml       # Kereshető gyorsbillentyű-jegyzék
│   │   ├── MonitorCanvas.qml         # Monitor-elrendezés vászon
│   │   ├── SettingsController.qml    # A settings állapota és backend-hívásai
│   │   ├── SettingsSection.qml       # Beállítás-szekció
│   │   ├── SettingsSidebar.qml       # Oldalsáv
│   │   ├── SettingsWindow.qml        # A settings FloatingWindow ablaka
│   │   ├── SystemController.qml      # Rendszer-oldal állapota
│   │   ├── SystemPage.qml            # Rendszer oldal
│   │   ├── TextSetting.qml           # Szöveges beállítás
│   │   └── WindowsPage.qml           # Ablakok oldal
│   ├── tray/
│   │   └── TrayMenu.qml
│   ├── vpn/
│   │   └── VpnPanel.qml              # Proton VPN fül tartalma
│   └── weather/
│       ├── WeatherCard.qml
│       └── WeatherController.qml
├── hypr/                             # Telepíthető Hyprland modulok
│   ├── autostart.lua
│   └── bindings.lua
├── nvim/                             # Telepíthető Neovim modulok
│   ├── vellum-keys/                  # Állandó gyorsbillentyű-súgó plugin
│   │   └── lua/vellum_keys/
│   │       ├── init.lua              # Lebegő ablak, módkövetés, kapcsoló
│   │       └── keys.lua              # A súgó tartalma módonként
│   ├── vellum-keys.lua               # LazyVim spec a súgóhoz
│   └── vellum.lua                    # LazyVim spec: colorscheme és élő újratöltés
├── pam/                              # PAM profil a zárolóképernyőhöz
│   └── vellum-shell
├── scripts/                          # Külső shell műveletek
│   ├── ai-usage-claude
│   ├── ai-usage-codex
│   ├── aur-install
│   ├── backend-install
│   ├── floating-terminal
│   ├── keybindings-list
│   ├── launch-bluetooth
│   ├── launch-wifi
│   ├── lib.sh
│   ├── lockscreen-monitor
│   ├── pkg-install
│   ├── pkg-remove
│   ├── screenshot-capture
│   ├── sddm-install
│   ├── sddm-layout
│   ├── shell-start
│   ├── theme-current
│   ├── theme-refresh
│   ├── tui-install
│   ├── tui-remove
│   ├── weather-location
│   ├── webapp-install
│   └── webapp-remove
├── sddm/                             # Vellum Ink greeter téma
│   └── vellum-ink/
│       ├── InkAmbient.qml            # Greeter ambient nézet
│       ├── InkBackground.qml         # Greeter háttér
│       ├── InkCard.qml               # Greeter bejelentkező kártya
│       ├── InkClock.qml              # Greeter óra
│       ├── InkGlow.qml               # Greeter fényudvar
│       ├── InkPasswordField.qml      # Greeter jelszómező
│       ├── InkPicker.qml             # Greeter választó
│       ├── InkPickerList.qml         # Greeter választólista
│       ├── InkPowerButton.qml        # Greeter energiagomb
│       ├── InkSeal.qml               # Greeter pecsét
│       ├── InkShutter.qml            # Greeter shoji animáció
│       ├── Main.qml                  # SDDM greeter belépési pont
│       ├── metadata.desktop
│       └── theme.conf
├── systemd/                          # A backend user service-e
│   └── vellum-shelld.service
├── themes/                           # Deklaratív színpaletták
│   ├── catppuccin-mocha/
│   │   └── theme.conf
│   ├── dynamic-matugen/
│   │   └── theme.conf
│   ├── gruvbox-material/
│   │   └── theme.conf
│   ├── japanese-ink/
│   │   └── theme.conf
│   ├── kanagawa-wave/
│   │   └── theme.conf
│   ├── monochrome/
│   │   └── theme.conf
│   ├── rose-pine/
│   │   └── theme.conf
│   ├── sakura-blossom/
│   │   └── theme.conf
│   └── tokyo-night/
│       └── theme.conf
├── ui/                               # Feature-független vizuális elemek
│   ├── CalendarGrid.qml              # Közös 6x7 naptárrács
│   ├── DashPanel.qml                 # Dashboard panelkeret fejléccel és elválasztóval
│   ├── DashTile.qml                  # Dashboard adatcsempe (érték, ikon, felirat)
│   ├── SearchField.qml               # Közös keresőmező
│   ├── SettingRow.qml                # Beállítássor: címke, leírás, vezérlő
│   ├── SettingSelect.qml             # Legördülő vezérlő
│   ├── SettingSlider.qml             # Csúszka vezérlő
│   ├── SettingToggle.qml             # Kapcsoló vezérlő
│   └── ShellLogo.qml                 # Shell embléma (ensō), témaszínt vesz fel
├── .gitignore
├── install.sh                        # Csomagfüggőségek telepítése
└── setup.sh                          # Teljes rendszerbeállítás

# Futásidőben keletkező, nem verziózott állapot a shell gyökerében:
#   current-theme, current-wallpaper, current-weather-location,
#   lockscreen-monitor, kitty-theme.conf, gtk-theme.css, zen-theme.css
```

## Rétegek felelőssége

### `shell.qml`

- Stabil Quickshell belépési pont.
- Létrehozza a core szolgáltatásokat és feature gyökereket.
- Összeköti a feature signalokat az alkalmazásszintű koordinátorokkal.
- Nem tartalmaz hosszú UI delegate-et, adatparsert vagy polling implementációt.

### `app/`

- Több feature-t érintő alkalmazásszintű szabályokat kezel.
- A popupok kölcsönös kizárása itt történik.
- Az IPC targetek csak ezt a réteget hívják.
- Nem végez platform pollingot és nem rajzol felületet.

### `core/`

- Hyprland, PipeWire, MPRIS és a Rust backend állapotát kezeli.
- Nem ismeri a popupok vizuális felépítését.
- Szűk property és függvény API-t ad a feature-öknek.
- A `core/Backend.qml` az egyetlen pont, ami a backend sockethez beszél; a többi
  controller csak a `topics` térképre köt rá.

### `backend/`

- Rust daemon: téma-motor és rendszerállapot, Unix socketen JSON-lines protokollal.
- Egy fájl egy képesség a `src/modules/` alatt, plusz egy sor a registryben.
- Nem ismeri a QML-t: a topicok és metódusok neve a szerződés, amit a `describe`
  művelet ad ki.

### `ui/`

- Csak általánosan újrahasznosítható vizuális primitiveket tartalmaz.
- Nem hivatkozik shell feature ID-kra vagy core singletonokra.
- Az adatokat property-ken, a műveleteket signalokon keresztül kapja.

### `features/`

- Egy mappa egy felhasználói funkció.
- A feature popup, controller, tároló és saját delegate fájljai együtt maradnak.
- Más feature belső ID-jára nem hivatkozhat.
- Feature-k közötti koordináció az `app/` rétegen keresztül történik.

## Függőségi irány

```text
shell.qml
  ├── app/
  ├── core/
  └── features/
        └── ui/

app/      -> feature gyökér API-k
features/ -> core API-k és ui primitivek
core/     -> Quickshell szolgáltatások és külső rendszer
ui/       -> QtQuick
```

Az alsóbb réteg nem importálhat magasabb réteget. A `core/` nem importál `features/` típust, a `ui/` pedig nem importál sem `core/`, sem `features/` típust.

## Stabil kompatibilitási pontok

- `shell.qml` útvonala nem változik, mert az IPC parancsok erre hivatkoznak.
- `LockShell.qml` megmarad kompatibilitási belépési pontként; a fő shell a lockscreent IPC-n aktiválja.
- A feature popupokat a `shell.qml` közvetlen, névterezett importokkal példányosítja; nincs szükség gyökér wrapper fájlokra.
- Az IPC targetek neve és metódusai kompatibilisek maradnak: `settings`, `menu`,
  `launcher`, `clipboard`, `style`, `power`, `lock`, `notifications`, `audio`,
  `about`. A `menu` és `power` a megszűnt menü paletta helyett a settings appot
  nyitja, de a nevük megmarad.
- A backend socketje (`$XDG_RUNTIME_DIR/vellum-shell.sock`), a protokoll `v: 1`
  verziója, valamint a topicok és metódusok nevei kompatibilisek maradnak: ezekre
  épül a QML kliens, a CLI és a settings app is.
- A `themes/<slug>/theme.conf` kulcsai kompatibilisek maradnak; a generátorok
  kimenetét golden teszt védi a korábbi bash scriptek rögzített kimenetével.

## Migráció állapota

### Elkészült

- `core/` theme, wallpaper, workspace, audio summary, VPN és MPRIS controllerek.
- `app/PopupCoordinator.qml` és `app/ShellIpc.qml`.
- `features/bar/` teljes topbar felbontás.
- Notification controller, toast és center felbontás.
- Értesítés csoportosítás alkalmazás szerint (`NotificationGroup.qml`, `NotificationEntryRow.qml`).
- Media, weather, system stats és calendar card felbontás.
- Launcher frecency és desktop ikon resolver.
- Clipboard backend és perzisztencia controller.
- Közös keresőmező és naptárrács.
- Audio, About és Power levélkomponensek.
- Appearance controller és az alsó dokk a wallpaper coverflow és palette
  sávval. Nincs mock felület: az előnézet maga az élő shell.
- About rendszerinformáció controller.
- A felesleges gyökér popup wrapperek megszűntek; a `shell.qml` közvetlenül importálja a feature-típusokat.
- Lock theme, power, PAM controller, háttér, card és password field szétválasztása.
- Lockscreen újratervezés a shell panelnyelvén: a zárás az asztali háttérképet
  homályosítja el fekete átmenet helyett, fölötte nagy óra és `ui/PopupFrame`
  formájú kártya. A shoji redőny, a pecsét és a fényfolt megszűnt.
- A feloldás két ütemű (`closing`, majd `thawing`): előbb a panel tűnik el, utána
  enged fel a homály, a fátyol, a vignetta és a vízjel. A `WlSessionLock`-ot csak
  akkor engedjük el, amikor a felület már pontosan az asztali háttérkép, így az
  utolsó képkocka és az asztal között nincs ugrás.
- Rust backend: protokoll, hub, lazy topicok és a `core/Backend.qml` kliens
  automatikus újracsatlakozással.
- Téma-motor: paletta, színmatek és a nyolc generátor egy helyen, natív Material
  You-val (a `matugen` függőség megszűnt; a `jq`-t a screenshot- és lockscreen
  segédscriptek továbbra is használják). A kimenetet golden teszt védi.
- Állapot modulok: `network`, `vpn`, `removable`, `privacy`, `sysstats`, `weather`.
- A backend systemd user service-ként indul bejelentkezéskor; a futó példány
  jelenti a git revízióját (`vellum ping`).
- Settings app (`features/settings/`) igazi `FloatingWindow` ablakban, oldalsávos
  navigációval: Display, Windows, Input, System és Keybindings oldal. A menü
  paletta megszűnt; a műveletei, köztük a csomagkezelő workflow-k a launcherbe,
  a beállításai ide kerültek.
- `hypr` backend modul: monitorok és kompozitor-opciók olvasása `hyprctl`-lel,
  írása élőben (`hyprctl eval` + natív Lua API) és perzisztensen. A perzisztens forma egy
  `~/.config/hypr/vellum-settings.json` store, amiből a `vellum_display.lua` és
  `vellum_tuning.lua` generálódik -- a felhasználó saját moduljaihoz nem nyúlunk.
- Launcher prefix nélkül: alkalmazás, művelet, emoji és számolás egyetlen
  pontszámozott listában. A `>` csak a projektkereséshez maradt meg, a
  webkeresés megszűnt.

- A kiváltott bash tema- es allapot-scriptek eltávolítva; a `scripts/` már csak
  telepítőket és interaktív segédeket tartalmaz.

### Következő

- Integrációs teszt külön vagy nested Wayland sessionben.
- `ai-usage-claude` / `ai-usage-codex` portolása, ha megéri.

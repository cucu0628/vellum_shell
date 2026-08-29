# Vellum Shell célstruktúra

Ez a dokumentum a shell végleges, feature-alapú szerkezetét írja le. A gyökérben csak a stabil belépési pontok, a felhasználói adatok és a külső segédprogramok maradnak. Az alkalmazás-összeállítás az `app/`, a platform- és állapotkezelés a `core/`, az újrahasznosítható vizuális elemek a `ui/`, az önálló felületek pedig a `features/` könyvtárba kerülnek.

## Célfa

```text
vellum_shell/
├── shell.qml                         # Stabil fő belépési pont, csak kompozíció
├── LockShell.qml                     # Stabil külön processzes lock belépési pont
├── layout.md                         # Architektúra és célstruktúra
├── README.md                         # Telepítés, használat és IPC dokumentáció
│
├── assets/                           # Statikus erőforrások
│   └── vellum-logo.svg                  # A shell emblémája QML-en kívüli használatra
│
├── app/                              # Alkalmazásszintű összekötés
│   ├── PopupCoordinator.qml          # Popup kizárás, monitor és nyitási szabályok
│   ├── ShellIpc.qml                  # Publikus Quickshell IPC felület
│   └── ShellComposition.qml          # Opcionális végső kompozíciós komponens
│
├── core/                             # UI-független shell szolgáltatások
│   ├── Paths.qml                     # Központi fájl- és scriptútvonalak
│   ├── ThemeStore.qml                # Paletta betöltése és frissítése
│   ├── WallpaperController.qml       # Háttérkép állapot és monitorablakok
│   ├── WorkspaceController.qml       # Hyprland workspace állapot
│   ├── AudioSummaryController.qml    # Panel hangerőállapot
│   ├── BatteryStatusController.qml   # Opcionális rendszerakku állapot
│   ├── VpnStatusController.qml       # Aktív VPN lekérdezése
│   ├── PrivacyController.qml         # Mikrofon- és kamerahasználat figyelése
│   ├── RemovableDeviceController.qml # Cserélhető kötetek és mount műveletek
│   ├── MprisController.qml           # Aktív médialejátszó kiválasztása
│   └── CommandRunner.qml             # Megosztott parancsindítás, ahol indokolt
│
├── ui/                               # Feature-független vizuális elemek
│   ├── SearchField.qml               # Közös keresőmező
│   ├── ShellLogo.qml                 # Shell embléma (torii), témaszínt vesz fel
│   ├── CalendarGrid.qml              # Közös 6x7 naptárrács
│   ├── DashPanel.qml                 # Dashboard panelkeret fejléccel és elválasztóval
│   ├── DashTile.qml                  # Dashboard adatcsempe (érték, ikon, felirat)
│   ├── OverlayWindow.qml             # Teljes képernyős overlay alap
│   ├── PopupFrame.qml                # Keret, háttér és nyitási animáció
│   ├── PopupHeader.qml               # Egységes popup fejléc
│   ├── SectionHeader.qml             # Általános szekciófejléc
│   ├── SelectableRow.qml             # Kijelölhető listaelem alap
│   └── IconButton.qml                # Panel- és popup ikon gomb
│
├── features/                         # Önálló shell funkciók
│   ├── bar/
│   │   ├── BarWindow.qml
│   │   ├── WorkspaceGroup.qml
│   │   ├── PrivacyStatusItem.qml     # Mikrofon/kamera jelző a workspacek mellett
│   │   ├── CenterClock.qml
│   │   ├── TrayGroup.qml
│   │   ├── ConnectivityStatusItem.qml # Hálózat + VPN egyetlen modulban
│   │   ├── BluetoothStatusItem.qml
│   │   ├── RemovableDeviceStatusItem.qml
│   │   ├── AudioStatusItem.qml
│   │   ├── NotificationStatusItem.qml
│   │   ├── BtopStatusItem.qml
│   │   ├── BatteryStatusItem.qml
│   │
│   ├── menu/
│   │   ├── MenuPopup.qml
│   │   ├── MenuController.qml
│   │   ├── MenuData.qml
│   │   └── MenuResultRow.qml
│   │
│   ├── launcher/
│   │   ├── LauncherPopup.qml
│   │   ├── LauncherResultRow.qml
│   │   ├── FrecencyStore.qml
│   │   ├── DesktopIconResolver.qml
│   │   ├── LauncherAliases.qml
│   │   └── EmojiData.qml
│   │
│   ├── clipboard/
│   │   ├── ClipboardPopup.qml
│   │   ├── ClipboardController.qml
│   │   └── ClipboardResultRow.qml
│   │
│   ├── notifications/
│   │   ├── NotificationsHost.qml
│   │   ├── NotificationsController.qml
│   │   ├── NotificationToast.qml
│   │   ├── NotificationCenter.qml
│   │   ├── NotificationGroup.qml     # Alkalmazás szerinti csoport fejléccel és nyitható listával
│   │   └── NotificationEntryRow.qml  # Egyetlen értesítés sor akciógombokkal
│   │
│   ├── media/
│   │   ├── MediaPopup.qml
│   │   ├── MediaCard.qml
│   │   ├── CalendarCard.qml
│   │   ├── SystemStatsCard.qml
│   │   ├── SystemStatsController.qml
│   │   └── PlaybackPositionController.qml
│   │
│   ├── bluetooth/
│   │   └── BluetoothPopup.qml
│   │
│   ├── privacy/
│   │   └── PrivacyPopup.qml          # Mikrofont/kamerát használó appok listája
│   │
│   ├── removable/
│   │   └── RemovableDevicePopup.qml  # Mount, unmount, megnyitás és leválasztás
│   │
│   ├── network/
│   │   ├── ConnectivityPopup.qml     # Közös Wi-Fi/VPN panel fülekkel
│   │   └── NetworkPanel.qml          # Wi-Fi fül tartalma
│   │
│   ├── vpn/
│   │   └── VpnPanel.qml              # Proton VPN fül tartalma
│   │
│   ├── weather/
│   │   ├── WeatherController.qml
│   │   └── WeatherCard.qml
│   │
│   ├── audio/
│   │   ├── AudioPopup.qml
│   │   ├── SectionHeader.qml
│   │   ├── EmptyCard.qml
│   │   ├── VolumeBar.qml
│   │   ├── DeviceCard.qml
│   │   ├── PickerToggle.qml
│   │   ├── CompactDeviceRow.qml
│   │   └── StreamRow.qml
│   │
│   ├── appearance/
│   │   ├── AppearanceStudio.qml
│   │   ├── AppearanceController.qml
│   │   ├── ScenePreview.qml
│   │   ├── WallpaperFilmstrip.qml
│   │   └── ThemeArchive.qml
│   │
│   │
│   │
│   ├── about/
│   │   ├── AboutPopup.qml
│   │   ├── SystemInfoController.qml
│   │   ├── InfoSectionCard.qml
│   │   └── InfoRow.qml
│   │
│   ├── tray/
│   │   └── TrayMenu.qml
│   │
│   └── lock/
│       ├── LockRoot.qml              # LockShell.qml belső implementációja
│       ├── LockThemeController.qml
│       ├── PowerStatusController.qml
│       ├── AuthenticationController.qml
│       ├── LockScreenSettingsController.qml
│       ├── LockBackground.qml        # Csendes háttér: ensō kör, vignetta
│       ├── LockGlow.qml              # Rétegzett puha fényfolt
│       ├── LockShutter.qml           # Shoji nyitó/záró animáció minden monitoron
│       ├── LockSeal.qml              # Forgó zárjel
│       ├── LockClock.qml             # Óra, dátum, napi haladásjelző
│       ├── LockCard.qml              # Beviteli monitor panelje
│       ├── AmbientLockView.qml       # Többi monitor ambient nézete
│       └── PasswordField.qml
│
├── scripts/                          # Külső shell műveletek
│   ├── lib.sh
│   ├── theme-read
│   ├── theme-list
│   ├── theme-current
│   ├── theme-refresh
│   ├── matugen-theme
│   ├── weather-location
│   ├── floating-terminal
│   ├── camera-usage
│   ├── launch-wifi
│   ├── launch-bluetooth
│   ├── keybindings-list
│   ├── pkg-install
│   ├── pkg-remove
│   ├── aur-install
│   ├── tui-install
│   ├── tui-remove
│   ├── webapp-install
│   └── webapp-remove
│
├── themes/                           # Deklaratív színpaletták
│   ├── catppuccin-mocha/theme.conf
│   ├── dynamic-matugen/theme.conf
│   ├── gruvbox-material/theme.conf
│   ├── japanese-ink/theme.conf
│   ├── kanagawa-wave/theme.conf
│   ├── rose-pine/theme.conf
│   ├── sakura-blossom/theme.conf
│   └── tokyo-night/theme.conf
│
├── wallpapers/                       # Beépített háttérképek
├── current-theme                     # Aktuális theme neve
├── current-wallpaper                 # Aktuális háttérkép elérési útja
└── current-weather-location          # Aktuális időjárási hely
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
- Az IPC targetek neve és metódusai kompatibilisek maradnak: `menu`, `launcher`, `clipboard`, `style`, `power`, `lock`, `notifications`, `audio`, `about`.
- A backend socketje (`$XDG_RUNTIME_DIR/vellum-shell.sock`), a protokoll `v: 1`
  verziója, valamint a topicok és metódusok nevei kompatibilisek maradnak: ezekre
  épül a QML kliens, a CLI és egy későbbi settings app is.
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
- Menu dinamikus adatcontroller.
- Közös keresőmező és naptárrács.
- Audio, About és Power levélkomponensek.
- Appearance controller, scene preview, wallpaper filmstrip és theme archive.
- About rendszerinformáció controller.
- A felesleges gyökér popup wrapperek megszűntek; a `shell.qml` közvetlenül importálja a feature-típusokat.
- Lock theme, power, PAM controller, háttér, card és password field szétválasztása.
- Lockscreen újratervezés csendes tus stílusban: ensō háttér, pecsét, óra és shoji nyitó/záró animáció.
- Rust backend: protokoll, hub, lazy topicok és a `core/Backend.qml` kliens
  automatikus újracsatlakozással.
- Téma-motor: paletta, színmatek és a nyolc generátor egy helyen, natív Material
  You-val (a `matugen` és `jq` függőség megszűnt). A kimenetet golden teszt védi.
- Állapot modulok: `network`, `vpn`, `removable`, `privacy`, `sysstats`, `weather`.
- A backend systemd user service-ként indul bejelentkezéskor; a futó példány
  jelenti a git revízióját (`vellum ping`).

### Következő

- Integrációs teszt külön vagy nested Wayland sessionben.
- A kiváltott bash scriptek eltávolítása (lásd a README Backend szakaszát).
- `ai-usage-claude` / `ai-usage-codex` portolása, ha megéri.

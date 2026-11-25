# Spanish translation for butterdwm (dwm + Quickshell)

Translates **butterdwm** by [JustAGuy Linux](https://justaguy.dev/butter/dwm)
into Spanish (es_MX): dwm with the **Quickshell** bar, on Debian 13. It covers
the bar, the network app, the shortcut help (`Super+/`) and the messages of its
scripts. It also applies fixes so the bar works well in Spanish.

**Version 9**: built and tested on butterdwm `e3f9958` (November 23, 2026).
It also ships `traducir-en-vivo.sh`, a translator that works on **any**
butterdwm version without replacing files (see `TRADUCIR-EN-VIVO.md`).
Version 8 was built on `35da28a` (November 20, 2026).
It also migrates a machine that already had version 6 or 7: a file that is an
*earlier* translation of this package (`translated-before.tsv`) is
re-translated instead of being left as is. Your own edits are still kept.
The generator (`tools/`) was redesigned so a future butterdwm version is
translated with a single command: `bash tools/regenerate.sh --new <commit>`
(see `tools/README.md`).

## Quick install

```sh
curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install.sh | bash
```

Check without changing anything, or undo:

```sh
curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install.sh | bash -s -- --check
curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install.sh | bash -s -- --restore
```

When done, press **Super+Ctrl+R** to restart the bar. If you ran it from a
terminal in your own session, the script restarts it for you.

## Safe by design

- **Never mixes versions.** A file is only replaced if it is *identical*
  (sha256) to the original English file of the butterdwm version this
  translation was made for (`manifest.txt`). If you edited it, or your
  butterdwm is another version, it stays as is and the script tells you.
- **Respects your shortcuts.** `keybinds.conf` is translated line by line: only
  the descriptions that still match the English original change.
- **Backup first.** Before touching anything it saves `~/butterbian-es-backup-FECHA.tar.gz`,
  and `--restore` leaves everything as it was.
- **No sudo.** Everything is written to `~/.config/suckless`.
- **Does not restart the bar over SSH.** A bar launched from SSH ends up
  outside your graphical session. Apps you open from it (Synaptic, GParted)
  could not ask for your password and would not open. Over SSH it asks you for
  Super+Ctrl+R.
- **No need to recompile dwm.** The shortcut help reads `keybinds.conf` directly.

## What it translates

- **Bar** (`quickshell/`, 29 files): command menu, launcher, metrics, volume,
  weather and radar, notifications, power, displays, calendar and the settings
  panel, including its keybinding, rules, layout, bar and wallpaper editors.
- **Network app** (`quickshell-network/`, `Super+Shift+N`): Wi-Fi, known
  networks, ping, QR sharing, Bluetooth, Tailscale and every status message.
- **Shortcuts** (`dwm/keybinds.conf`): the 79 descriptions of the help.
- **Scripts** (`scripts/`):
  - in the help, the automatic labels ("Ver etiqueta 1", "Diseño: mosaico")
    and the key names (Espacio, Retroceso, Subir vol...);
  - the notices when applying shortcuts and when changing the wallpaper theme,
    and the welcome message;
  - the rofi fallback power menu;
  - the GTK notices (`scripts/gtk-theme`) and the radar errors the card shows
    (`scripts/radar`);
  - the volume notification (`scripts/changevolume`), the update flow
    (`scripts/setup-update`) and the messages of `displays`, `themes`,
    `gen-keybinds`, `install-dwm` and `picom-effects`.

## What it does NOT translate (on purpose)

Some texts look like UI but the program uses them as data. If they are
translated, something stops working:

- key names written to `keybinds.conf` (`Return`, `Left`, `Prior`...);
- sensor labels (`Package id 0`, `Composite`) and the `kill -s KILL` signal;
- nmcli fields (`IN-USE,SIGNAL`) and notification urgencies (`CRITICAL`, `LOW`);
- the `Settings` category of `.desktop` files, Tailscale states and
  bluetoothctl / xrandr output;
- the window titles used by `rules.conf` (`Network`, `butterdwm settings`).

## Fixes it applies

1. **False low-battery warning on desktops.** The aggregate UPower device
   (`DisplayDevice`, or kind `unknown` with 0% and no level) no longer counts
   as a battery.
2. **Clock in Spanish.** `Qt.formatDateTime()` ignores the locale. Now it uses
   `toLocaleString()`, which shows `sáb 7 nov 2:38 p.m.`. The weather radar
   time works the same way.
3. **Calendar in Spanish.** Months and weekdays in Spanish. The week starts on
   Sunday, as in Mexico, with aligned headers and grid.
4. **Full and plugged-in battery** counts as "charging" (the kernel writes `Full`).
5. **nmcli errors in red**, whether they say `failed` or `falló`.
6. **UPower device types in Spanish**: Mouse, Teclado, Audífonos, Control...
7. **Power menu**: p/c/r/a keys (screen, log out, reboot, shut down) and the
   short "confirmar" hint that does not overlap the label.

## Requirements

- butterdwm installed (`~/.config/suckless`) on Debian 13.
- `bash`, `curl`, `tar`, `awk` and `sha256sum` (Debian ships them).
- Locale `es_MX.UTF-8` (`LANG=es_MX.UTF-8`) so Qt gives dates and texts in Spanish.

## If your butterdwm is newer

If `--check` reports files that do not match this package's version, run
`./traducir-en-vivo.sh` instead: it translates the installed files in place
without replacing any file, and works on any version. Unknown new strings are
reported, and can be taught with `--add`. See `TRADUCIR-EN-VIVO.md`. The
`tools/` folder still has the generator to rebuild a versioned package:
`bash tools/regenerate.sh --new <commit>`.

## Notes

- `Wired connection 1` is the NetworkManager profile name, not bar text. If you
  want it in Spanish:
  `sudo nmcli connection modify "Wired connection 1" connection.id "Conexión cableada 1"`

## Changelog

- **v9** (2026-11-24):
  - rebuilt on butterdwm `e3f9958`: the network app's new texts are translated
    without copying a newer payload over the installed files;
  - new `traducir-en-vivo.sh`: translates installed files in place, any
    version, no file replacement, backups, `--check`, `--restore`, `--verbose`,
    `--add` to teach new strings;
  - shipped data files for the live translator: `rules_extra.tsv`,
    `revert.tsv`, `ignore.tsv`; 16/16 tests on a real copy of the desktop.
- **v8** (2026-11-22): the last texts that were still in English:
  - the displays panel's buttons (`identificar / aplicar / revertir /
    mantener`) and its `revertido` status (the word it compares stays
    English, only what is shown changes);
  - the network app's password placeholder and the `pair` note of a new
    Bluetooth device; the monitors' `actual` pill; the humidity and wind
    labels of the weather card;
  - the notices of `scripts/`: the volume notification, the whole update
    flow (`setup-update`), the displays, themes and gtk messages, and the
    complaints of the shortcut and rule generators (`keybinds-gen`,
    `rules-gen`), which the settings editor shows. 47 files now.
- **v7** (2026-11-22): rebuilt on butterdwm `35da28a`:
  - the new texts of that version: the Tailscale device list in the network
    app (`Super+Shift+N`), the themes row of the wallpaper tab, the radar
    card, and the status texts `Today`, `applying…`, `disconnecting…`;
  - `scripts/gtk-theme` (upstream moved the GTK notices there) and the radar
    errors the card shows (`scripts/radar`);
  - the shortcut help (`Super+/`) works: `dwm/keybinds.conf` used to stay in
    English because Gawk in a UTF-8 locale rejected `[\200-\277]`. The
    installer now runs awk with `LC_ALL=C` and its `desc=` regex needs no
    backslashes;
  - a machine with version 6 updates itself: `translated-before.tsv` keeps
    the sha256 of the files this package installed before, so they are
    recognised as ours and re-translated, not kept as another version.
- **v6** (2026-11-11): same payload as v5 (verified byte by byte), but the
  generator was redesigned for any future version: persistent accumulated
  dictionary (`tools/dictionary.tsv`), regex-tolerant anchors in the build, and
  a single orchestrator `regenerate.sh --new <commit>`. The package is now
  self-contained (clone and staging live inside `work/`).
- **v5** (2026-11-10): rebuilt on butterdwm `a511dab`, with the power-menu
  fixes (p/c/r/a keys, "confirmar" hint).
- **v4** (2026-11-07): rebuilt on butterdwm `d63645d`, with a sha256 installer.
  Fixes three v3 problems:
  - 8 translations that broke features: force logout, Wi-Fi signal, CPU and
    disk temperature, notification colors, recording shortcuts, settings apps
    in the launcher and the monitor name;
  - the bug that duplicated `desc=` in `keybinds.conf` and broke the dwm build;
  - the version mixing (it copied the October QML files over newer butterdwm).

  Adds the new upstream bits (rules and keybinding editors, Pomodoro, known
  networks) and the script texts.
- **v3** (2026-11-06): translated QML payload and protection of edited `desc=`.

## Structure

```
install.sh                   one-line installer (downloads the repo and runs the script)
traducir-en-vivo.sh          translate installed files, any version, no replacement
translate-butterbian-es.sh   apply / --check / --restore
manifest.txt                 sha256 of the original and the translated file of each file
shortcuts.tsv                shortcut descriptions: English -> Spanish
payload/suckless/            the 47 translated files
translated-before.tsv        sha256 of the Spanish files earlier versions installed
tools/                       v6 generator (v9 package) + live translator (accumulated dictionary + build + regenerate.sh)
work/                        butterdwm clone and translation staging (created by regenerate.sh)
```

## License

MIT. The files in `payload/` derive from butterdwm by
[JustAGuy Linux](https://justaguy.dev/butter/dwm), with the translation and
fixes of this repo.

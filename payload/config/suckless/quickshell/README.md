# quickshell shell for dwm

The full desktop shell: bar, popups, wallpaper-driven theming, and the
network app. dwm needs the **quickshell-extbar patch**
(`suckless/dwm/patches/dwm-quickshell-extbar.diff`, applied in this tree's
dwm.c) — a hard dependency that provides everything the shell relies on:

- dock windows are adopted unmanaged and their `_NET_WM_STRUT_PARTIAL`
  reserves screen space, re-tiling live when the bar height changes
  (mainline dwm ignores struts and would tile the bar);
- `_DWM_SELTAGS` on the root window carries the raw tagset bitmask
  (faithful for multi-tag views, unlike lossy `_NET_CURRENT_DESKTOP`),
  refreshed on every tag mutation as the bar's change signal;
- root `_NET_CURRENT_DESKTOP` and client `_NET_WM_DESKTOP` ClientMessages
  are handled, so `xdotool set_desktop` / `set_desktop_for_window` work
  for bar clicks.

Occupancy comes from each client's `_NET_CLIENT_INFO` tag bitmask
(ewmhtags patch). Urgency is not exported by dwm — `urgtags` stays 0.
Sticky/all-tag windows light every occupancy dot; that matches dwm
semantics.

Launch: `qs -p ~/.config/suckless/quickshell` (autostart.sh does this), or
`scripts/bar restart|log` which handles the `-p` flag.

## Portability contract (read before porting to another WM)

The **reference implementation** lives in mangobutter (`main`
branch, `config/quickshell/`); this tree follows it, and bspwm-setup and
openbox-setup are the other X11 ports. Cohesion across projects comes
from keeping the shared files byte-identical — `diff` against mango's
tree should show only the files listed as WM-specific.

**Shared verbatim (do not fork per WM):**
`Theme.qml` `BarModule.qml` `Txt.qml` `SectionLabel.qml` `Toggle.qml`
`TogglePill.qml` `QuickTile.qml` `BarIpc.qml` `Batteries.qml`
`Weather.qml` `WeatherPopup.qml` `RadarView.qml` `NotifyPopup.qml`
`Network.qml` `CalendarPopup.qml` `Clock.qml` `Media.qml` `MediaPopup.qml`
`Metrics.qml` `MetricsPopup.qml` `Volume.qml` `VolumePopup.qml` `Tray.qml`
`Bell.qml` `CapsLock.qml` `Screenshot.qml` `PowerButton.qml` `Launcher.qml`
`Title.qml` `TweakSlider.qml` `Tags.qml` `MicMute.qml` — plus
`scripts/wallpaper-theme` (all but its WM tail), `scripts/network`,
`scripts/radar`, `scripts/sysinfo`, `scripts/procs`, `scripts/bar`
(plus the icon-theme handoff), and the `quickshell-network/` app.
(`Tags.qml` and `Title.qml` ask `Wm.of(output)` for their state; dwm's
Wm answers with its one global tagset for every output.)
`WallpaperPicker.qml` is ahead of mango main here (folder row, keyboard
navigation — from mango's dev branch).

**Shared with a dwm edit (diff is small and commented at the top):**
- `Sys.qml` — mango's, plus `composited` (is picom up?) for Popout.
- `Popout.qml` — the X11 edition: a `PopupWindow` catcher (card-only
  without a compositor) instead of mango's layer-shell overlay; same
  `centered`, popup scale and `ipcNames` contract. Opens ask
  `scripts/popup-focus` for the keyboard (below).
- `LauncherPopup.qml` — dwm actions: keybindings → `scripts/help`,
  restart dwm (SIGHUP), screenshots through flameshot, terminals are st;
  no lock, displays, metrics-as-action or Wi-Fi share.
- `PowerPopup.qml` — no Lock row (butterdwm ships no locker).
- `Commands.qml` — keep-awake via `xset`, night light via one-shot
  redshift (tracked locally), no lock tiles or Displays row.
- `Updates.qml` `MetricsPopup.qml` — kitty → st.

**WM-specific (this project's versions):**
- `Wm.qml` — dwm backend: `xprop -spy` on `_DWM_SELTAGS`,
  `_NET_NUMBER_OF_DESKTOPS`, `_NET_CLIENT_LIST`; occupancy from
  `_NET_CLIENT_INFO`; actions via xdotool (handled by the extbar patch).
  Shims for the shared files: `monitor` (empty — the patch doesn't
  publish selmon, so the first output's bar answers IPC), `of()`,
  `tagApps` (empty), `logout()`, `restart()`, `sessionProcs`.
- `Bar.qml` — no padding sync and no place timer: the extbar patch honors
  this window's strut directly. Right-click on empty bar opens the
  layout/tweaks picker.
- `LayoutButton.qml` `LayoutPicker.qml` — dwm-backed versions: the button
  shows the current layout's config.h glyph (scroll cycles, click opens
  the picker); right-click on empty bar opens the same popup, which is
  this port's one tweaks surface (like bspwm's — openbox's separate
  `BarTweaks.qml` has no counterpart here). The picker is a glyph-tile
  grid of all fifteen layouts, applied by writing a layouts[] index to
  `_DWM_SETLAYOUT` (extbar patch §18e), current one read from
  `_DWM_LAYOUT`; a Desktop section (§18f): window gap (persisted to the
  `dwm-gaps` state file, re-applied by autostart.sh), master width and
  master count (pertag — they tweak the focused tag and reset with dwm;
  not persisted; they dim in layouts whose arrange ignores mfact/
  nmaster — flags in Wm.layouts, keep them and the glyph/order table in
  sync with `layouts[]` in dwm's config.def.h); and a Bar section: bar
  height / element scale, persisted to the state files Theme.qml
  watches. bspwm's `LayoutIcon.qml` + `scripts/layout` have no
  counterpart here; border width has no slider (compile-time in dwm).
- Tail of `scripts/wallpaper-theme` — dwm: a marker-bracketed
  Xresources block (dwm + st colors) + `xrdb -load` + dunst respawn +
  `pkill -HUP dwm`. The markers still read `! BEGIN/END dwm-thememenu`
  after the retired theme switcher that once owned them, so upgraded
  installs replace the old block instead of stacking a second one.
- `Follow.qml` — the native bar's `>`/`v` window-follow indicator as a
  clickable module (`_DWM_FOLLOW`/`_DWM_SETFOLLOW`; Mod+n stays in sync).
- `scripts/popup-focus` — dwm hands keyboard focus only to its clients,
  never to the bar's override-redirect popups; Popout runs this on open
  (focus the mapped popup) and `release` on close (back to dwm's active
  client). That's what makes Escape, the launcher's search and the
  weather field work. Wayland ports don't need it.
- `scripts/launcher` `scripts/power` `scripts/help` — open the popups
  over IPC, rofi when the bar is down (as mango's, with `pkill -x dwm`
  for logout).
- `SettingsPopup.qml` — the settings panel: one centered card, tabs
  down the left (Keybinds, Rules, Layout, Bar, Wallpaper, Displays),
  Apply at the foot of the strip. This is where the setup is configured; the
  modules' own popups (state and quick actions) stay as they are.
  `KeybindsPane.qml` and `RulesPane.qml` are the two editors,
  `LayoutTweaks.qml` the Layout tab, `BarTweaks.qml` the Bar tab,
  `WallpaperPane.qml` the wallpaper grid and palette extraction (the old
  picker popup), `DisplaysPane.qml` mango's Displays card as a pane
  (`scripts/displays` speaks wlr-randr's argument style over xrandr, so
  the pane is shared; its scale and VRR rows are dropped on X11);
  `EditField.qml` and `EditButton.qml` are the editors' widgets. IPC: `settings toggle`, `settings open <tab>`; the retired
  popups' names still answer — `keybinds`, `layouts` / `tweaks`,
  `wallpapers` (toggle opens the tab; `random` and `set <path>` apply
  with the panel closed), `displays`.
- `shell.qml` — besides a Bar per screen: applies the kept displays
  layout at start, re-applies it (and the wallpaper, via ~/.fehbg) when
  Quickshell's screens change, and carries the Displays tab's identify
  overlay (a PanelWindow per screen).
- `scripts/keybinds` — `dwm/keybinds.conf` as the Keybinds tab's rows
  (section, keys, label, line, kind; same rows as mango's script prints
  from its config) and the editor's verbs: `get N`, `set N …`,
  `add SECTION …`, `delete N` (each tried through keybinds-gen first;
  refused with the reason if the result wouldn't build), `check`,
  `apply`, `open N`. `scripts/rules` does the same for `dwm/rules.conf`
  (plus `pick`: xprop on a click, for the match fields). The panes are
  shared: another port only needs scripts answering the same verbs.
  Recording a chord writes `_DWM_SETGRAB` 0/1 on the root
  (Wm.setKeyGrab) so dwm releases its key grabs while the chord is
  pressed — that atom is butterdwm's addition to the extbar patch (see
  dwm/modifications.txt).
- `scripts/screenshot` `scripts/screen-off` — flameshot and `xset dpms`
  behind the same names mango's grim/wlopm scripts use.
- `qmldir`, this `README.md`.

**Interfaces that must never drift between projects:**
- `polybar/colors.ini` palette keys (background, background-alt, foreground,
  primary, secondary, alert, disabled, border) — Theme.qml's watch target.
- `wallpaper-theme <image> <8 semantic> <16 ansi>` argument order.
- IPC targets, registered once in `BarIpc.qml` and answered by the
  popup on the focused output: `launcher` `power` `commands` `volume`
  `metrics` `layouts`/`tweaks` (one popup here) `weather` (toggle,
  radar) `wallpapers` (toggle/random/set) `updates` (check) `keybinds`.
  `displays` (toggle) opens the Displays tab.
- Script names in `scripts/`: wallpaper-theme, network, bar, launcher,
  power, screenshot, screen-off, radar, sysinfo, procs.
- State file names in the WM config dir (Theme.qml's watch targets,
  plain values): `bar-height` `bar-scale` `popup-scale` `tag-icons`
  `weather-location` `weather-units` `launcher-history` `pomodoro`;
  dwm adds `dwm-gaps` (consumed by autostart.sh, not Theme.qml).

## Live theming

`Theme.qml` watches `polybar/colors.ini`, which `scripts/wallpaper-theme`
rewrites on every wallpaper pick — the bar re-colors in place, no restart.
The picker extracts the palette in QML (Canvas histogram; fidelity mode for
flat designed art, pastel interpretation for photos). A beacon check runs
first: a small, bright, hue-distinct cluster — a lamp, neon sign, sunset
sliver — becomes the accent even though it barely registers in the
histogram, and the dominant field hue steps down to secondary; images
without one behave exactly as before and the script fans it
out to bar/rofi/dunst/kitty/GTK/dwm borders/st. Dunst's config is symlinked
from `~/.config/dunst/dunstrc` so D-Bus-spawned dunst is themed too.
This is the single theming system on dwm — the wallpaper dictates every
color (the old dwm-thememenu preset switcher was removed).

## Controls

| Module   | Left click        | Right click   | Middle       | Scroll          |
|----------|-------------------|---------------|--------------|-----------------|
| Launcher | app launcher popup | settings: Wallpaper tab | random wallpaper | — |
| Tags     | focus             | —             | send window  | cycle tags      |
| (empty bar) | —              | settings: Layout tab | —     | —               |
| Follow   | toggle window-follow (arrow lit = following) | — | — | —          |
| Media    | play/pause        | now-playing popup | dismiss until it plays again | prev/next track |
| Weather  | forecast card (3 days, location field, °F/°C, radar) | card with the field focused | — | — |
| Volume   | volume popup: output + picker, mic + meter, per-app, pavucontrol | mute | — | ±2% |
| Metrics  | what's using the machine (CPU/RAM/temps/disks/mounts/programs) | btop in kitty | — | — |
| Network  | network app       | nm-connection-editor | —     | —               |
| Tray     | activate          | menu          | secondary    | —               |
| Bell     | (appears only while DND is on — click resumes, right-click history) |||
| Clock    | calendar popup    | —             | —            | —               |
| Updates  | (appears only with pending apt upgrades — click opens upgrade terminal, middle re-checks) |||
| Mic      | (appears only while the mic is muted — click unmutes) |||
| Caps     | (indicator — appears only while caps lock is on) |||
| Screenshot | region (flameshot's editor) | full screen | —  | —               |
| Power    | power menu popup  | —             | —            | —               |
| Commands | command menu popup | —            | —            | —               |

Keybindings (keybinds.conf): `super+space` app launcher · `super+x`
power menu · `super+shift+p` wallpaper picker · `super+shift+n` network
app · `super+shift+m` command menu · `super+shift+l` layout picker.

The command menu (󰘳, right end of the bar) is the quick-settings panel:
actions with **no other bar surface**, in sections. Batteries (anything
UPower knows with one — laptop, mouse, headset — only when there is
one). Quick settings: two-line tiles, name over state (`QuickTile`):
power profile, keep awake, microphone, night light, do not disturb,
Bluetooth (with an adapter), focus timer (− / + set its length; the
countdown shows on the 󰘳 pill itself). Filled = on, red = a state you
shouldn't forget (mic muted, DND); right-click = the fuller tool
(pavucontrol's input tab, notification history, the network app).
Brightness slider on laptops. System rows: notifications, snapshots
(Timeshift, when installed), check updates, keybindings, restart bar,
power menu (`PowerPopup`, also `super+x`). Stateful glanceable modules
(volume, network, DND, media) never move in here. IPC: `commands toggle`.

The app launcher (`super+space`, left-click the swirl) is a centered
grid of every installed app: type to search (name, generic name,
keywords, program), arrows move, Enter launches, Esc clears then
closes; All · Apps · Settings · Actions chips (Ctrl+Tab cycles). The
bar's own tools are searchable as actions (power menu, keybindings,
wallpaper, layout, command menu, weather, network, screen off,
screenshots, updates, restart bar, restart dwm, about). Launch history
(`launcher-history`) only breaks ties between matches. Icons follow the
GTK icon theme (`scripts/bar` hands it to quickshell).

Bar tweaks: right-click an empty stretch of the bar (or click the layout
button) for the picker's Bar section — **bar height** (36–72 px) and
**element scale** (0.7–2.0×) sliders. Element scale resizes
fonts, icons, module pills, tags, and tray (popups stay fixed); height is
a floor, not a cap — the bar grows to fit when scaled elements outgrow it.
Both persist to plain live-watched files — `bar-height` and `bar-scale` in
the suckless dir — so `echo 48 > ~/.config/suckless/bar-height` works
identically. Defaults (42 / 1.0) apply when the files are absent.

Weather config lives under the forecast in the card: a location field
(Enter pins a city/zip/airport, "auto" goes back to by-IP) and °F/°C/auto
pills; right-click the module opens the card with the field focused.
State is two plain live-watched files — `weather-location` and
`weather-units` in the suckless dir — so `echo`/`rm` work identically for
scripts. "radar" swaps the forecast for the last hour of rain on a map
(`RadarView`, tiles via `scripts/radar` into `~/.cache/suckless/radar`).
Location auto-detect follows VPN exit nodes; the card's 󰍎 line shows
which location the data is actually for.

Design grammar: indicators sit flat on the bar or icon-only — no
hover-expanding labels (a module growing on hover shifts the
right-anchored row out from under the cursor); details live in popups
and apps, and Volume's label flashes only on change. Pill backgrounds
mean "clickable". One popup per module — no hub:
three hub concepts (card, side panel, expanding deck) were built and
retired; every control lives in its module's obvious place. Popups
summoned from the keyboard (launcher, power) float centered with a
solid accent border; drop-downs hang under their module. The network
app, which needs a real window (wifi passwords), is a floating window
with its own qs instance. All popups share `Popout.qml` (card chrome +
click-outside/Escape close, keyboard focus via `scripts/popup-focus`) —
never hand-roll popup chrome. Battery joins
the flat metrics on laptops. VPN state (vpn/wireguard/tun) shows as a
green shield on the network module; the network app can toggle saved VPN
profiles (NM-managed vpn/wireguard only — externally managed tunnels
like tailscale show the shield and a read-only "external" row, but no
toggle: nmcli can down them but never bring them back), and carries the bluetooth manager (power, paired-device
connect/disconnect, PIN-less pairing via "pair new"; PIN pairing stays
blueman's job) — the section renders only when an adapter exists.

## Development notes

- New QML type → add to `qmldir` **and** fully restart (`scripts/bar
  restart`). Hot reload registers no new types and can leave stale handler
  trees running — never trust it for behavior changes.
- Debug: `scripts/bar log` · IPC surface: `scripts/bar ipc show`.
- Popups and the keyboard: a popup that doesn't get keys means
  `scripts/popup-focus` didn't find its window — it looks for a mapped
  top-level named `quickshell` without a strut (xdotool's search doesn't
  list Qt's override-redirect windows; xwininfo does).
- A failed config load (a type missing from `qmldir`, say) leaves the
  bar dead for the retry; dwm drops its reserved strip meanwhile and
  only re-reserves it on the next clean `scripts/bar restart`.
- The bar window is adopted unmanaged by the extbar patch: it does not
  appear in `_NET_CLIENT_LIST` (so the occupancy scan never sees it) and
  `scripts/bar place` no-ops, same as under bspwm.

## Fallback

Bar dies the moment you click it: check `~/.icons/default/index.theme`
for a self-referential Inherits loop — nwg-look ≤1.0.2 (what trixie
ships) generates one applying a cursor theme, and libxcb-cursor
recurses forever resolving the click cursor (found by ddubs, Aug 2026;
fixed upstream in nwg-look 1.0.3, issue #90). Delete the file or fix
the chain.

`Mod+Ctrl+b` toggles dwm's native bar back on; uncomment the slstatus line
in `scripts/autostart.sh` for status text (and don't run both bars — their
reservations stack). If quickshell misbehaves: `scripts/bar restart`.

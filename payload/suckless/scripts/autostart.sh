#!/bin/sh

# dwm SIGHUP-restart re-runs this script. Guard each daemon with `pgrep -x`
# so subsequent invocations are no-ops instead of spawning duplicates.

# ─── HiDPI / 4K displays ──────────────────────────────────────────────
# There's no single scaling knob — dwm doesn't scale, so each toolkit has
# to be told separately. If type is tiny on a 4K screen, uncomment this
# whole block and log out / back in.
#
# The values give ~200% (good for a 4K laptop or 27"). For ~150%, use
# Xft.dpi 144, drop GDK_SCALE, and set the cursor sizes to 36. The exports
# reach only what this script starts.
#
# printf 'Xft.dpi: 192\nXcursor.size: 48\n' | xrdb -merge   # X apps, fonts + cursor
# export GDK_SCALE=2          # GTK app widgets (thunar, geany)
# export GDK_DPI_SCALE=0.5    # cancel GTK's double font scaling on top of GDK_SCALE
# export QT_AUTO_SCREEN_SCALE_FACTOR=1   # Qt apps follow Xft.dpi
# export XCURSOR_SIZE=48
# ──────────────────────────────────────────────────────────────────────

pgrep -x lxpolkit  >/dev/null || lxpolkit &
# xsettingsd pushes GTK theme/icon changes to running apps; the theme
# installer (butterscripts) writes ~/.xsettingsd, --only-config has none
[ -f ~/.xsettingsd ] && { pgrep -x xsettingsd >/dev/null || xsettingsd & }

# quickshell bar, through scripts/bar so it gets the GTK icon theme
# (`-n` exits if already running, so the SIGHUP re-run of this script is
# a no-op while the bar is up)
if command -v qs >/dev/null 2>&1; then
	"$HOME/.config/suckless/scripts/bar" start >/dev/null 2>&1 &
fi

# wallpaper: the last pick (wallpaper-theme keeps it in wallpaper-current),
# else the default; feh sets it and exits
wp=$(cat "$HOME/.config/suckless/wallpaper-current" 2>/dev/null)
[ -f "$wp" ] || wp="$HOME/.config/suckless/wallpaper/cozy-window.png"
feh --no-fehbg --bg-fill "$wp" &

pgrep -x dunst >/dev/null || dunst -config ~/.config/suckless/dunst/dunstrc &
pgrep -x picom >/dev/null || picom --config ~/.config/suckless/picom/picom.conf -b &

# hide cursor when idle (mitigates dwm sloppy-focus typing-in-wrong-window)
# optional — install with `apt install unclutter`
if command -v unclutter >/dev/null 2>&1; then
	pgrep -x unclutter >/dev/null || unclutter -idle 1 -root &
fi

# re-apply the picker's saved window gap — every dwm restart resets gaps
# to the compiled default; the delay lets dwm's event loop come up first
if [ -r "$HOME/.config/suckless/dwm-gaps" ]; then
	(sleep 1; xprop -root -f _DWM_SETGAPS 32c \
		-set _DWM_SETGAPS "$(cat "$HOME/.config/suckless/dwm-gaps")") &
fi
# ...and the saved border width, same way
if [ -r "$HOME/.config/suckless/dwm-border" ]; then
	(sleep 1; xprop -root -f _DWM_SETBORDER 32c \
		-set _DWM_SETBORDER "$(cat "$HOME/.config/suckless/dwm-border")") &
fi

# First-login welcome (shown once, dismissable)
if [ ! -f "$HOME/.cache/dwm/welcomed" ]; then
	mkdir -p "$HOME/.cache/dwm"
	touch "$HOME/.cache/dwm/welcomed"
	(sleep 3; notify-send -u normal -t 15000 \
		"Bienvenido a dwm" \
		"Presiona Super + / cuando quieras para ver todos los atajos.&#10;En ~/QUICKSTART-dwm.md hay una guía rápida.") &
fi

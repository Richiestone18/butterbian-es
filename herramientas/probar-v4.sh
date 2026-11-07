#!/usr/bin/env bash
# Pruebas del instalador v4 sobre una copia temporal de butterdwm en ingles (no toca nada real).
# uso: probar-v4.sh <repo butterbian-es> <suckless original en ingles> [<v4 esperada>]
set -u
R=$(cd "$1" && pwd); ORIG=$(cd "$2" && pwd); ESPERADA=${3:-}
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ok=0; mal=0
pasa() { echo "  OK   $*"; ok=$((ok+1)); }
falla() { echo "  MAL  $*"; mal=$((mal+1)); }
nuevo_dest() { rm -rf "$T/suckless" "$T/home"; mkdir -p "$T/home"; cp -r "$ORIG" "$T/suckless"; }
corre() { ( export HOME="$T/home" BUTTERBIAN_ES_DEST="$T/suckless"; unset DISPLAY SSH_CONNECTION SSH_TTY XDG_STATE_HOME; bash "$R/traducir-butterbian-es.sh" "$@" ); }
rutas() { grep -v '^#' "$R/manifiesto.txt" | awk '{print $3}'; }
iguales_a() {   # $1 = arbol de referencia; compara archivos del manifiesto
    local n=0 r; for r in $(rutas); do cmp -s "$1/$r" "$T/suckless/$r" || n=$((n+1)); done; echo $n; }

echo "== 1) copia limpia en ingles: --check =="
nuevo_dest; corre --check | sed 's/^/     /'
corre --check | grep -q 'por traducir: 35 ' && pasa "--check ve 35 archivos por traducir" || falla "--check no ve 35 por traducir"
cmp -s "$ORIG/dwm/keybinds.conf" "$T/suckless/dwm/keybinds.conf" && pasa "--check no escribio nada" || falla "--check modifico keybinds.conf"

echo "== 2) aplicar =="
corre | sed 's/^/     /'
[ -n "$ESPERADA" ] && { d=$(iguales_a "$ESPERADA"); [ "$d" = 0 ] && pasa "los 35 archivos quedan identicos a la v4 esperada" || falla "$d archivo(s) distintos de la v4 esperada"; }
if [ -n "$ESPERADA" ]; then
    if cmp -s "$ESPERADA/dwm/keybinds.conf" "$T/suckless/dwm/keybinds.conf"; then pasa "keybinds.conf identico a la v4 (incluida la alineacion)"
    elif diff <(tr -s ' ' <"$ESPERADA/dwm/keybinds.conf") <(tr -s ' ' <"$T/suckless/dwm/keybinds.conf") >/dev/null; then pasa "keybinds.conf igual a la v4 (solo cambian espacios de alineacion)"
    else falla "keybinds.conf difiere de la v4"; diff "$ESPERADA/dwm/keybinds.conf" "$T/suckless/dwm/keybinds.conf" | head -6; fi
fi
grep -c 'desc=' "$T/suckless/dwm/keybinds.conf" | grep -qx "$(grep -c 'desc=' "$ORIG/dwm/keybinds.conf")" && pasa "no se duplico ningun desc=" || falla "cambio el numero de desc="
grep -qE 'desc="?desc=' "$T/suckless/dwm/keybinds.conf" && falla "bug v3: desc anidado" || pasa "sin el bug de la v3 (desc=\"desc=...\")"
for s in $(rutas | grep '^scripts/'); do [ -x "$T/suckless/$s" ] || falla "$s perdio el permiso de ejecucion"; done; pasa "scripts siguen siendo ejecutables"
ls "$T/home"/butterbian-es-backup-*.tar.gz >/dev/null 2>&1 && pasa "respaldo creado" || falla "sin respaldo"

echo "== 3) aplicar otra vez (idempotente) =="
corre | sed 's/^/     /' | head -3
corre | grep -q 'Nada que traducir' && pasa "segunda vez: nada que traducir" || falla "la segunda vez volvio a escribir"

echo "== 4) --restore =="
corre --restore | sed 's/^/     /' | head -2
d=$(iguales_a "$ORIG"); [ "$d" = 0 ] && cmp -s "$ORIG/dwm/keybinds.conf" "$T/suckless/dwm/keybinds.conf" \
    && pasa "restore deja todo como el original en ingles" || falla "restore: $d archivo(s) distintos del original"

echo "== 5) ediciones del usuario se respetan =="
nuevo_dest
echo "// cambio mio" >> "$T/suckless/quickshell/Clock.qml"
sed -i 's/desc=Browser /desc=Brave /' "$T/suckless/dwm/keybinds.conf"
corre >/dev/null
grep -q 'cambio mio' "$T/suckless/quickshell/Clock.qml" && grep -q 'Qt.formatDateTime' "$T/suckless/quickshell/Clock.qml" \
    && pasa "Clock.qml editado: se dejo intacto" || falla "piso un QML editado"
grep -q 'desc=Brave ' "$T/suckless/dwm/keybinds.conf" && pasa "atajo con texto propio respetado" || falla "piso un desc editado"
corre --check | grep -q 'editados/otra version: 1$' && pasa "--check reporta 1 archivo editado" || falla "--check no reporta el editado"

echo "== 6) otra version de butterdwm (todos distintos) =="
nuevo_dest; for r in $(rutas); do echo "# v-futura" >> "$T/suckless/$r"; done
corre | grep -q 'Nada que traducir\|por traducir: 0' ; d=$(for r in $(rutas); do grep -q 'v-futura' "$T/suckless/$r" || echo x; done | wc -l)
[ "$d" = 0 ] && pasa "otra version: no toco ningun archivo (no mezcla)" || falla "otra version: modifico $d archivo(s)"
echo "== RESULTADO: $ok OK, $mal MAL =="
[ "$mal" = 0 ]

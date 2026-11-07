#!/usr/bin/env bash
# traducir-butterbian-es.sh  (v4)
# --------------------------------------------------------------------------
# Traduccion al espanol (es_MX) de butterdwm: dwm + barra Quickshell de
# JustAGuy Linux, en Debian 13.
#
#   ./traducir-butterbian-es.sh            aplica la traduccion
#   ./traducir-butterbian-es.sh --check    solo revisa, no escribe nada
#   ./traducir-butterbian-es.sh --restore  deshace la ultima aplicacion
#   ./traducir-butterbian-es.sh --help
#
# Seguro por diseno:
#  - Un archivo de la barra o de scripts/ solo se reemplaza si es IDENTICO
#    (sha256) al original en ingles de la version para la que se hizo esta
#    traduccion (manifiesto.txt). Si lo editaste, o tu butterdwm es otra
#    version, se queda como esta y se avisa: nunca mezcla versiones.
#  - Los atajos (dwm/keybinds.conf) se traducen linea por linea: solo los
#    desc= que siguen en el ingles original. Los que editaste se respetan.
#  - Antes de tocar nada guarda un respaldo (~/butterbian-es-backup-*.tar.gz).
#  - Todo vive en ~/.config/suckless: no usa sudo.
# --------------------------------------------------------------------------
# si lo corren con sh (dash), se relanza con bash antes de leer lo demas
[ -z "${BASH_VERSION:-}" ] && exec bash "$0" "$@"
set -u

DEST="${BUTTERBIAN_ES_DEST:-$HOME/.config/suckless}"
HERE=$(cd "$(dirname "$0")" && pwd)
PAYLOAD="$HERE/payload/suckless"
MANIF="$HERE/manifiesto.txt"
ATAJOS="$HERE/atajos.tsv"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"
LAST="$STATE_DIR/traducir-butterbian-es.last"
STAMP=$(date +%Y%m%d-%H%M%S)

say() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

for c in sha256sum tar awk; do command -v "$c" >/dev/null 2>&1 || die "hace falta '$c'"; done
[ -f "$MANIF" ] && [ -f "$ATAJOS" ] && [ -d "$PAYLOAD" ] || die "paquete incompleto: falta manifiesto.txt, atajos.tsv o payload/ junto a este script"

# ----------------------------------------------------------- clasificar archivos
# llena ING (en ingles original: se traducen), ESP (ya traducidos) y DIS (editados u otra version)
ING=(); ESP=(); DIS=()
clasificar() {
    local en es ruta s
    while read -r en es ruta; do
        case "$en" in ''|'#'*) continue ;; esac
        if [ ! -f "$DEST/$ruta" ]; then DIS+=("$ruta (no existe)"); continue; fi
        s=$(sha256sum "$DEST/$ruta" | cut -d' ' -f1)
        if   [ "$s" = "$en" ]; then ING+=("$ruta")
        elif [ "$s" = "$es" ]; then ESP+=("$ruta")
        else DIS+=("$ruta"); fi
    done < "$MANIF"
}

# ----------------------------------------------------------------- atajos (awk)
# modo=contar -> imprime "traducibles ya editados" ; modo=aplicar -> imprime el archivo nuevo
atajos_awk() {
    awk -F'\t' -v modo="$1" '
    FNR == NR { if ($0 !~ /^#/ && NF >= 2) { T[$1] = $2; E[$2] = 1 } ; next }
    {
        linea = $0
        if (linea ~ /^[ \t]*#/ || !match(linea, /desc=("[^"]*"|[^ \t]+)/)) { if (modo == "aplicar") print linea; next }
        ini = RSTART; lar = RLENGTH
        val = substr(linea, ini + 5, lar - 5); txt = val; q = 0
        if (substr(txt, 1, 1) == "\"") { txt = substr(txt, 2, length(txt) - 2); q = 1 }
        if (!(txt in T)) {
            if (txt in E) ya++; else editado++
            if (modo == "aplicar") print linea
            next
        }
        if (T[txt] == txt) { ya++; if (modo == "aplicar") print linea; next }   # igual en ambos idiomas
        trad++
        if (modo != "aplicar") next
        nuevo = T[txt]
        rep = (q || index(nuevo, " ") > 0) ? "desc=\"" nuevo "\"" : "desc=" nuevo
        resto = substr(linea, ini + lar)
        match(resto, /^[ \t]*/); esp = RLENGTH; cola = substr(resto, esp + 1)
        if (cola == "") { print substr(linea, 1, ini - 1) rep; next }
        tmp = rep; mb = gsub(/[\200-\277]/, "", tmp)          # bytes de continuacion UTF-8
        n = (lar + esp) - (length(rep) - mb); if (n < 1) n = 1
        pad = sprintf("%" n "s", "")
        print substr(linea, 1, ini - 1) rep pad cola
    }
    END { if (modo != "aplicar") printf "%d %d %d\n", trad, ya, editado }
    ' "$ATAJOS" "$DEST/dwm/keybinds.conf"
}

# ------------------------------------------------- ¿estamos en la sesion grafica?
en_sesion_grafica() {
    [ -n "${DISPLAY:-}" ] && [ -z "${SSH_CONNECTION:-}" ] && [ -z "${SSH_TTY:-}" ] \
        && pgrep -u "$(id -u)" -x dwm >/dev/null 2>&1
}
aplicar_barra() {
    # la app de red se abre bajo demanda: si estaba abierta, se cierra para que tome el cambio
    command -v qs >/dev/null 2>&1 && qs -p "$DEST/quickshell-network" kill >/dev/null 2>&1
    if en_sesion_grafica && [ -x "$DEST/scripts/bar" ]; then
        "$DEST/scripts/bar" restart >/dev/null 2>&1 </dev/null
        say "Barra reiniciada."
    else
        say "Para ver la barra en espanol pulsa Super+Ctrl+R (o cierra sesion y vuelve a entrar)."
        say "  (desde SSH no la reinicio: quedaria fuera de tu sesion y las apps que abras"
        say "   desde ella, como Synaptic, no podrian pedirte la contrasena)"
    fi
}

resumen_distintos() {
    [ ${#DIS[@]} -eq 0 ] && return
    say ""
    say "AVISO: ${#DIS[@]} archivo(s) NO son el original de la version de este paquete"
    say "($(sed -n '1s/^# //p' "$MANIF")). Los editaste o tu butterdwm es otra version:"
    say "se quedan como estan (en ingles) para no mezclar versiones:"
    local i; for i in "${DIS[@]:0:12}"; do say "   - $i"; done
    [ ${#DIS[@]} -gt 12 ] && say "   ... y $(( ${#DIS[@]} - 12 )) mas"
}

# ------------------------------------------------------------------------- main
case "${1:-}" in
    --help|-h) sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --check|-c) MODO=check ;;
    --restore|-r) MODO=restore ;;
    "") MODO=aplicar ;;
    *) die "opcion desconocida: $1 (usa --help)" ;;
esac

if [ "$MODO" = restore ]; then
    [ -f "$LAST" ] || die "no hay ninguna aplicacion registrada ($LAST)"
    BAK=$(sed -n 1p "$LAST"); [ -f "$BAK" ] || die "no encuentro el respaldo $BAK"
    tar xzf "$BAK" -C "$DEST" || die "no se pudo extraer $BAK"
    say "Restaurado desde $BAK ($(tar tzf "$BAK" | grep -vc '/$') archivos)."
    aplicar_barra
    exit 0
fi

[ -d "$DEST/quickshell" ] || die "no encuentro $DEST/quickshell: instala butterdwm primero"
[ -f "$DEST/dwm/keybinds.conf" ] || die "no encuentro $DEST/dwm/keybinds.conf"
say "butterbian-es v4 — $(sed -n '1s/^# butterbian-es v4 · //p' "$MANIF")"
clasificar
read -r A_TRAD A_YA A_EDIT < <(atajos_awk contar)

if [ "$MODO" = check ]; then
    say "Barra, app de red y scripts:"
    say "   por traducir: ${#ING[@]}   ya en espanol: ${#ESP[@]}   editados/otra version: ${#DIS[@]}"
    say "Atajos (dwm/keybinds.conf):"
    say "   por traducir: $A_TRAD   ya en espanol: $A_YA   con texto tuyo (se respetan): $A_EDIT"
    resumen_distintos
    exit 0
fi

if [ ${#ING[@]} -eq 0 ] && [ "$A_TRAD" -eq 0 ]; then
    say "Nada que traducir: ya esta en espanol (${#ESP[@]} archivos, $A_YA atajos)."
    resumen_distintos
    exit 0
fi

mkdir -p "$STATE_DIR"
BAK="$HOME/butterbian-es-backup-$STAMP.tar.gz"
( cd "$DEST" && tar czf "$BAK" "${ING[@]}" dwm/keybinds.conf ) || die "no se pudo crear el respaldo"
printf '%s\n' "$BAK" > "$LAST"
say "1/3 Respaldo: $BAK"

say "2/3 Barra, app de red y scripts: ${#ING[@]} archivo(s)"
for ruta in "${ING[@]}"; do
    cp "$PAYLOAD/$ruta" "$DEST/$ruta.es-tmp" && chmod --reference="$DEST/$ruta" "$DEST/$ruta.es-tmp" \
        && mv "$DEST/$ruta.es-tmp" "$DEST/$ruta" || die "no pude escribir $DEST/$ruta"
done

say "3/3 Atajos: $A_TRAD descripcion(es)"
if [ "$A_TRAD" -gt 0 ]; then
    atajos_awk aplicar > "$DEST/dwm/keybinds.conf.es-tmp" \
        && chmod --reference="$DEST/dwm/keybinds.conf" "$DEST/dwm/keybinds.conf.es-tmp" \
        && mv "$DEST/dwm/keybinds.conf.es-tmp" "$DEST/dwm/keybinds.conf" || die "no pude escribir keybinds.conf"
fi
[ "$A_EDIT" -gt 0 ] && say "   ($A_EDIT atajo(s) con texto tuyo: se respetaron)"
resumen_distintos

say ""
aplicar_barra
say "La ayuda de atajos (Super+/) ya sale en espanol; no hace falta recompilar dwm."
say ""
say "Deshacer: $0 --restore"
say "   (o:  curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install.sh | bash -s -- --restore)"

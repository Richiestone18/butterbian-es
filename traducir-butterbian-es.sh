#!/bin/sh
# traducir-butterbian-es.sh
# --------------------------------------------------------------------------
# Aplica (y puede deshacer) la traduccion al espanol de Butterbian /
# JustAGuy Linux dwm + Quickshell en Debian 13 / Butterbian.
#
#   ./traducir-butterbian-es.sh            aplica la traduccion
#   ./traducir-butterbian-es.sh --check    solo compara, no escribe nada
#   ./traducir-butterbian-es.sh --restore  deshace el ultimo cambio
#   ./traducir-butterbian-es.sh --help
#
# Copia los archivos ya traducidos de la barra (quickshell/ y
# quickshell-network/) desde el payload del repo, y traduce las descripciones
# de atajos (desc=) de dwm/keybinds.conf una por una, SOLO si coinciden con el
# ingles original — nunca pisa un desc= que hayas editado tu.
# Todo va en ~/.config/suckless (no usa sudo).
# --------------------------------------------------------------------------

set -u

DEST="${HOME}/.config/suckless"
STATE_DIR="${HOME}/.local/state"
LAST="${STATE_DIR}/traducir-butterbian-es.last"
STAMP=$(date +%Y%m%d-%H%M%S)
LOG="${HOME}/traducir-butterbian-es-${STAMP}.log"
REPO_SLUG="${BUTTERBIAN_ES_REPO:-Richiestone18/butterbian-es}"
REPO_BRANCH="${BUTTERBIAN_ES_BRANCH:-main}"

say() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

cleanup() { [ -n "${TMPDIR_DATA:-}" ] && rm -rf "$TMPDIR_DATA"; }
trap cleanup EXIT INT TERM

# ---------------------------------------------------------------- leer datos --
cargar_datos() {
    HERE=$(cd "$(dirname "$0")" && pwd)
    DATA="$HERE/traducir.txt"
    if [ -f "$DATA" ] && [ -s "$DATA" ]; then
        return 0
    fi
    say "Descargando el data file de GitHub ($REPO_SLUG)..."
    command -v curl >/dev/null 2>&1 || die "hace falta curl"
    TMPDIR_DATA=$(mktemp -d) || die "no puedo crear directorio temporal"
    curl -fsSL "https://codeload.github.com/${REPO_SLUG}/tar.gz/refs/heads/${REPO_BRANCH}" \
        | tar xz -C "$TMPDIR_DATA" || die "no pude descargar $REPO_SLUG"
    DIR=$(find "$TMPDIR_DATA" -maxdepth 1 -mindepth 1 -type d | head -1)
    [ -n "$DIR" ] || die "el paquete no trae nada"
    DATA="$DIR/traducir.txt"
    [ -f "$DATA" ] || die "el paquete no trae traducir.txt"
    return 0
}

# ------------------------------------------------------------- reiniciar barra --
reiniciar_barra() {
    [ -z "${DISPLAY:-}" ] && [ -e /tmp/.X11-unix/X0 ] && export DISPLAY=:0
    [ -z "${XAUTHORITY:-}" ] && [ -f "${HOME}/.Xauthority" ] && export XAUTHORITY="${HOME}/.Xauthority"
    export LANG="${LANG:-es_MX.UTF-8}"
    export LANGUAGE="${LANGUAGE:-es_MX:es}"
    export LC_ALL="${LC_ALL:-es_MX.UTF-8}"
    command -v qs >/dev/null 2>&1 && qs -p "$DEST/quickshell-network" kill >/dev/null 2>&1
    if [ -n "${DISPLAY:-}" ] && [ -x "$DEST/scripts/bar" ]; then
        setsid nohup "$DEST/scripts/bar" restart >"$LOG" 2>&1 </dev/null &
        sleep 6
        if pgrep -f "^qs -p $DEST/quickshell" >/dev/null 2>&1; then
            say "     barra reiniciada (log: $LOG)"
        else
            say "     AVISO: la barra no aparece viva; revisa $LOG o cierra sesion y vuelve a entrar"
        fi
    else
        say "     sin DISPLAY: no reinicio la barra (se aplicara al cerrar sesion)"
    fi
}

# ------------------------------------------------------ copiar un arbol fuente --
copiar_arbol() {
    # $1 = directorio origen (payload/.../quickshell), $2 = destino relativo
    _src="$1"; _dstrel="$2"; _dstd="$DEST/$_dstrel"
    [ -d "$_src" ] || return 0
    mkdir -p "$_dstd"
    # copia plana de todo el contenido del origen al destino
    cp -r "$_src/." "$_dstd/" 2>/dev/null || true
    _n=$(find "$_dstd" -type f 2>/dev/null | wc -l)
    say "     $_n archivo(s) en $_dstrel"
}

# ------------------------------------------------------ aplicador de @@K --
# Aplica operaciones @@K (desc= de atajos) sobre dwm/keybinds.conf.
# Nunca sobrescribe un desc= que difiera del ingles original.
aplicar_k() {
    exec 3< "$DATA"
    _i=0; _errs=0; _aplicados=0; _resp=0
    while IFS= read -r _line <&3 || [ -n "$_line" ]; do
        case "$_line" in
            '@@K '*)
                _i=$((_i + 1))
                _rest="${_line#@@K }"
                _mod="${_rest%% *}"; _rest2="${_rest#* }"
                _key="${_rest2%% *}"; _rest3="${_rest2#* }"
                _mod="${_mod#mod=}"; _key="${_key#key=}"
                if [ "${_rest3#\"}" != "$_rest3" ]; then
                    _tmp="${_rest3#\"}"
                    _olddesc="${_tmp%%\"*}"
                    _resto="${_tmp#*\"}"
                    _newdesc="${_resto# }"
                else
                    _olddesc=''
                    _newdesc="$_rest3"
                fi
                _kline=$(grep -nE "^mod=$(printf '%s' "$_mod" | sed 's/[+]/\\+/g')[[:space:]]+key=$(printf '%s' "$_key" | sed 's/[+]/\\+/g')[[:space:]]" "$DEST/dwm/keybinds.conf" | head -1 | cut -d: -f1)
                if [ -z "$_kline" ]; then
                    _errs=$((_errs + 1))
                    say "  AVISO: no se encontro el atajo mod=$_mod key=$_key (op $_i)"
                    continue
                fi
                _linea=$(sed -n "${_kline}p" "$DEST/dwm/keybinds.conf")
                _actual=$(printf '%s' "$_linea" | sed -n 's/.*desc="\([^"]*\)".*/\1/p')
                if [ -z "$_olddesc" ]; then
                    if [ -n "$_actual" ]; then
                        _resp=$((_resp + 1))
                        continue  # el usuario ya le puso desc: no se toca
                    fi
                    _nueva=$(printf '%s' "$_linea" \
                        | sed 's/^\(mod='"$_mod"'[[:space:]]\+key='"$_key"'[[:space:]]\+\)/\1desc="'"$_newdesc"'" /')
                    sed -i "${_kline}s/.*/${_nueva}/" "$DEST/dwm/keybinds.conf"
                    _aplicados=$((_aplicados + 1))
                else
                    if [ "$_actual" != "$_olddesc" ]; then
                        _resp=$((_resp + 1))
                        say "  AVISO: desc actual de $_mod $_key es '$_actual', se esperaba '$_olddesc' — no se toca"
                        continue
                    fi
                    _nueva=$(printf '%s' "$_linea" | sed 's/desc="[^"]*"/desc="'"$_newdesc"'"/')
                    sed -i "${_kline}s/.*/${_nueva}/" "$DEST/dwm/keybinds.conf"
                    _aplicados=$((_aplicados + 1))
                fi
                ;;
        esac
    done 3< "$DATA"
    say "     atajos traducidos: $_aplicados | respetados (ya editados): $_resp | avisos: $_errs"
    exec 3<&-
}

# ---------------------------------------------------------------- check --
hacer_check() {
    cargar_datos
    [ -d "$DEST/quickshell" ] || die "no encuentro $DEST/quickshell"
    say "Data file empaquetado: $(grep -c '^@@K ' "$DATA") operacion(es) de atajos."
    say "Ejecute sin --check para aplicar (o --restore para deshacer)."
    exit 0
}

# ---------------------------------------------------------------- restore --
hacer_restore() {
    [ -f "$LAST" ] || die "no hay cambio registrado en $LAST"
    BAK=$(sed -n 1p "$LAST")
    [ -f "$BAK" ] || die "no encuentro el backup $BAK"
    say "Restaurando $BAK ..."
    tar xzf "$BAK" -C "$DEST" || die "fallo al descomprimir el backup"
    say "Restaurado. Reiniciando la barra."
    reiniciar_barra
    exit 0
}

# ---------------------------------------------------------------- main --
case "${1:-}" in
    --help|-h)
        sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
        exit 0 ;;
    --check|-c) MODO=check ;;
    --restore|-r) MODO=restore ;;
    "") MODO=aplicar ;;
    *) die "opcion desconocida: $1 (usa --help)" ;;
esac

[ "$MODO" = restore ] && hacer_restore
[ "$MODO" = check ] && hacer_check

[ -d "$DEST/quickshell" ] || die "no encuentro la configuracion de la barra en $DEST/quickshell"

cargar_datos

mkdir -p "$STATE_DIR"
BAK="${HOME}/butterbian-es-backup-${STAMP}.tar.gz"
( cd "$DEST" && tar czf "$BAK" quickshell quickshell-network dwm/keybinds.conf ) \
    || die "no se pudo crear el backup"
printf '%s\n' "$BAK" > "$LAST"
say "1/3 Backup: $BAK"

_ver=$(grep '^@@V ' "$DATA" | head -1)
say "     $_ver"

HERE=$(cd "$(dirname "$0")" && pwd)
PAYLOAD="$HERE/payload/config/suckless"

say "2/3 Copiando archivos traducidos de la barra..."
copiar_arbol "$PAYLOAD/quickshell" "quickshell"
copiar_arbol "$PAYLOAD/quickshell-network" "quickshell-network"

say "3/3 Aplicando descripciones de atajos (dwm/keybinds.conf)..."
aplicar_k

say "Reiniciando la barra..."
reiniciar_barra

say ""
say "Listo: barra de quickshell, app de red y atajos de dwm en espanol."
say "Incluye los arreglos de bateria (sin avisos falsos en equipos sin pila)"
say "y el reloj con fecha localizada."
say ""
say "Deshacer:   $0 --restore"
say "Comparar:   $0 --check"

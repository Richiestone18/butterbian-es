#!/bin/sh
# traducir-butterbian-es.sh
# -------------------------------------------------------------------------
# Traduce al espanol la barra de Quickshell (y su app de red) y el panel de
# atajos de dwm en un sistema Butterbian / Debian + dwm + quickshell con la
# configuracion "suckless" de JustAGuy Linux (la misma de la Wyse).
#
#   ./traducir-butterbian-es.sh            aplica la traduccion
#   ./traducir-butterbian-es.sh --check    solo compara, no escribe nada
#   ./traducir-butterbian-es.sh --restore  deshace el ultimo cambio aplicado
#
# Se puede ejecutar desde la copia del repo (usa payload/ de al lado) o solo,
# descargando los archivos traducidos de GitHub. Antes de tocar nada guarda un
# tar.gz en ~/ con la configuracion anterior y al final reinicia la barra.
# -------------------------------------------------------------------------

set -u

# --- de donde salen los archivos traducidos cuando no estan al lado --------
REPO_SLUG="${BUTTERBIAN_ES_REPO:-Richiestone18/butterbian-es}"
REPO_BRANCH="${BUTTERBIAN_ES_BRANCH:-main}"

HERE=$(cd "$(dirname "$0")" && pwd)
DEST="${HOME}/.config/suckless"
STATE_DIR="${HOME}/.local/state"
LAST="$STATE_DIR/traducir-butterbian-es.last"
STAMP=$(date +%Y%m%d-%H%M%S)
LOG="${HOME}/traducir-butterbian-es-${STAMP}.log"
TMPDIR_PAYLOAD=""

say() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

limpiar() { [ -n "$TMPDIR_PAYLOAD" ] && rm -rf "$TMPDIR_PAYLOAD"; }
trap limpiar EXIT INT TERM

# reinicia la barra con el idioma correcto (el reloj depende del locale)
reiniciar_barra() {
    [ -z "${DISPLAY:-}" ] && [ -e /tmp/.X11-unix/X0 ] && export DISPLAY=:0
    [ -z "${XAUTHORITY:-}" ] && [ -f "${HOME}/.Xauthority" ] && export XAUTHORITY="${HOME}/.Xauthority"
    export LANG="${LANG:-es_MX.UTF-8}"
    export LANGUAGE="${LANGUAGE:-es_MX:es}"
    export LC_ALL="${LC_ALL:-es_MX.UTF-8}"

    # la app de red corre como instancia aparte: cerrarla para los textos nuevos
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

case "${1:-}" in
    --help|-h)
        sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
        exit 0 ;;
    --check|-c)   MODO=check ;;
    --restore|-r) MODO=restore ;;
    "")           MODO=aplicar ;;
    *)            die "opcion desconocida: $1 (usa --help)" ;;
esac

[ -d "$DEST/quickshell" ] || die "no encuentro la configuracion de la barra en $DEST/quickshell
  este script es para el setup dwm + quickshell de Butterbian / JustAGuy Linux"

# ---------------------------------------------------------------- restore --
if [ "$MODO" = restore ]; then
    [ -f "$LAST" ] || die "no hay ningun cambio registrado en $LAST"
    BAK=$(sed -n 1p "$LAST")
    [ -f "$BAK" ] || die "no encuentro el backup $BAK"
    say "Restaurando $BAK ..."
    tar xzf "$BAK" -C "$DEST" || die "fallo al descomprimir el backup"
    say "Restaurado. Reiniciando la barra."
    reiniciar_barra
    exit 0
fi

# ------------------------------------------------------------- el payload --
PAYLOAD="$HERE/payload/config/suckless"
if [ ! -d "$PAYLOAD" ]; then
    # ejecutado suelto (por ejemplo con curl): bajar el repo entero
    say "0/4  Descargando los archivos traducidos de GitHub ($REPO_SLUG)..."
    command -v curl >/dev/null 2>&1 || die "hace falta curl"
    TMPDIR_PAYLOAD=$(mktemp -d) || die "no puedo crear un directorio temporal"
    URL="https://codeload.github.com/${REPO_SLUG}/tar.gz/refs/heads/${REPO_BRANCH}"
    curl -fsSL "$URL" | tar xz -C "$TMPDIR_PAYLOAD" \
        || die "no pude descargar $URL (revisa la conexion o el nombre del repo)"
    PAYLOAD=$(find "$TMPDIR_PAYLOAD" -maxdepth 4 -type d -path '*/payload/config/suckless' | head -1)
    [ -n "$PAYLOAD" ] && [ -d "$PAYLOAD/quickshell" ] \
        || die "el paquete descargado no trae payload/config/suckless"
    say "     ok: $(cd "$PAYLOAD" && find . -type f | wc -l) archivos"
fi

ARCHIVOS_QS=$(cd "$PAYLOAD/quickshell" && find . -type f)
ARCHIVOS_NET=$(cd "$PAYLOAD/quickshell-network" && find . -type f)

# ------------------------------------------------------------------ check --
if [ "$MODO" = check ]; then
    say "Comparando $DEST contra la traduccion empaquetada:"
    difs=0
    for f in $ARCHIVOS_QS; do
        cmp -s "$PAYLOAD/quickshell/$f" "$DEST/quickshell/$f" || { say "  distinto: quickshell/$f"; difs=$((difs+1)); }
    done
    for f in $ARCHIVOS_NET; do
        cmp -s "$PAYLOAD/quickshell-network/$f" "$DEST/quickshell-network/$f" || { say "  distinto: quickshell-network/$f"; difs=$((difs+1)); }
    done
    cmp -s "$PAYLOAD/dwm/keybinds.conf" "$DEST/dwm/keybinds.conf" \
        || { say "  distinto: dwm/keybinds.conf"; difs=$((difs+1)); }
    if [ "$difs" -eq 0 ]; then
        say "Todo igual: esta maquina ya esta traducida."
    else
        say "$difs archivo(s) distinto(s). Ejecuta sin --check para aplicarlos."
        say "Ojo: si Butterbian actualizo su config, esto la reemplaza por la version"
        say "     traducida; el backup previo permite volver atras con --restore."
    fi
    exit 0
fi

# ------------------------------------------------------------------ backup --
mkdir -p "$STATE_DIR"
say "1/4  Guardando la configuracion actual..."
BAK="${HOME}/butterbian-es-backup-${STAMP}.tar.gz"
( cd "$DEST" && tar czf "$BAK" quickshell quickshell-network dwm/keybinds.conf ) \
    || die "no se pudo crear el backup"
printf '%s\n' "$BAK" > "$LAST"
say "     $BAK"

# ------------------------------------------------------------------ copiar --
say "2/4  Copiando los archivos traducidos..."
mkdir -p "$DEST/quickshell" "$DEST/quickshell-network" "$DEST/dwm"
n=0
for f in $ARCHIVOS_QS; do
    mkdir -p "$DEST/quickshell/$(dirname "$f")"
    cp -p "$PAYLOAD/quickshell/$f" "$DEST/quickshell/$f" || die "fallo copiando quickshell/$f"
    n=$((n+1))
done
for f in $ARCHIVOS_NET; do
    mkdir -p "$DEST/quickshell-network/$(dirname "$f")"
    cp -p "$PAYLOAD/quickshell-network/$f" "$DEST/quickshell-network/$f" || die "fallo copiando quickshell-network/$f"
    n=$((n+1))
done
cp -p "$PAYLOAD/dwm/keybinds.conf" "$DEST/dwm/keybinds.conf" || die "fallo copiando keybinds.conf"
n=$((n+1))
say "     $n archivos"

# ------------------------------------------------------------------ locale --
say "3/4  Revisando el idioma del sistema..."
if locale -a 2>/dev/null | grep -qi '^es_MX'; then
    say "     locale es_MX disponible"
else
    say "     AVISO: falta el locale es_MX. Generalo con:"
    say "       sudo sed -i 's/^# *es_MX.UTF-8/es_MX.UTF-8/' /etc/locale.gen && sudo locale-gen"
fi
if [ -f "${HOME}/.xsession" ] && ! grep -q 'LANG=es_MX' "${HOME}/.xsession" 2>/dev/null; then
    say "     AVISO: ~/.xsession no exporta LANG=es_MX.UTF-8, asi que la fecha del"
    say "            reloj saldra en ingles. Anade al principio del archivo:"
    say "              export LANG=es_MX.UTF-8 LANGUAGE=es_MX:es LC_ALL=es_MX.UTF-8"
fi

# ---------------------------------------------------------------- reinicio --
say "4/4  Reiniciando la barra..."
reiniciar_barra

say ""
say "Listo: barra de quickshell, app de red y panel de atajos de dwm en espanol."
say "Incluye los arreglos de bateria (sin avisos falsos en equipos sin pila) y el"
say "reloj con fecha localizada."
say ""
say "Deshacer:   $0 --restore"
say "Comparar:   $0 --check"

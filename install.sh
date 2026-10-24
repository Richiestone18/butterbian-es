#!/bin/sh
# install.sh — instalador de una linea para la traduccion de Butterbian + dwm
#
#   curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install.sh -o install.sh
#   chmod +x install.sh
#   ./install.sh              # aplica la traduccion
#   ./install.sh --check      # solo compara
#   ./install.sh --restore    # deshace el ultimo cambio
#
# Descarga el repo en un directorio temporal y ejecuta traducir-butterbian-es.sh.
# -----------------------------------------------------------------------------
set -eu

REPO="${BUTTERBIAN_ES_REPO:-Richiestone18/butterbian-es}"
BRANCH="${BUTTERBIAN_ES_BRANCH:-main}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

printf 'Descargando %s (%s)...\n' "$REPO" "$BRANCH"
curl -fsSL "https://codeload.github.com/${REPO}/tar.gz/refs/heads/${BRANCH}" \
    | tar xz -C "$TMP"
DIR=$(find "$TMP" -maxdepth 1 -mindepth 1 -type d | head -1)
[ -n "$DIR" ] && [ -f "$DIR/traducir-butterbian-es.sh" ] \
    || { echo "ERROR: el paquete descargado no trae traducir-butterbian-es.sh" >&2; exit 1; }

# el script ve payload/ junto a el, asi que trabaja sin volver a descargar nada
exec sh "$DIR/traducir-butterbian-es.sh" "$@"

#!/bin/sh
# install.sh — instalador de una linea para la traduccion de butterdwm (dwm + Quickshell)
#
#   curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install.sh | bash -s -- --check
#   curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install.sh | bash -s -- --restore
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
    | tar xz -C "$TMP" || { echo "ERROR: no pude descargar $REPO (revisa la conexión o el nombre del repo)" >&2; exit 1; }

DIR=$(find "$TMP" -maxdepth 1 -mindepth 1 -type d | head -1)
[ -n "$DIR" ] && [ -f "$DIR/traducir-butterbian-es.sh" ] \
    || { echo "ERROR: el paquete descargado no trae traducir-butterbian-es.sh" >&2; exit 1; }

# el script trae junto a el manifiesto.txt, atajos.tsv y payload/: no descarga nada mas
exec bash "$DIR/traducir-butterbian-es.sh" "$@"

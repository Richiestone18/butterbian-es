#!/bin/sh
# install.sh — one-line installer for the butterdwm translation (dwm + Quickshell)
#
#   curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install.sh | bash -s -- --check
#   curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install.sh | bash -s -- --restore
#
# Downloads the repo into a temporary directory and runs translate-butterbian-es.sh.
# -----------------------------------------------------------------------------
set -eu

REPO="${BUTTERBIAN_ES_REPO:-Richiestone18/butterbian-es}"
BRANCH="${BUTTERBIAN_ES_BRANCH:-main}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

printf 'Downloading %s (%s)...\n' "$REPO" "$BRANCH"
curl -fsSL "https://codeload.github.com/${REPO}/tar.gz/refs/heads/${BRANCH}" \
    | tar xz -C "$TMP" || { echo "ERROR: could not download $REPO (check the connection or the repo name)" >&2; exit 1; }

DIR=$(find "$TMP" -maxdepth 1 -mindepth 1 -type d | head -1)
[ -n "$DIR" ] && [ -f "$DIR/translate-butterbian-es.sh" ] \
    || { echo "ERROR: the downloaded package has no translate-butterbian-es.sh" >&2; exit 1; }

# the script carries manifest.txt, shortcuts.tsv and payload/ next to it: nothing else is downloaded
exec bash "$DIR/translate-butterbian-es.sh" "$@"

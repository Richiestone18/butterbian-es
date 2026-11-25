#!/bin/sh
# install-live.sh — one-line installer for the live translator (any butterdwm version)
#
#   curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install-live.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install-live.sh | bash -s -- --check
#   curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install-live.sh | bash -s -- --verbose
#   curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install-live.sh | bash -s -- --restore
#   curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install-live.sh | bash -s -- --add quickshell/Clock.qml "New text" "Texto nuevo"
#
# Downloads the repo into a temporary directory and runs traducir-en-vivo.sh
# with its dictionary and rules next to it. Nothing is copied over the install.
# -----------------------------------------------------------------------------
set -eu

REPO="${BUTTERBIAN_ES_REPO:-Richiestone18/butterbian-es}"
BRANCH="${BUTTERBIAN_ES_BRANCH:-main}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

printf 'Downloading %s (%s)...\n' "$REPO" "$BRANCH"
curl -fsSL "https://codeload.github.com/${REPO}/tar.gz/refs/heads/${BRANCH}" \
    | tar xz -C "$TMP" || { echo "ERROR: could not download $REPO" >&2; exit 1; }

DIR=$(find "$TMP" -maxdepth 1 -mindepth 1 -type d | head -1)
[ -n "$DIR" ] && [ -f "$DIR/traducir-en-vivo.sh" ] \
    || { echo "ERROR: the downloaded package has no traducir-en-vivo.sh" >&2; exit 1; }

exec bash "$DIR/traducir-en-vivo.sh" "$@"

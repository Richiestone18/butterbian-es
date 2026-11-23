#!/usr/bin/env bash
# regenerate.sh — regenerate the v6 translation for a newer butterdwm.
#
# usage:
#   regenerate.sh --new <commit>            [--base <commit>] [--repo <url|path>]
#               [--package]                 [--no-tests]
#
#   --new         commit (or tag/branch) of butterdwm to translate (required)
#   --base        commit of the package's PREVIOUS version; if omitted it is
#                 read from the current manifest.txt (the commit already translated)
#   --repo        url to clone, or path of an existing local clone
#                 (default: https://codeberg.org/justaguylinux/butterdwm.git)
#   --package     also regenerate payload/, manifest.txt and shortcuts.tsv
#   --no-tests    do not run test-v6.sh at the end (it runs by default)
#
# Output: work/v6/suckless (the new translation). The accumulated dictionary
# is kept in tools/dictionary.tsv and grows on every regeneration.
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
cd "$HERE" || exit 1

NEW=""; BASE=""; REPO="https://codeberg.org/justaguylinux/butterdwm.git"
PACKAGE=0; TESTS=1
while [ $# -gt 0 ]; do
    case "$1" in
        --new) NEW="$2"; shift 2 ;;
        --base) BASE="$2"; shift 2 ;;
        --repo) REPO="$2"; shift 2 ;;
        --package) PACKAGE=1; shift ;;
        --no-tests) TESTS=0; shift ;;
        *) echo "unknown option: $1" >&2; exit 1 ;;
    esac
done
[ -n "$NEW" ] || { echo "missing --new <commit>" >&2; exit 1; }

# --- default base: the commit already translated (current manifest)
if [ -z "$BASE" ]; then
    BASE=$(sed -n '1s/.*butterdwm \([0-9a-f]*\).*/\1/p' manifest.txt)
    [ -n "$BASE" ] || { echo "could not read the base commit from manifest.txt; use --base" >&2; exit 1; }
fi

# --- work clone (created on first run)
CLON="work/butterdwm-full"
if [ ! -d "$CLON/.git" ]; then
    echo "== cloning $REPO =="
    git clone "$REPO" "$CLON" || exit 1
else
    echo "== updating $CLON =="
    git -C "$CLON" fetch --all --tags --quiet || { echo "fetch failed (check the network)"; }
fi
if ! git -C "$CLON" rev-parse --verify --quiet "$NEW^{commit}" >/dev/null; then
    echo "commit $NEW does not exist in the clone; fetch tags/branches with: git -C $CLON fetch" >&2
    exit 1
fi
git -C "$CLON" checkout --quiet --detach "$NEW" || exit 1
echo "== upstream at $(git -C "$CLON" rev-parse --short HEAD) =="

# --- generation chain
A="--repo $CLON --out work/v6/suckless"
echo "== 1/4 dictionary (accumulated) =="
python3 tools/dict_v6.py $A --base "$BASE" || exit 1
echo "== 2/4 build (revert + translations + patches + validation) =="
python3 tools/build_v6.py $A || exit 1
echo "== 3/4 shortcuts =="
python3 tools/keybinds_v6.py $A || exit 1
echo "== 4/4 scripts =="
python3 tools/scripts_v6.py $A || exit 1

# --- package
if [ "$PACKAGE" = 1 ]; then
    echo "== packaging =="
    python3 tools/package_v6.py --repo "$CLON" --out work/v6/suckless || exit 1
    echo "payload, manifest.txt and shortcuts.tsv regenerated."
fi

echo "== output: work/v6/suckless =="
if [ "$TESTS" = 1 ]; then
    echo "== test-v6.sh (no real machine: 6 tests) =="
    bash tools/test-v6.sh "$HERE" "$CLON/suckless" || echo "  (tests: failed or no expected tree)"
fi
echo "== done =="

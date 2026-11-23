#!/usr/bin/env bash
# v6 installer tests on a temporary English butterdwm copy (touches nothing real).
# usage: test-v6.sh <butterbian-es repo> <English suckless> [<expected v6>]
set -u
R=$(cd "$1" && pwd); ORIG=$(cd "$2" && pwd); EXPECTED=${3:-}
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ok=0; bad=0
pass() { echo "  OK   $*"; ok=$((ok+1)); }
fail() { echo "  BAD  $*"; bad=$((bad+1)); }
new_dest() { rm -rf "$T/suckless" "$T/home"; mkdir -p "$T/home"; cp -r "$ORIG" "$T/suckless"; }
run() { ( export HOME="$T/home" BUTTERBIAN_ES_DEST="${DEST:-$T/suckless}"; unset DISPLAY SSH_CONNECTION SSH_TTY XDG_STATE_HOME; bash "$R/translate-butterbian-es.sh" "$@" ); }
paths() { grep -v '^#' "$R/manifest.txt" | awk '{print $3}'; }
same_as() {   # $1 = reference tree; compares manifest files
    local n=0 r; for r in $(paths); do cmp -s "$1/$r" "${DEST:-$T/suckless}/$r" || n=$((n+1)); done; echo $n; }

echo "== 1) clean English copy: --check =="
new_dest; run --check | sed 's/^/     /'
N=$(paths | wc -l)
run --check | grep -q "to translate: $N " && pass "--check sees $N files to translate" || fail "--check does not see all $N to translate"
cmp -s "$ORIG/dwm/keybinds.conf" "$T/suckless/dwm/keybinds.conf" && pass "--check wrote nothing" || fail "--check modified keybinds.conf"

echo "== 2) apply =="
run | sed 's/^/     /'
[ -n "$EXPECTED" ] && { d=$(same_as "$EXPECTED"); [ "$d" = 0 ] && pass "the 35 files end up identical to the expected v6" || fail "$d file(s) differ from the expected v6"; }
if [ -n "$EXPECTED" ]; then
    if cmp -s "$EXPECTED/dwm/keybinds.conf" "$T/suckless/dwm/keybinds.conf"; then pass "keybinds.conf identical to v6 (alignment included)"
    elif diff <(tr -s ' ' <"$EXPECTED/dwm/keybinds.conf") <(tr -s ' ' <"$T/suckless/dwm/keybinds.conf") >/dev/null; then pass "keybinds.conf equal to v6 (only alignment spaces differ)"
    else fail "keybinds.conf differs from v6"; diff "$EXPECTED/dwm/keybinds.conf" "$T/suckless/dwm/keybinds.conf" | head -6; fi
fi
grep -c 'desc=' "$T/suckless/dwm/keybinds.conf" | grep -qx "$(grep -c 'desc=' "$ORIG/dwm/keybinds.conf")" && pass "no desc= was duplicated" || fail "the number of desc= changed"
grep -qE 'desc="?desc=' "$T/suckless/dwm/keybinds.conf" && fail "v3 bug: nested desc" || pass "no v3 bug (desc=\"desc=...\")"
for s in $(paths | grep '^scripts/'); do [ -x "$T/suckless/$s" ] || fail "$s lost its execute permission"; done; pass "scripts are still executable"
ls "$T/home"/butterbian-es-backup-*.tar.gz >/dev/null 2>&1 && pass "backup created" || fail "no backup"

echo "== 3) apply again (idempotent) =="
run | sed 's/^/     /' | head -3
run | grep -q 'Nothing to translate' && pass "second run: nothing to translate" || fail "the second run wrote again"

echo "== 4) --restore =="
run --restore | sed 's/^/     /' | head -2
d=$(same_as "$ORIG"); [ "$d" = 0 ] && cmp -s "$ORIG/dwm/keybinds.conf" "$T/suckless/dwm/keybinds.conf" \
    && pass "restore leaves everything as the English original" || fail "restore: $d file(s) differ from the original"

echo "== 5) user edits are respected =="
new_dest
echo "// my change" >> "$T/suckless/quickshell/Clock.qml"
sed -i 's/desc=Browser /desc=Brave /' "$T/suckless/dwm/keybinds.conf"
run >/dev/null
grep -q 'my change' "$T/suckless/quickshell/Clock.qml" && grep -q 'Qt.formatDateTime' "$T/suckless/quickshell/Clock.qml" \
    && pass "edited Clock.qml: left intact" || fail "overwrote an edited QML"
grep -q 'desc=Brave ' "$T/suckless/dwm/keybinds.conf" && pass "shortcut with own text respected" || fail "overwrote an edited desc"
run --check | grep -q 'edited/other version: 1$' && pass "--check reports 1 edited file" || fail "--check does not report the edited one"

echo "== 6) another butterdwm version (all different) =="
new_dest; for r in $(paths); do echo "# v-future" >> "$T/suckless/$r"; done
run | grep -q 'Nothing to translate\|to translate: 0' ; d=$(for r in $(paths); do grep -q 'v-future' "$T/suckless/$r" || echo x; done | wc -l)
[ "$d" = 0 ] && pass "another version: touched no file (no mixing)" || fail "another version: modified $d file(s)"
echo "== RESULT: $ok OK, $bad BAD =="
[ "$bad" = 0 ]

# == 7) mixed machine (previous translation + newer upstream files) ==
# Uses the real machine as MIX. If it is already 100% v6 (N_ING=0), a mix is
# fabricated: shell.qml and 5 quickshell/ files are reverted to English from
# ORIG, so the migration flow is always exercised. restore must return the mix
# as it started (copied to T/mix0 before touching anything).
if [ -n "${MIX:-}" ] && [ -d "$MIX" ] && [ -n "${EXPECTED_V6:-}" ]; then
    echo "== 7) mixed machine (previous translation + newer upstream) =="
    rm -rf "$T/mix" "$T/home"; mkdir -p "$T/home"; cp -r "$MIX" "$T/mix"
    export DEST="$T/mix"
    N_ING=$(run --check | sed -n 's/.*to translate: \([0-9]*\) .*/\1/p' | head -1)
    echo "  (real mixed machine: $N_ING file(s) in English to translate)"
    if [ "${N_ING:-0}" -eq 0 ]; then
        echo "  fabricating mix: shell.qml and 5 of quickshell/ reverted to English"
        cp "$ORIG/quickshell-network/shell.qml" "$T/mix/quickshell-network/shell.qml"
        i=1
        for r in $(paths | grep -E '^quickshell/' | head -5); do
            cp "$ORIG/$r" "$T/mix/$r"; i=$((i+1))
        done
        N_ING=$i
    fi
    cp -r "$T/mix" "$T/mix0"
    [ "${N_ING:-0}" -gt 0 ] && pass "--check sees $N_ING to translate" || fail "--check sees no files to translate in the mix"
    sha_antes=$(cd "$T/mix" && find . -type f | sort | xargs sha256sum | sha256sum | cut -d' ' -f1)
    run --check >/dev/null
    sha_despues=$(cd "$T/mix" && find . -type f | sort | xargs sha256sum | sha256sum | cut -d' ' -f1)
    [ "$sha_antes" = "$sha_despues" ] && pass "--check wrote nothing (mismo sha256 del arbol)" || fail "--check translated something"
    run | sed 's/^/     /'
    d=$(same_as "$EXPECTED_V6"); [ "$d" = 0 ] && pass "apply leaves the 35 identical to v6" || fail "$d file(s) differ from v6"
    grep -q '"nada pendiente"' "$T/mix/quickshell/NotifyPopup.qml" && pass "new NotifyPopup translated" || fail "NotifyPopup stayed in English"
    grep -q '"Tormenta eléctrica"' "$T/mix/quickshell/WeatherData.qml" && pass "weather conditions translated" || fail "conditions untranslated"
    grep -q 'title: "Network"' "$T/mix/quickshell-network/shell.qml" && pass "Network title intact (rules.conf uses it)" || fail "a data title was translated"
    cmp -s "$EXPECTED_V6/quickshell-network/shell.qml" "$T/mix/quickshell-network/shell.qml" && pass "shell.qml matches the expected v6 (geometry and texts)" || fail "shell.qml differs from the expected v6"
    cmp -s "$MIX/quickshell/PopupHeader.qml" "$T/mix/quickshell/PopupHeader.qml" && pass "PopupHeader without text: intact" || fail "PopupHeader changed"
    run | grep -q 'Nothing to translate' && pass "second run: nothing to translate" || fail "the second run wrote again"
    run --restore >/dev/null 2>&1 || true
    d=$(same_as "$T/mix0"); [ "$d" = 0 ] && pass "restore returns the initial mix" || fail "restore: $d file(s) differ from the initial mix"
    echo "== RESULT: $ok OK, $bad BAD =="
    [ "$bad" = 0 ]
fi

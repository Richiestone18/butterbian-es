#!/usr/bin/env bash
# translate-butterbian-es.sh  (v9)
# --------------------------------------------------------------------------
# Spanish (es_MX) translation of butterdwm: dwm + the Quickshell bar by
# JustAGuy Linux, on Debian 13.
#
#   ./translate-butterbian-es.sh            apply the translation
#   ./translate-butterbian-es.sh --check    only check, write nothing
#   ./translate-butterbian-es.sh --restore  undo the last application
#   ./translate-butterbian-es.sh --help
#
# Safe by design:
#  - A bar or scripts/ file is only replaced if it is IDENTICAL (sha256) to
#    the original English file of the version this translation was made for
#    (manifest.txt). If you edited it, or your butterdwm is another version,
#    it stays as is and you are told: versions are never mixed.
#  - Shortcuts (dwm/keybinds.conf) are translated line by line: only the
#    desc= that still match the English original. The ones you edited are kept.
#  - Before touching anything it saves a backup (~/butterbian-es-backup-*.tar.gz).
#  - Everything lives in ~/.config/suckless: no sudo needed.
# --------------------------------------------------------------------------
# if run with sh (dash), relaunch with bash before reading anything else
[ -z "${BASH_VERSION:-}" ] && exec bash "$0" "$@"
set -u

DEST="${BUTTERBIAN_ES_DEST:-$HOME/.config/suckless}"
HERE=$(cd "$(dirname "$0")" && pwd)
PAYLOAD="$HERE/payload/suckless"
MANIF="$HERE/manifest.txt"
PREV="$HERE/translated-before.tsv"	# versiones nuestras anteriores
SHORTCUTS="$HERE/shortcuts.tsv"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"
LAST="$STATE_DIR/traducir-butterbian-es.last"
STAMP=$(date +%Y%m%d-%H%M%S)

say() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

for c in sha256sum tar awk; do command -v "$c" >/dev/null 2>&1 || die "missing '$c'"; done
[ -f "$MANIF" ] && [ -f "$SHORTCUTS" ] && [ -d "$PAYLOAD" ] || die "incomplete package: missing manifest.txt, shortcuts.tsv or payload/ next to this script"

# ----------------------------------------------------------- classify files
# fills ING (English original: to be translated), ESP (already translated) and DIS (edited or another version)
ING=(); ESP=(); DIS=(); ANT=()
classify() {
    local en es rel s
    while read -r en es rel; do
        case "$en" in ''|'#'*) continue ;; esac
        if [ ! -f "$DEST/$rel" ]; then DIS+=("$rel (missing)"); continue; fi
        s=$(sha256sum "$DEST/$rel" | cut -d' ' -f1)
        if   [ "$s" = "$en" ]; then ING+=("$rel")
        elif [ "$s" = "$es" ]; then ESP+=("$rel")
        # una traduccion NUESTRA anterior: se actualiza, no es una edicion tuya
        elif [ -f "$PREV" ] && awk -v h="$s" -v r="$rel" '$1 == h && $2 == r { e = 1 } END { exit !e }' "$PREV"
        then ANT+=("$rel"); ING+=("$rel")
        else DIS+=("$rel"); fi
    done < "$MANIF"
}

# ----------------------------------------------------------------- shortcuts (awk)
# mode=count -> prints "translatable already edited" ; mode=apply -> prints the new file
shortcuts_awk() {
    # LC_ALL=C: en un locale UTF-8 gawk rechaza /[\200-\277]/ y el
    # relleno de la columna cuenta BYTES, no caracteres
    LC_ALL=C awk -F'\t' -v mode="$1" '
    FNR == NR { if ($0 !~ /^#/ && NF >= 2) { T[$1] = $2; E[$2] = 1 } ; next }
    {
        line = $0
        if (line ~ /^[ \t]*#/ || !match(line, /desc=("[^"]*"|[^ \t]+)/)) { if (mode == "apply") print line; next }
        ini = RSTART; lar = RLENGTH
        val = substr(line, ini + 5, lar - 5); txt = val; q = 0
        if (substr(txt, 1, 1) == "\"") { txt = substr(txt, 2, length(txt) - 2); q = 1 }
        if (!(txt in T)) {
            if (txt in E) already++; else edited++
            if (mode == "apply") print line
            next
        }
        if (T[txt] == txt) { already++; if (mode == "apply") print line; next }   # same in both languages
        translated++
        if (mode != "apply") next
        nuevo = T[txt]
        rep = (q || index(nuevo, " ") > 0) ? "desc=\"" nuevo "\"" : "desc=" nuevo
        resto = substr(line, ini + lar)
        match(resto, /^[ \t]*/); sp = RLENGTH; tail = substr(resto, sp + 1)
        if (tail == "") { print substr(line, 1, ini - 1) rep; next }
        tmp = rep; mb = gsub(/[\200-\277]/, "", tmp)          # UTF-8 continuation bytes
        n = (lar + sp) - (length(rep) - mb); if (n < 1) n = 1
        pad = sprintf("%" n "s", "")
        print substr(line, 1, ini - 1) rep pad tail
    }
    END { if (mode != "apply") printf "%d %d %d\n", translated, already, edited }
    ' "$SHORTCUTS" "$DEST/dwm/keybinds.conf"
}

# ------------------------------------------------- are we in the graphical session?
in_graphical_session() {
    [ -n "${DISPLAY:-}" ] && [ -z "${SSH_CONNECTION:-}" ] && [ -z "${SSH_TTY:-}" ] \
        && pgrep -u "$(id -u)" -x dwm >/dev/null 2>&1
}
restart_bar() {
    # the network app opens on demand: if it was open, close it so it picks up the change
    command -v qs >/dev/null 2>&1 && qs -p "$DEST/quickshell-network" kill >/dev/null 2>&1
    if in_graphical_session && [ -x "$DEST/scripts/bar" ]; then
        "$DEST/scripts/bar" restart >/dev/null 2>&1 </dev/null
        say "Bar restarted."
    else
        say "To see the bar in Spanish press Super+Ctrl+R (or log out and back in)."
        say "  (from SSH I do not restart it: it would end up outside your session and the"
        say "   apps you open from it, like Synaptic, could not ask for your password)"
    fi
}

summary_distinct() {
    [ ${#DIS[@]} -eq 0 ] && return
    say ""
    say "WARNING: ${#DIS[@]} file(s) are NOT the original of this package's version"
    say "($(sed -n '1s/^# //p' "$MANIF")). You edited them or your butterdwm is another version:"
    say "they stay as they are (in English) to avoid mixing versions:"
    local i; for i in "${DIS[@]:0:12}"; do say "   - $i"; done
    [ ${#DIS[@]} -gt 12 ] && say "   ... and $(( ${#DIS[@]} - 12 )) more"
}

# ------------------------------------------------------------------------- main
case "${1:-}" in
    --help|-h) sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --check|-c) MODE=check ;;
    --restore|-r) MODE=restore ;;
    "") MODE=apply ;;
    *) die "unknown option: $1 (use --help)" ;;
esac

if [ "$MODE" = restore ]; then
    [ -f "$LAST" ] || die "no application registered ($LAST)"
    BAK=$(sed -n 1p "$LAST"); [ -f "$BAK" ] || die "backup not found: $BAK"
    tar xzf "$BAK" -C "$DEST" || die "could not extract $BAK"
    say "Restored from $BAK ($(tar tzf "$BAK" | grep -vc '/$') files)."
    restart_bar
    exit 0
fi

[ -d "$DEST/quickshell" ] || die "cannot find $DEST/quickshell: install butterdwm first"
[ -f "$DEST/dwm/keybinds.conf" ] || die "cannot find $DEST/dwm/keybinds.conf"
say "$(sed -n '1s/^# //p' "$MANIF" | sed 's/ · / — /')"
classify
read -r A_TRAD A_YA A_EDIT < <(shortcuts_awk count)

if [ "$MODE" = check ]; then
    say "Bar, network app and scripts:"
    say "   to translate: ${#ING[@]}   already in Spanish: ${#ESP[@]}   edited/other version: ${#DIS[@]}"
    [ ${#ANT[@]} -gt 0 ] && say "   (${#ANT[@]} of them come from an earlier translation of this package: they get updated)"
    say "Shortcuts (dwm/keybinds.conf):"
    say "   to translate: $A_TRAD   already in Spanish: $A_YA   with your own text (kept): $A_EDIT"
    summary_distinct
    exit 0
fi

if [ ${#ING[@]} -eq 0 ] && [ "$A_TRAD" -eq 0 ]; then
    say "Nothing to translate: already in Spanish (${#ESP[@]} files, $A_YA shortcuts)."
    summary_distinct
    exit 0
fi

mkdir -p "$STATE_DIR"
BAK="$HOME/butterbian-es-backup-$STAMP.tar.gz"
( cd "$DEST" && tar czf "$BAK" "${ING[@]}" dwm/keybinds.conf ) || die "could not create the backup"
printf '%s\n' "$BAK" > "$LAST"
say "1/3 Backup: $BAK"

say "2/3 Bar, network app and scripts: ${#ING[@]} file(s)"
[ ${#ANT[@]} -gt 0 ] && say "   (${#ANT[@]} of them from an earlier translation)"
for rel in "${ING[@]}"; do
    cp "$PAYLOAD/$rel" "$DEST/$rel.es-tmp" && chmod --reference="$DEST/$rel" "$DEST/$rel.es-tmp" \
        && mv "$DEST/$rel.es-tmp" "$DEST/$rel" || die "could not write $DEST/$rel"
done

say "3/3 Shortcuts: $A_TRAD description(s)"
if [ "$A_TRAD" -gt 0 ]; then
    shortcuts_awk apply > "$DEST/dwm/keybinds.conf.es-tmp" \
        && chmod --reference="$DEST/dwm/keybinds.conf" "$DEST/dwm/keybinds.conf.es-tmp" \
        && mv "$DEST/dwm/keybinds.conf.es-tmp" "$DEST/dwm/keybinds.conf" || die "could not write keybinds.conf"
fi
[ "$A_EDIT" -gt 0 ] && say "   ($A_EDIT shortcut(s) with your own text: kept)"
summary_distinct

say ""
restart_bar
say "The shortcut help (Super+/) now shows in Spanish; no need to recompile dwm."
say ""
say "Undo: $0 --restore"
say "   (or:  curl -fsSL https://raw.githubusercontent.com/Richiestone18/butterbian-es/main/install.sh | bash -s -- --restore)"

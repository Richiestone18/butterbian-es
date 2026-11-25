#!/usr/bin/env python3
"""Traductor en vivo para butterdwm: traduce textos sin reemplazar archivos.

No usa manifest.txt ni payload/: trabaja sobre los archivos ya instalados y
sustituye unicamente cadenas de texto conocidas por su diccionario acumulado.
Cualquier edition del usuario (texto que no este en el diccionario) se conserva.

Uso:
  traducir_en_vivo.py [--dest DIR] [--pkg DIR] [--check] [--restore] [--verbose]
"""
import argparse
import csv
import os
import re
import stat
import subprocess
import sys
import tarfile
import time

STR = re.compile(r'"(?:[^"\\]|\\.)*"')
LET = re.compile(r"[A-Za-zÁÉÍÓÚáéíóúÑñ]{2}")
DATA = re.compile(r"^[\w./:%@-]+$")
DESC = re.compile(r'desc=("[^"]*"|[^\t ]+)')


def norm(line):
    """Normaliza una linea: cada cadena literal pasa a ser "S"."""
    return STR.sub('"S"', line).strip()


def read_tsv(path, ncol, skip_comment="#"):
    rows = []
    if not os.path.exists(path):
        return rows
    with open(path, encoding="utf-8") as f:
        for raw in f:
            line = raw.rstrip("\n")
            if not line or line.startswith(skip_comment):
                continue
            parts = line.split("\t")
            if len(parts) == ncol:
                rows.append(parts)
    return rows


def load_rules(pkg):
    dic = {}
    for arch, en, es, ctx in read_tsv(os.path.join(pkg, "tools/dictionary.tsv"), 4):
        dic[(arch, en, ctx)] = es

    extra = {}
    for arch, ancla, en, es in read_tsv(os.path.join(pkg, "tools/rules_extra.tsv"), 4):
        extra.setdefault(arch, []).append((re.compile(ancla), re.compile(en), es))

    revert = {}
    for arch, pat in read_tsv(os.path.join(pkg, "tools/revert.tsv"), 2):
        revert.setdefault(arch, []).append(re.compile(pat))

    short = {}
    for row in read_tsv(os.path.join(pkg, "shortcuts.tsv"), 2):
        short[row[0]] = row[1]

    ignore = set()
    for row in read_tsv(os.path.join(pkg, "tools/ignore.tsv"), 1):
        ignore.add(row[0])

    known_es = set()
    for (arch, en, ctx), es in dic.items():
        known_es.add(es.strip('"'))
    for rules in extra.values():
        for _, _, es in rules:
            known_es.add(es.strip('"'))
    return dic, extra, revert, short, ignore, known_es


def translate_qml(text, rel, dic, extra, revert, ignore, known_es, pending):
    """Devuelve (texto traducido, numero de cambios)."""
    lines = text.split("\n")
    out = []
    changed = 0
    rev_patterns = revert.get(rel, [])
    rules = extra.get(rel, [])

    # indice del diccionario por cadena, para el fallback de contexto reformateado
    glob = {}
    for (arch, en, ctx), es in dic.items():
        glob.setdefault(en, set()).add((es, ctx))

    for line in lines:
        c = norm(line)
        if any(p.search(line) for p in rev_patterns):
            out.append(line)
            continue

        hit = set()

        def rep(m):
            nonlocal changed
            s = m.group(0)
            k = (rel, s, c)
            if k in dic and dic[k] != s:
                hit.add(s)
                changed += 1
                return dic[k]
            opts = glob.get(s, set())
            if len(opts) == 1:
                es, ctx = next(iter(opts))
                if c == ctx and es != s:
                    hit.add(s)
                    changed += 1
                    return es
            return s

        new = STR.sub(rep, line)

        for ancla, en_re, es in rules:
            if ancla.search(new) and en_re.search(new):
                m = en_re.search(new)
                new = new[:m.start()] + es + new[m.end():]
                changed += 1

        if new == line:
            for m in STR.finditer(line):
                s = m.group(0)
                t = s[1:-1]
                if s in hit or not LET.search(t):
                    continue
                if DATA.fullmatch(t) and not re.search(r"[A-Z ]", t):
                    continue
                if t in ignore or t in known_es:
                    continue
                if re.search(r"[áéíóúÁÉÍÓÚñÑ¿¡]", t):
                    continue
                if re.search(r"[/=$]", t) or " -p " in t:
                    continue
                # comandos, formatos de fecha/hora, unidades y siglas: datos, no UI
                if re.search(r"[;|{}$%]|&&|\|\||--|~|\b(sudo|printf|echo|qs|nmcli|pkexec|xdg-|sh -c)\b", t):
                    continue
                if re.search(r"\d", t) and re.search(r"hour|min|sec|px|Hz|°|%", t, re.I):
                    continue
                if re.search(r"\b[hHmMdDyY]\b[:/ ]|[hH]:[mM]", t):
                    continue
                if t.isupper() and len(t) <= 12:
                    continue
                if t.strip() in {"Gbps", "Mbps", "Kbps", "Hz", "ms", "px", "min",
                                 "s", "W", "V", "A", "KB", "MB", "GB"}:
                    continue
                if "\\" in t or re.search(r"[<>{}*@#+]", t):
                    continue
                pending.setdefault(t, []).append(rel)
        out.append(new)

    return "\n".join(out), changed


def translate_shortcuts(text, short, stats):
    """Traduce las descripciones desc=; conserva las ediciones del usuario."""
    values = set(short.values())
    translated = already = edited = 0
    out = []
    for line in text.split("\n"):
        if line.lstrip().startswith("#") or "desc=" not in line:
            out.append(line)
            continue
        m = DESC.search(line)
        if not m:
            out.append(line)
            continue
        ini, end = m.start(), m.end()
        val = line[ini + 5:end]
        txt = val
        quoted = False
        if txt.startswith('"'):
            txt = txt[1:-1]
            quoted = True
        if txt not in short:
            if txt in values:
                already += 1
            else:
                edited += 1
            out.append(line)
            continue
        nuevo = short[txt]
        if nuevo == txt:
            already += 1
            out.append(line)
            continue
        translated += 1
        rep = 'desc="%s"' % nuevo if (quoted or " " in nuevo) else "desc=" + nuevo
        resto = line[end:]
        sp = len(resto) - len(resto.lstrip(" \t"))
        tail = resto[sp:]
        if tail == "":
            out.append(line[:ini] + rep)
            continue
        ancho = len((line[ini:end] + resto[:sp]).encode("utf-8"))
        pad = max(1, ancho - len(rep))
        out.append(line[:ini] + rep + " " * pad + tail)

    stats["shortcuts"] = (translated, already, edited)
    return "\n".join(out)


def state_path():
    base = os.environ.get("XDG_STATE_HOME") or os.path.join(os.path.expanduser("~"), ".local/state")
    return os.path.join(base, "traducir-en-vivo.last")


def write_atomic(path, content):
    tmp = path + ".vivo-tmp"
    mode = stat.S_IMODE(os.stat(path).st_mode)
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(content)
    os.chmod(tmp, mode)
    os.replace(tmp, path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", default=os.environ.get("BUTTERBIAN_ES_DEST") or os.path.join(os.path.expanduser("~"), ".config/suckless"))
    ap.add_argument("--pkg", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--restore", action="store_true")
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--add", nargs=3, metavar=("ARCHIVO", "EN", "ES"),
                    help='agregar un par: --add quickshell/Clock.qml "New text" "Texto nuevo"')
    a = ap.parse_args()

    dest, pkg = a.dest, a.pkg
    if not os.path.isdir(dest):
        print("ERROR: no existe el destino:", dest, file=sys.stderr)
        return 2

    if a.add:
        rel, en_txt, es_txt = a.add
        en = en_txt if en_txt.startswith('"') else '"' + en_txt + '"'
        es = es_txt if es_txt.startswith('"') else '"' + es_txt + '"'
        fila = [rel, en_txt.strip('"'), en, es]
        ruta = os.path.join(pkg, "tools/rules_extra.tsv")
        for line in open(ruta, encoding="utf-8"):
            if line.startswith("#"):
                continue
            if line.rstrip("\n").split("\t") == fila:
                print("La regla ya existe:", " | ".join(fila))
                return 0
        with open(ruta, "a", encoding="utf-8") as f:
            f.write("\t".join(fila) + "\n")
        print("Regla agregada:", " | ".join(fila))
        print("Vuelve a correr el traductor para aplicarla.")
        return 0

    if a.restore:
        last = state_path()
        if not os.path.exists(last):
            print("ERROR: no hay aplicacion registrada en", last, file=sys.stderr)
            return 2
        bak = open(last, encoding="utf-8").readline().strip()
        if not os.path.exists(bak):
            print("ERROR: no existe el backup:", bak, file=sys.stderr)
            return 2
        subprocess.run(["tar", "xzf", bak, "-C", dest], check=True)
        print("Restaurado desde", bak)
        print("Presiona Super+Ctrl+R para recargar la barra.")
        return 0

    dic, extra, revert, short, ignore, known_es = load_rules(pkg)
    changes = {}
    stats = {"qml": 0, "files": 0}
    pending = {}

    for carpeta in ("quickshell", "quickshell-network"):
        root = os.path.join(dest, carpeta)
        if not os.path.isdir(root):
            continue
        for basedir, _, files in os.walk(root):
            for name in sorted(files):
                if not name.endswith(".qml"):
                    continue
                path = os.path.join(basedir, name)
                rel = os.path.relpath(path, dest).replace(os.sep, "/")
                text = open(path, encoding="utf-8").read()
                new, n = translate_qml(text, rel, dic, extra, revert, ignore, known_es, pending)
                if n:
                    changes[rel] = new
                    stats["qml"] += n
                    stats["files"] += 1

    key = "dwm/keybinds.conf"
    key_path = os.path.join(dest, key)
    if os.path.exists(key_path):
        text = open(key_path, encoding="utf-8").read()
        new = translate_shortcuts(text, short, stats)
        if new != text:
            changes[key] = new

    tr, ya, edit = stats.get("shortcuts", (0, 0, 0))
    print("Textos QML traducidos: %d en %d archivo(s)" % (stats["qml"], stats["files"]))
    print("Atajos: %d por traducir, %d ya en espanol, %d con texto propio (se conservan)" % (tr, ya, edit))
    if pending:
        print("Cadenas no reconocidas por el diccionario: %d (datos o texto propio; usa --verbose)" % len(pending))
        if a.verbose:
            for txt, where in sorted(pending.items(), key=lambda x: x[0])[:40]:
                print("   - %r  (%s)" % (txt[:70], ", ".join(sorted(set(where))[:2])))
            print('  Para cubrirlos agrega a tools/rules_extra.tsv: archivo<TAB>ancla<TAB>"en"<TAB>"es"')

    if a.check:
        print("--check: no se escribio nada.")
        return 0
    if not changes:
        print("Nada que traducir: ya esta todo en espanol.")
        return 0

    stamp = time.strftime("%Y%m%d-%H%M%S")
    bak = os.path.join(os.path.expanduser("~"), "butterbian-es-vivo-backup-%s.tar.gz" % stamp)
    with tarfile.open(bak, "w:gz") as tar:
        for rel in sorted(changes):
            tar.add(os.path.join(dest, rel), arcname=rel)
    os.makedirs(os.path.dirname(state_path()), exist_ok=True)
    with open(state_path(), "w", encoding="utf-8") as f:
        f.write(bak + "\n")

    for rel, content in changes.items():
        write_atomic(os.path.join(dest, rel), content)
    print("Backup:", bak)
    print("Archivos modificados en sitio:", ", ".join(sorted(changes)))
    print("No se reemplazo ningun archivo: solo cambiaron las cadenas de texto.")
    print("Presiona Super+Ctrl+R para recargar la barra.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

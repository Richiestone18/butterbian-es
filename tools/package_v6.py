#!/usr/bin/env python3
"""butterbian-es v6: packages the translation into the package (payload + manifest + shortcuts.tsv).

vs v5: the tools already live INSIDE the package (tools/), they are not
copied from an external working directory; the rest of the flow is the same.

Usage:
  package_v6.py [--repo R] [--out O] [--version v6]
Defaults: R=work/butterdwm-full  O=work/v6/suckless  version=v6
"""
import os, re, shutil, hashlib, subprocess, argparse

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # raiz del paquete


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', default='work/butterdwm-full')
    ap.add_argument('--out', default='work/v6/suckless')
    ap.add_argument('--version', default='v6')
    a = ap.parse_args()
    S = HERE
    U = f'{S}/{a.repo}/suckless'      # upstream en ingles
    V = f'{S}/{a.out}'                # traduccion
    REPO = S
    COMMIT = subprocess.run(['git', '-C', f'{S}/{a.repo}', 'rev-parse', 'HEAD'],
                            capture_output=True, text=True).stdout.strip()
    FECHA = subprocess.run(['git', '-C', f'{S}/{a.repo}', 'log', '-1',
                            '--format=%cd', '--date=short'],
                           capture_output=True, text=True).stdout.strip()

    def sha(p):
        return hashlib.sha256(open(p, 'rb').read()).hexdigest()

    # --- previous Spanish versions: (sha256, ruta) de lo que este paquete ya
    # --- tradujo antes, para que el instalador las actualice en vez de
    # --- confundirlas con una edicion a mano (translated-before.tsv, acumulado)
    ANTES = os.path.join(REPO, 'translated-before.tsv')
    previas = set()
    if os.path.exists(ANTES):
        for _l in open(ANTES, encoding='utf-8'):
            _p = _l.split()
            if len(_p) == 2:
                previas.add((_p[0], _p[1]))
    _pay = os.path.join(REPO, 'payload/suckless')
    if os.path.isdir(_pay):
        for _r, _, _fs in os.walk(_pay):
            for _x in _fs:
                _rel = os.path.relpath(os.path.join(_r, _x), _pay)
                previas.add((hashlib.sha256(
                    open(os.path.join(_r, _x), 'rb').read()).hexdigest(), _rel))

    # clean previous format
    for viejo in ('payload', 'traducir.txt'):
        p = os.path.join(REPO, viejo)
        if os.path.isdir(p):
            shutil.rmtree(p)
        elif os.path.exists(p):
            os.remove(p)

    filas = []
    for root, _, fs in os.walk(V):
        for f in sorted(fs):
            rel = os.path.relpath(os.path.join(root, f), V)
            if rel == 'dwm/keybinds.conf':
                continue          # goes through shortcuts.tsv, line by line
            en, es = os.path.join(U, rel), os.path.join(V, rel)
            if not os.path.exists(en) or sha(en) == sha(es):
                continue
            dst = os.path.join(REPO, 'payload/suckless', rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(es, dst)
            os.chmod(dst, os.stat(en).st_mode & 0o777)
            filas.append((sha(en), sha(es), rel))
    filas.sort(key=lambda r: r[2])
    with open(os.path.join(REPO, 'manifest.txt'), 'w') as m:
        m.write(f'# butterbian-es {a.version} · butterdwm {COMMIT[:12]} ({FECHA})\n')
        m.write('# sha256 of the English original · sha256 of the translated · path in ~/.config/suckless\n')
        m.write('# A file is only replaced if it is IDENTICAL to the original of that version.\n')
        for en, es, rel in filas:
            m.write(f'{en} {es} {rel}\n')

    # shortcuts: en->es desc pairs, comparing upstream vs translation line by line
    DESC = re.compile(r'desc=("[^"]*"|\S+)')
    pares = {}
    for a, b in zip(open(f'{U}/dwm/keybinds.conf', encoding='utf-8'),
                    open(f'{V}/dwm/keybinds.conf', encoding='utf-8')):
        if a.lstrip().startswith('#'):
            continue
        ma, mb = DESC.search(a), DESC.search(b)
        if not (ma and mb):
            continue
        ea, eb = ma.group(1).strip('"'), mb.group(1).strip('"')
        pares[ea] = eb          # also the ones equal in both languages (Terminal, Editor...)
    with open(os.path.join(REPO, 'shortcuts.tsv'), 'w', encoding='utf-8') as t:
        t.write(f'# original description (English)\tdescription in Spanish   · butterdwm {COMMIT[:12]}\n')
        for ea, eb in pares.items():
            t.write(f'{ea}\t{eb}\n')

    # translated-before.tsv: versiones espanolas anteriores, sin los pares que
    # esta version repite (los que no cambiaron son la version actual)
    nuevas = {(es, rel) for en, es, rel in filas}
    previas2 = sorted(p for p in previas if p not in nuevas)
    with open(ANTES, 'w', encoding='utf-8') as _f:
        _f.write('# sha256 of the Spanish files an earlier release of this package installed\n')
        _f.write('# if ~/.config/suckless matches one of these, the installer updates the\n')
        _f.write('# file (it is ours, not a hand edit) instead of leaving it as is\n')
        for _h, _rel in previas2:
            _f.write('%s %s\n' % (_h, _rel))
    print('translated-before.tsv: %d previous Spanish file(s)' % len(previas2))

    print(f'payload: {len(filas)} files | shortcuts.tsv: {len(pares)} phrases | upstream {COMMIT[:12]} ({FECHA})')
    print('by folder:', {k: sum(1 for r in filas if r[2].startswith(k))
                         for k in ('quickshell/', 'quickshell-network/', 'scripts/')})


if __name__ == '__main__':
    main()

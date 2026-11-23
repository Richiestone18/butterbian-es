#!/usr/bin/env python3
"""butterbian-es v6: dwm shortcuts in Spanish.

vs v5:
  - The description dictionary is READ from shortcuts.tsv (single source,
    shipped with the package) instead of being duplicated in the code.
  - The scripts/keybinds and KeybindsPane.qml patches use regex anchors.

Usage:
  keybinds_v6.py [--repo R] [--out O] [--shortcuts A]
Defaults: R=work/butterdwm-full  O=work/v6/suckless  A=shortcuts.tsv
"""
import os, re, sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # package root


def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', default='work/butterdwm-full')
    ap.add_argument('--out', default='work/v6/suckless')
    ap.add_argument('--shortcuts', default='shortcuts.tsv')
    a = ap.parse_args()
    U = os.path.join(HERE, a.repo, 'suckless')
    V = os.path.join(HERE, a.out)
    fallas = []

    # -------------------------------------------------- dictionary from shortcuts.tsv
    D = {}
    with open(os.path.join(HERE, a.shortcuts), encoding='utf-8') as f:
        for line in f:
            line = line.rstrip('\n')
            if not line or line.startswith('#'):
                continue
            en, es = line.split('\t', 1)
            D[en] = es
    print('shortcuts.tsv:', len(D), 'phrases')

    # ---------------------------------------------------------------- keybinds.conf
    DESC = re.compile(r'desc=(\"(?:[^\"\\\\]|\\\\.)*\"|\\S+)')
    src = open(f'{U}/dwm/keybinds.conf', encoding='utf-8').read().split('\n')
    out = []; n_ok = 0; sin = []
    for l in src:
        if l.lstrip().startswith('mod=') or (l.lstrip().startswith('key=') and 'desc=' in l):
            m = DESC.search(l)
            if m:
                val = m.group(1); txt = val[1:-1] if val.startswith('"') else val
                if txt not in D: sin.append(txt); out.append(l); continue
                es = D[txt]; nuevo = f'desc="{es}"' if (' ' in es or val.startswith('"')) else f'desc={es}'
                ini, fin = m.span()
                resto = l[fin:]; pad = len(resto) - len(resto.lstrip(' '))
                ancho = (fin - ini) + pad                 # original width of the desc column
                relleno = max(1, ancho - len(nuevo))
                l = l[:ini] + nuevo + (' ' * relleno + resto.lstrip(' ') if resto.strip() else '')
                n_ok += 1
        out.append(l)
    os.makedirs(f'{V}/dwm', exist_ok=True)
    open(f'{V}/dwm/keybinds.conf', 'w', encoding='utf-8').write('\n'.join(out))
    print(f'keybinds.conf: {n_ok} desc translated | untranslated: {len(sin)} {sin}')
    if sin: fallas.append('desc without translation')

    # ---------------------------------------------------------------- scripts/keybinds
    k = open(f'{U}/scripts/keybinds', encoding='utf-8').read()
    R = [
        # (regex del bloque EN, texto ES)
        (r'"Previous tag"', '"Etiqueta anterior"'),
        (r'"View tag "', '"Ver etiqueta "'),
        (r'"Toggle tag "', '"Alternar etiqueta "'),
        (r'"Move window to tag "', '"Mover ventana a la etiqueta "'),
        (r'"Toggle window on tag "', '"Alternar ventana en la etiqueta "'),
        (r'"Show or hide slot "', '"Mostrar u ocultar la ranura "'),
        (r'"Put this window in slot "', '"Poner esta ventana en la ranura "'),
        (r'return "Layout: " a', 'return "Diseño: " ((a in LN) ? LN[a] : a)'),
        (r'K\["space"\] = "Space"', 'K["space"] = "Espacio"'),
        (r'K\["BackSpace"\] = "Backspace"; K\["Delete"\] = "Del"; K\["Print"\] = "PrtSc"',
         'K["BackSpace"] = "Retroceso"; K["Delete"] = "Supr"; K["Print"] = "ImprPant"'),
        (r'K\["XF86AudioRaiseVolume"\] = "Vol Up"; K\["XF86AudioLowerVolume"\] = "Vol Down"',
         'K["XF86AudioRaiseVolume"] = "Subir vol"; K["XF86AudioLowerVolume"] = "Bajar vol"'),
        (r'K\["XF86AudioMute"\] = "Mute"; K\["XF86AudioMicMute"\] = "Mic Mute"',
         'K["XF86AudioMute"] = "Silencio"; K["XF86AudioMicMute"] = "Silenciar mic"'),
        (r'K\["XF86MonBrightnessUp"\] = "Brightness Up"; K\["XF86MonBrightnessDown"\] = "Brightness Down"',
         'K["XF86MonBrightnessUp"] = "Subir brillo"; K["XF86MonBrightnessDown"] = "Bajar brillo"'),
        (r'    K\["Return"\] = "Enter";',
         '    # nombres de los layouts para la ayuda (do=setlayout NOMBRE)\n'
         '    LN["dwindle"] = "dwindle"; LN["tile"] = "mosaico"; LN["columns"] = "columnas"; LN["centered"] = "centrada"\n'
         '    LN["floating"] = "flotante"; LN["bstack"] = "pila inferior"; LN["nrowgrid"] = "rejilla de n filas"; LN["deck"] = "baraja"\n'
         '    LN["gaplessgrid"] = "rejilla sin huecos"; LN["spiral"] = "espiral"; LN["monocle"] = "monóculo"; LN["grid"] = "rejilla"\n'
         '    K["Return"] = "Enter";'),
    ]
    for old, new in R:
        k, n = re.subn(old, new, k)
        if n == 0:
            fallas.append(f'scripts/keybinds: not found «{old[:40]}»')
    os.makedirs(f'{V}/scripts', exist_ok=True)
    open(f'{V}/scripts/keybinds', 'w', encoding='utf-8').write(k)
    os.chmod(f'{V}/scripts/keybinds', 0o755)
    print('scripts/keybinds: replacements', len(R))

    # ---------------------------------------------------------------- KeybindsPane.qml (display only)
    p = f'{V}/quickshell/KeybindsPane.qml'; q = open(p, encoding='utf-8').read()
    PQ = [
        (r'    readonly property var foldByDefault: \["scratch slots"\]\n',
         '    readonly property var foldByDefault: ["scratch slots"]\n'
         '    // section names as shown; the real name (keybinds.conf) stays in English\n'
         '    readonly property var sectionNames: ({ launch: "lanzar", "bar popups": "ventanas de la barra",\n'
         '        window: "ventana", layout: "diseño", tags: "etiquetas", monitor: "monitor",\n'
         '        scratchpads: "scratchpads", "scratch slots": "ranuras scratch", gaps: "huecos",\n'
         '        media: "multimedia", screenshots: "capturas", system: "sistema", other: "otros" })\n'),
        (r'\+ section\.modelData\.title\n',
         '+ (root.sectionNames[section.modelData.title] ?? section.modelData.title)\n'),
        (r'\? "New bind in " \+ root\.editing\.section',
         '? "Nuevo atajo en " + (root.sectionNames[root.editing.section] ?? root.editing.section)'),
    ]
    for old, new in PQ:
        q, n = re.subn(old, new, q)
        if n != 1:
            fallas.append(f'KeybindsPane: «{old.strip()[:50]}» found {n} times')
    open(p, 'w', encoding='utf-8').write(q)
    print('KeybindsPane.qml: patches', len(PQ))
    print('FAILURES:', fallas or 'none')
    sys.exit(1 if fallas else 0)


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Empaqueta la v4 en el repo butterbian-es (payload + manifiesto + atajos.tsv + herramientas)."""
import os, re, shutil, hashlib, subprocess
S = os.path.dirname(os.path.abspath(__file__))
U = f'{S}/butterdwm-full/suckless'      # upstream en ingles (d63645d)
V = f'{S}/v4/suckless'                  # v4 traducida
REPO = f'{S}/butterbian-es'
COMMIT = subprocess.run(['git', '-C', f'{S}/butterdwm-full', 'rev-parse', 'HEAD'], capture_output=True, text=True).stdout.strip()
FECHA = subprocess.run(['git', '-C', f'{S}/butterdwm-full', 'log', '-1', '--format=%cd', '--date=short'], capture_output=True, text=True).stdout.strip()
def sha(p): return hashlib.sha256(open(p, 'rb').read()).hexdigest()

# limpiar formato v3
for viejo in ('payload', 'traducir.txt'):
    p = os.path.join(REPO, viejo)
    if os.path.isdir(p): shutil.rmtree(p)
    elif os.path.exists(p): os.remove(p)

filas = []
for root, _, fs in os.walk(V):
    for f in sorted(fs):
        rel = os.path.relpath(os.path.join(root, f), V)
        if rel == 'dwm/keybinds.conf': continue          # va por atajos.tsv, linea por linea
        en, es = os.path.join(U, rel), os.path.join(V, rel)
        if not os.path.exists(en) or sha(en) == sha(es): continue
        dst = os.path.join(REPO, 'payload/suckless', rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(es, dst)
        os.chmod(dst, os.stat(en).st_mode & 0o777)
        filas.append((sha(en), sha(es), rel))
filas.sort(key=lambda r: r[2])
with open(os.path.join(REPO, 'manifiesto.txt'), 'w') as m:
    m.write(f'# butterbian-es v4 · butterdwm {COMMIT[:12]} ({FECHA})\n')
    m.write('# sha256 del original en ingles · sha256 del traducido · ruta en ~/.config/suckless\n')
    m.write('# Solo se reemplaza un archivo si es IDENTICO al original de esa version.\n')
    for en, es, rel in filas: m.write(f'{en} {es} {rel}\n')

# atajos: pares desc ingles -> espanol, comparando linea a linea upstream vs v4
DESC = re.compile(r'desc=("[^"]*"|\S+)')
pares = {}
for a, b in zip(open(f'{U}/dwm/keybinds.conf', encoding='utf-8'), open(f'{V}/dwm/keybinds.conf', encoding='utf-8')):
    if a.lstrip().startswith('#'): continue
    ma, mb = DESC.search(a), DESC.search(b)
    if not (ma and mb): continue
    ea, eb = ma.group(1).strip('"'), mb.group(1).strip('"')
    pares[ea] = eb          # tambien los iguales en ambos idiomas (Terminal, Editor...)
with open(os.path.join(REPO, 'atajos.tsv'), 'w', encoding='utf-8') as t:
    t.write(f'# descripcion original (ingles)\tdescripcion en espanol   · butterdwm {COMMIT[:12]}\n')
    for ea, eb in pares.items(): t.write(f'{ea}\t{eb}\n')

# herramientas de mantenimiento (generador de la traduccion)
H = os.path.join(REPO, 'herramientas'); os.makedirs(H, exist_ok=True)
for f in ('dic_v4.py', 'v4_build.py', 'v4_keybinds.py', 'v4_scripts.py', 'empaquetar_v4.py'):
    shutil.copy2(os.path.join(S, f), os.path.join(H, f))
print(f'payload: {len(filas)} archivos | atajos.tsv: {len(pares)} frases | upstream {COMMIT[:12]} ({FECHA})')
print('por carpeta:', {k: sum(1 for r in filas if r[2].startswith(k)) for k in ('quickshell/', 'quickshell-network/', 'scripts/')})

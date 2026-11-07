#!/usr/bin/env python3
"""butterbian-es v4: atajos de dwm en espanol.
  - dwm/keybinds.conf: traduce desc= (conserva el '!' de fijado, alinea columnas)
  - scripts/keybinds: etiquetas automaticas de la ayuda (binds sin desc) y nombres de teclas
  - KeybindsPane.qml: nombres de seccion traducidos SOLO al mostrarlos
Correr despues de v4_build.py.
"""
import os, re, sys
U = 'butterdwm-full/suckless'; V = 'v4/suckless'
fallas = []

D = {
 '!Terminal': '!Terminal',
 "!App launcher (the bar's; rofi when the bar is down)": '!Lanzador de apps (rofi si no hay barra)',
 'Browser': 'Navegador',
 'Browser (private window)': 'Navegador (ventana privada)',
 'File manager': 'Gestor de archivos',
 'Editor': 'Editor',
 'Keybindings': 'Atajos de teclado',
 "!Window switcher (the bar's; rofi when the bar is down)": '!Cambiar de ventana (rofi si no hay barra)',
 'Wallpaper picker (re-themes the desktop from the image)': 'Elegir fondo (y los colores del escritorio)',
 'Command menu': 'Menú de comandos',
 'Layout settings': 'Ajustes de diseño',
 'Network app (Super+n is window-follow)': 'App de red (Super+n es seguir ventana)',
 'Power menu': 'Menú de energía',
 '!Close window': '!Cerrar ventana',
 'Focus next window': 'Enfocar ventana siguiente',
 'Focus previous window': 'Enfocar ventana anterior',
 'Move window down the stack': 'Bajar ventana en la pila',
 'Move window up the stack': 'Subir ventana en la pila',
 'Fullscreen': 'Pantalla completa',
 'Toggle floating': 'Alternar flotante',
 'Sticky (show on all tags)': 'Fijar (mostrar en todas las etiquetas)',
 'Window follows on tag / monitor send': 'Seguir la ventana al enviarla a otra etiqueta o monitor',
 'Hide or show the bar': 'Ocultar o mostrar la barra',
 'Tab attach: focused window into a tab group on this monitor': 'Pestañas: unir la ventana enfocada a un grupo de pestañas',
 'Tab detach: focused window out of its tab group': 'Pestañas: sacar la ventana enfocada de su grupo',
 '!Shrink master (or column)': '!Reducir maestro (o columna)',
 '!Grow master (or column)': '!Agrandar maestro (o columna)',
 'Shrink master (or column)': 'Reducir maestro (o columna)',
 'Grow master (or column)': 'Agrandar maestro (o columna)',
 'Reset master and column factors': 'Restablecer tamaños de maestro y columnas',
 'Master count +1': 'Ventanas maestras +1',
 'Master count -1': 'Ventanas maestras -1',
 'Previously viewed tag': 'Etiqueta vista antes',
 'Previous tag': 'Etiqueta anterior',
 'Next tag': 'Etiqueta siguiente',
 'Send window to previous tag': 'Enviar ventana a la etiqueta anterior',
 'Send window to next tag': 'Enviar ventana a la etiqueta siguiente',
 'Focus previous monitor': 'Enfocar monitor anterior',
 'Focus next monitor': 'Enfocar monitor siguiente',
 'Send window to previous monitor': 'Enviar ventana al monitor anterior',
 'Send window to next monitor': 'Enviar ventana al monitor siguiente',
 '!Drop-down terminal': '!Terminal desplegable',
 'Pulsemixer': 'Pulsemixer',
 'Make this window the drop-down terminal': 'Usar esta ventana como terminal desplegable',
 'Take this window out of its slot': 'Sacar esta ventana de su ranura',
 '!Toggle gaps': '!Alternar huecos',
 'Reset gaps to defaults': 'Restablecer huecos',
 'All gaps +1': 'Todos los huecos +1', 'All gaps -1': 'Todos los huecos -1',
 'Inner gaps +1': 'Huecos internos +1', 'Inner gaps -1': 'Huecos internos -1',
 'Outer gaps +1': 'Huecos externos +1', 'Outer gaps -1': 'Huecos externos -1',
 'Inner horizontal gaps +1': 'Huecos internos horizontales +1', 'Inner horizontal gaps -1': 'Huecos internos horizontales -1',
 'Inner vertical gaps +1': 'Huecos internos verticales +1', 'Inner vertical gaps -1': 'Huecos internos verticales -1',
 'Outer horizontal gaps +1': 'Huecos externos horizontales +1', 'Outer horizontal gaps -1': 'Huecos externos horizontales -1',
 'Outer vertical gaps +1': 'Huecos externos verticales +1', 'Outer vertical gaps -1': 'Huecos externos verticales -1',
 'Volume up': 'Subir volumen', 'Volume down': 'Bajar volumen', 'Mute': 'Silenciar',
 'Brightness up': 'Subir brillo', 'Brightness down': 'Bajar brillo',
 "Screenshot: region (flameshot's editor)": 'Captura: región (editor de flameshot)',
 'Screenshot: full screen': 'Captura: pantalla completa',
 '!Apply this file: regenerate, rebuild and restart dwm in place': '!Aplicar este archivo: regenerar, recompilar y reiniciar dwm',
 'Restart dwm (keeps windows and tags)': 'Reiniciar dwm (conserva ventanas y etiquetas)',
 'Restart the bar': 'Reiniciar la barra',
 'Quit dwm': 'Salir de dwm',
}

# ---------------------------------------------------------------- keybinds.conf
DESC = re.compile(r'desc=("(?:[^"\\]|\\.)*"|\S+)')
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
            ancho = (fin - ini) + pad                 # ancho original de la columna desc
            relleno = max(1, ancho - len(nuevo))
            l = l[:ini] + nuevo + (' ' * relleno + resto.lstrip(' ') if resto.strip() else '')
            n_ok += 1
    out.append(l)
os.makedirs(f'{V}/dwm', exist_ok=True)
open(f'{V}/dwm/keybinds.conf', 'w', encoding='utf-8').write('\n'.join(out))
print(f'keybinds.conf: {n_ok} desc traducidos | sin traduccion: {len(sin)} {sin}')
if sin: fallas.append('desc sin traduccion')

# ---------------------------------------------------------------- scripts/keybinds
k = open(f'{U}/scripts/keybinds', encoding='utf-8').read()
R = [
 ('"Previous tag"', '"Etiqueta anterior"'),
 ('"View tag "', '"Ver etiqueta "'),
 ('"Toggle tag "', '"Alternar etiqueta "'),
 ('"Move window to tag "', '"Mover ventana a la etiqueta "'),
 ('"Toggle window on tag "', '"Alternar ventana en la etiqueta "'),
 ('"Show or hide slot "', '"Mostrar u ocultar la ranura "'),
 ('"Put this window in slot "', '"Poner esta ventana en la ranura "'),
 ('return "Layout: " a', 'return "Diseño: " ((a in LN) ? LN[a] : a)'),
 ('K["space"] = "Space"', 'K["space"] = "Espacio"'),
 ('K["BackSpace"] = "Backspace"; K["Delete"] = "Del"; K["Print"] = "PrtSc"',
  'K["BackSpace"] = "Retroceso"; K["Delete"] = "Supr"; K["Print"] = "ImprPant"'),
 ('K["XF86AudioRaiseVolume"] = "Vol Up"; K["XF86AudioLowerVolume"] = "Vol Down"',
  'K["XF86AudioRaiseVolume"] = "Subir vol"; K["XF86AudioLowerVolume"] = "Bajar vol"'),
 ('K["XF86AudioMute"] = "Mute"; K["XF86AudioMicMute"] = "Mic Mute"',
  'K["XF86AudioMute"] = "Silencio"; K["XF86AudioMicMute"] = "Silenciar mic"'),
 ('K["XF86MonBrightnessUp"] = "Brightness Up"; K["XF86MonBrightnessDown"] = "Brightness Down"',
  'K["XF86MonBrightnessUp"] = "Subir brillo"; K["XF86MonBrightnessDown"] = "Bajar brillo"'),
 ('    K["Return"] = "Enter";',
  '    # nombres de los layouts para la ayuda (do=setlayout NOMBRE)\n'
  '    LN["dwindle"] = "dwindle"; LN["tile"] = "mosaico"; LN["columns"] = "columnas"; LN["centered"] = "centrada"\n'
  '    LN["floating"] = "flotante"; LN["bstack"] = "pila inferior"; LN["nrowgrid"] = "rejilla de n filas"; LN["deck"] = "baraja"\n'
  '    LN["gaplessgrid"] = "rejilla sin huecos"; LN["spiral"] = "espiral"; LN["monocle"] = "monóculo"; LN["grid"] = "rejilla"\n'
  '    K["Return"] = "Enter";'),
]
for old, new in R:
    c = k.count(old)
    if c == 0: fallas.append(f'scripts/keybinds: no encontre «{old}»'); continue
    k = k.replace(old, new)
os.makedirs(f'{V}/scripts', exist_ok=True)
open(f'{V}/scripts/keybinds', 'w', encoding='utf-8').write(k)
os.chmod(f'{V}/scripts/keybinds', 0o755)
print('scripts/keybinds: reemplazos', len(R))

# ---------------------------------------------------------------- KeybindsPane.qml (solo mostrar)
p = f'{V}/quickshell/KeybindsPane.qml'; q = open(p, encoding='utf-8').read()
PQ = [
 ('    readonly property var foldByDefault: ["scratch slots"]\n',
  '    readonly property var foldByDefault: ["scratch slots"]\n'
  '    // section names as shown; the real name (keybinds.conf) stays in English\n'
  '    readonly property var sectionNames: ({ launch: "lanzar", "bar popups": "ventanas de la barra",\n'
  '        window: "ventana", layout: "diseño", tags: "etiquetas", monitor: "monitor",\n'
  '        scratchpads: "scratchpads", "scratch slots": "ranuras scratch", gaps: "huecos",\n'
  '        media: "multimedia", screenshots: "capturas", system: "sistema", other: "otros" })\n'),
 ('+ section.modelData.title\n',
  '+ (root.sectionNames[section.modelData.title] ?? section.modelData.title)\n'),
 ('"Nuevo atajo en " + root.editing.section',
  '"Nuevo atajo en " + (root.sectionNames[root.editing.section] ?? root.editing.section)'),
]
for old, new in PQ:
    c = q.count(old)
    if c != 1: fallas.append(f'KeybindsPane: «{old.strip()[:50]}» aparece {c} veces'); continue
    q = q.replace(old, new)
open(p, 'w', encoding='utf-8').write(q)
print('KeybindsPane.qml: parches', len(PQ))
print('FALLAS:', fallas or 'ninguna')
sys.exit(1 if fallas else 0)

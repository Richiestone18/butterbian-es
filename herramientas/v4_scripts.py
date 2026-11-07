#!/usr/bin/env python3
"""butterbian-es v4: textos visibles de scripts/ (notificaciones y menus de rofi de respaldo).
Reemplazos exactos; cada uno debe aparecer las veces esperadas. Correr despues de v4_keybinds.py."""
import os, sys
U = 'butterdwm-full/suckless/scripts'; V = 'v4/suckless/scripts'
S = {
 'keybinds-apply': [
  ('"dwm build failed"', '"Falló la compilación de dwm"', 1),
  ('"Keybinds applied" "dwm rebuilt and restarted"', '"Atajos aplicados" "dwm recompilado y reiniciado"', 1),
 ],
 'wallpaper-theme': [
  ('"GTK not themed"', '"GTK sin tema"', 2),
  ('"Orchis-Nord-Template is missing. Rerun the theme installer:\\ntheming/install_wallpaper_theme.sh"',
   '"Falta Orchis-Nord-Template. Vuelve a correr el instalador del tema:\\ntheming/install_wallpaper_theme.sh"', 1),
  ('"Orchis-Nord-Template is not the plain-Nord build. Rerun the theme installer:\\ntheming/install_wallpaper_theme.sh"',
   '"Orchis-Nord-Template no es la versión Nord simple. Vuelve a correr el instalador del tema:\\ntheming/install_wallpaper_theme.sh"', 1),
  ('"Wallpaper theme" "Palette from $(basename "$IMG")"', '"Tema del fondo" "Paleta de $(basename "$IMG")"', 1),
 ],
 'autostart.sh': [
  ('"Welcome to dwm"', '"Bienvenido a dwm"', 1),
  ('"Press Super + / anytime to see all keybindings.&#10;See ~/QUICKSTART-dwm.md for a cheat sheet."',
   '"Presiona Super + / cuando quieras para ver todos los atajos.&#10;En ~/QUICKSTART-dwm.md hay una guía rápida."', 1),
 ],
 'help': [
  ('-p "Keybindings"', '-p "Atajos"', 1),
 ],
 'power': [   # menu de rofi de respaldo: opciones y case cambian juntos
  ('"[Cancel]" "Logout" "Shutdown" "Reboot"', '"[Cancelar]" "Cerrar sesión" "Apagar" "Reiniciar"', 1),
  ('-p "Power Menu"', '-p "Energía"', 1),
  ('    "Logout")', '    "Cerrar sesión")', 1),
  ('    "Shutdown")', '    "Apagar")', 1),
  ('    "Reboot")', '    "Reiniciar")', 1),
 ],
}
fallas = []
for f, reglas in S.items():
    t = open(os.path.join(U, f), encoding='utf-8').read()
    for old, new, n in reglas:
        c = t.count(old)
        if c != n: fallas.append(f'{f}: «{old[:50]}» aparece {c} veces (esperaba {n})'); continue
        t = t.replace(old, new)
    os.makedirs(V, exist_ok=True)
    open(os.path.join(V, f), 'w', encoding='utf-8').write(t)
    os.chmod(os.path.join(V, f), os.stat(os.path.join(U, f)).st_mode & 0o777)
print('scripts traducidos:', ', '.join(S), '| FALLAS:', fallas or 'ninguna')
sys.exit(1 if fallas else 0)

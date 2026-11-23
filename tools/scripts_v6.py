#!/usr/bin/env python3
"""butterbian-es v6: visible texts of scripts/ (notifications and rofi fallback menus).
Same as v5 (exact replacements with expected counts) but parameterized.

Usage:
  scripts_v6.py [--repo R] [--out O]
Defaults: R=work/butterdwm-full  O=work/v6/suckless
"""
import os, sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # raiz del paquete


def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', default='work/butterdwm-full')
    ap.add_argument('--out', default='work/v6/suckless')
    a = ap.parse_args()
    U = os.path.join(HERE, a.repo, 'suckless/scripts')
    V = os.path.join(HERE, a.out, 'scripts')
    S = {
        'keybinds-apply': [
            ('"dwm build failed"', '"Falló la compilación de dwm"', 1),
            ('"Keybinds applied" "dwm rebuilt and restarted"', '"Atajos aplicados" "dwm recompilado y reiniciado"', 1),
            ('printf "\\npress enter to close "', 'printf "\\npulsa enter para cerrar "', 1),
        ],
        'wallpaper-theme': [
            ('"Wallpaper theme" "Palette from $(basename "$IMG")"', '"Tema del fondo" "Paleta de $(basename "$IMG")"', 1),
        ],
        # v7: upstream movio el recoloreo de GTK (y sus avisos) a scripts/gtk-theme
        'gtk-theme': [
            ('"GTK not themed"', '"GTK sin tema"', 1),
            ('problem "Orchis-Nord-Template is missing."', 'problem "Falta Orchis-Nord-Template."', 1),
            ('problem "Orchis-Nord-Template is not the plain-Nord build."',
             'problem "Orchis-Nord-Template no es la versión Nord simple."', 1),
            ('"$1 Rerun the theme installer:\\ntheming/install_wallpaper_theme.sh"',
             '"$1 Vuelve a correr el instalador del tema:\\ntheming/install_wallpaper_theme.sh"', 1),
        ],
        # v7: los errores de scripts/radar los pinta la tarjeta del radar
        'radar': [
            ('"radar: couldn\'t reach RainViewer"', '"radar: no se pudo conectar con RainViewer"', 1),
            ('"radar: no frames"', '"radar: sin imágenes"', 1),
            ('"radar: some tiles failed"', '"radar: algunos mosaicos fallaron"', 1),
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
            if c != n:
                fallas.append(f'{f}: «{old[:50]}» found {c} times (expected {n})')
                continue
            t = t.replace(old, new)
        os.makedirs(V, exist_ok=True)
        open(os.path.join(V, f), 'w', encoding='utf-8').write(t)
        os.chmod(os.path.join(V, f), os.stat(os.path.join(U, f)).st_mode & 0o777)
    print('scripts translated:', ', '.join(S), '| FAILURES:', fallas or 'none')
    sys.exit(1 if fallas else 0)


if __name__ == '__main__':
    main()

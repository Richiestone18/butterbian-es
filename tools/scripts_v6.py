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
        # ---- v8: avisos de los scripts (notificaciones, terminal y el editor
        # ---- de atajos/reglas, que muestra los avisos de los generadores)
        'changevolume': [
            ('"Volume ${volume}%"', '"Volumen ${volume}%"', 1),
            ('"Volume Muted"', '"Volumen silenciado"', 1),
        ],
        'setup-update': [
            ('"setup-update: no install record in $R (not installed from a git clone)"',
             '"setup-update: no hay registro de instalación en $R (no se instaló desde un clon de git)"', 1),
            ('"setup: can\'t reach $REMOTE"', '"setup: no se pudo alcanzar $REMOTE"', 2),
            ('"setup: up to date ($BRANCH)"', '"setup: al día ($BRANCH)"', 2),
            ('"setup: 1 commit newer on $BRANCH"', '"setup: 1 commit más nuevo en $BRANCH"', 1),
            ('"setup: $n commits newer on $BRANCH"', '"setup: $n commits más nuevos en $BRANCH"', 1),
            ('"setup: $BRANCH has moved on since this install ($SRC is gone, so no count)"',
             '"setup: $BRANCH avanzó desde esta instalación ($SRC ya no está, así que sin conteo)"', 1),
            ('"$SRC: pulling $BRANCH"', '"$SRC: bajando $BRANCH"', 1),
            ('"update failed: $SRC couldn\'t pull origin/$BRANCH (git says why above)"',
             '"falló la actualización: $SRC no pudo bajar origin/$BRANCH (git dice por qué arriba)"', 1),
            ('"update failed: $SRC is in the way and isn\'t a clone of the setup"',
             '"falló la actualización: $SRC está en medio y no es un clon del setup"', 1),
            ('"cloning $REMOTE ($BRANCH) to $SRC"', '"clonando $REMOTE ($BRANCH) en $SRC"', 1),
            ('"update failed: can\'t clone $REMOTE"', '"falló la actualización: no se pudo clonar $REMOTE"', 1),
            ('"update failed: the installer stopped (see above)"',
             '"falló la actualización: el instalador se detuvo (ver arriba)"', 1),
            ("printf 'update it now? [y/N] '", "printf '¿actualizar ahora? [y/N] '", 1),
            ("printf '\\ndone'", "printf '\\nlisto'", 1),
            ("printf '\\npress enter to close '", "printf '\\npulsa enter para cerrar '", 1),
            ('"usage: setup-update [check|offer]"', '"uso: setup-update [check|offer]"', 1),
        ],
        'keybinds-gen': [
            ('"keybinds-gen: cannot read $CONF"', '"keybinds-gen: no se pudo leer $CONF"', 1),
            ('"keybinds-gen: cannot read $DEF"', '"keybinds-gen: no se pudo leer $DEF"', 1),
            ('expected next/prev or a number, got ', 'se espera next/prev o un número, en vez de ', 1),
            ('tag number 1-12 expected, got ', 'se espera una etiqueta 1-12, en vez de ', 1),
            ('return "Layout: " a', 'return "Diseño: " a', 1),
            ('expected name=value, got ', 'se espera name=value, en vez de ', 1),
            ('unclosed quote in ', 'comilla sin cerrar en ', 1),
            ('die("unknown field ', 'die("campo desconocido ', 1),
            ('name "= given twice"', 'name "= repetido dos veces"', 1),
            ('unknown modifier ', 'modificador desconocido ', 1),
            ('"bind needs key="', '"el atajo necesita key="', 1),
            ('"bind needs run= or do= (one of them)"', '"el atajo necesita run= o do= (uno de los dos)"', 1),
            ('"key= is one keysym name"', '"key= es un solo nombre de tecla"', 1),
            (' is bound twice (lines ', ' está ligado dos veces (líneas ', 1),
            ('"run= is empty"', '"run= está vacío"', 1),
            ('" takes no argument"', '" no lleva argumento"', 1),
            ('"number expected for "', '"se espera un número para "', 1),
            ('unknown layout ', 'diseño desconocido ', 1),
            ('togglescratch takes the scratchpad id from rules.conf (one letter)',
             'togglescratch toma el id del scratchpad de rules.conf (una letra)', 1),
            (' is not defined in rules.conf', ' no está definido en rules.conf', 1),
            ('"scratchslot needs 1-9"', '"scratchslot necesita 1-9"', 1),
            ('"makescratchtagwin needs 1-9, s or none"', '"makescratchtagwin necesita 1-9, s o none"', 1),
            ('unknown action ', 'acción desconocida ', 1),
        ],
        'rules-gen': [
            ('"rules-gen: cannot read $CONF"', '"rules-gen: no se pudo leer $CONF"', 1),
            ('takes yes or no', 'acepta yes o no', 1),
            ('expected name=value, got ', 'se espera name=value, en vez de ', 1),
            ('unclosed quote in ', 'comilla sin cerrar en ', 1),
            ('unknown field ', 'campo desconocido ', 1),
            ('name "= given twice"', 'name "= repetido dos veces"', 1),
            ('tag= wants numbers 1-12, got ', 'tag= quiere números 1-12, en vez de ', 1),
            ('"a rule needs class=, instance= or title="', '"una regla necesita class=, instance= o title="', 1),
            ('"scratch= is one lowercase letter"', '"scratch= es una letra minúscula"', 1),
            ('" is defined twice"', '" está definido dos veces"', 1),
            ('"scratch= needs run=, the command that opens it"',
             '"scratch= necesita run=, el comando que lo abre"', 1),
            ('"run= only goes with scratch="', '"run= solo va con scratch="', 1),
            ('"monitor= wants a number"', '"monitor= quiere un número"', 1),
        ],
        'displays': [
            ('"displays: unknown argument $1"', '"displays: argumento desconocido $1"', 1),
        ],
        'themes': [
            ('"themes: no theme $id in $THEMES"', '"themes: no hay tema $id en $THEMES"', 1),
            ('"themes: no wallpaper for $id"', '"themes: no hay fondo para $id"', 1),
        ],
        'gen-keybinds': [
            ('"gen-keybinds: cannot read $CONF"', '"gen-keybinds: no se pudo leer $CONF"', 1),
        ],
        'install-dwm': [
            ("\"install-dwm: $src/$f is not a plain file of $u's\"",
             '"install-dwm: $src/$f no es un archivo normal de $u"', 1),
            ('"install-dwm: $src/$f changed while copying"',
             '"install-dwm: $src/$f cambió mientras se copiaba"', 1),
        ],
        'picom-effects': [
            ('"picom-effects opacity: a percent 50-100"',
             '"picom-effects opacity: un porcentaje 50-100"', 1),
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

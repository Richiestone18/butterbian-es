#!/usr/bin/env python3
"""butterbian-es v4: traduce los QML de butterdwm (upstream actual) al espanol.

Fuentes:
  - diccionario en->es extraido de la v3 (payload de la Wyse, base upstream 328c5b0),
    aplicado solo donde coincide el contexto de la linea  (dic_v4.py -> v4/suckless)
  - reversiones: strings que el programa usa como datos (no se traducen)
  - traducciones nuevas (lo agregado en upstream despues de 328c5b0)
  - arreglos funcionales de la v3 re-aplicados (bateria, reloj, calendario...)
Valida al final que, fuera de los parches, solo cambiaron textos entre comillas.
"""
import os, re, sys, subprocess, difflib

U = 'butterdwm-full/suckless'          # upstream en ingles
V = 'v4/suckless'                      # salida
STR = re.compile(r'"(?:[^"\\]|\\.)*"')
def norm(l): return STR.sub('"S"', l).rstrip()

subprocess.run([sys.executable, 'dic_v4.py'], check=True, capture_output=True)

def rd(p): return open(p, encoding='utf-8').read().split('\n')
def wr(p, lines): open(p, 'w', encoding='utf-8').write('\n'.join(lines))
problemas = []

# ---------------------------------------------------------------- 1) reversiones
# lineas cuyo texto entre comillas es DATO (keysyms, sensores, señales, campos de
# nmcli, urgencias, categorias .desktop, salida de xrandr) + todos los comentarios
REVERT = {
    'quickshell/ChordField.qml':   ['Qt.Key_'],                       # keysyms X11 que van a keybinds.conf
    'quickshell/MetricsPopup.qml': ['"Package id 0"', '"Composite"', '"KILL"'],
    'quickshell/NotifyPopup.qml':  ['urgency ==='],
    'quickshell/Sys.qml':          ['IN-USE,SIGNAL'],
    'quickshell/LauncherPopup.qml':['categories.includes'],
    'quickshell/DisplaysPane.qml': ['!== "Unknown"'],
    'quickshell-network/shell.qml':['indexOf("fail")', 'indexOf("Error")'],
}
nrev = 0
for root, _, fs in os.walk(V):
    for f in fs:
        if not f.endswith('.qml'): continue
        rel = os.path.relpath(os.path.join(root, f), V)
        up, v4 = rd(os.path.join(U, rel)), rd(os.path.join(V, rel))
        assert len(up) == len(v4), rel
        for i, (a, b) in enumerate(zip(up, v4)):
            if a == b: continue
            if a.lstrip().startswith('//') or any(m in a for m in REVERT.get(rel, [])):
                v4[i] = a; nrev += 1
        wr(os.path.join(V, rel), v4)
print('lineas revertidas a ingles (datos/comentarios):', nrev)

# ---------------------------------------------------------------- 2) traducciones
# (archivo, ancla en la linea, texto_en, texto_es) -- reemplazo literal dentro de
# las lineas que contienen el ancla; cada regla debe aplicar al menos una vez
T = [
    ('quickshell/BarTweaks.qml', 'label: "Hide empty"', '"Hide empty"', '"Ocultar vacías"'),
    ('quickshell/BarTweaks.qml', 'label: "tags shown"', '"tags shown"', '"etiquetas visibles"'),
    ('quickshell/EditorPanel.qml', 'label: "Save"', '"Save"', '"Guardar"'),
    ('quickshell/EditorPanel.qml', 'label: "Cancel"', '"Cancel"', '"Cancelar"'),
    ('quickshell/EditorPanel.qml', 'label: "Delete"', '"Delete"', '"Eliminar"'),
    ('quickshell/KeybindsPane.qml', 'text: "Keys"', '"Keys"', '"Teclas"'),
    ('quickshell/KeybindsPane.qml', 'text: "Description"', '"Description"', '"Descripción"'),
    ('quickshell/KeybindsPane.qml', 'text: "Does"', '"Does"', '"Hace"'),
    ('quickshell/RulesPane.qml', '? "New rule"', '"New rule"', '"Nueva regla"'),
    ('quickshell/RulesPane.qml', 'text: "Window" }', '"Window"', '"Ventana"'),
    ('quickshell/RulesPane.qml', 'text: "Window is"', '"Window is"', '"La ventana es"'),
    ('quickshell/RulesPane.qml', 'text: "Opens on tag"', '"Opens on tag"', '"Se abre en etiqueta"'),
    ('quickshell/RulesPane.qml', 'text: "On monitor"', '"On monitor"', '"En monitor"'),
    ('quickshell/RulesPane.qml', 'text: "Toggle key"', '"Toggle key"', '"Tecla de alternancia"'),
    ('quickshell/RulesPane.qml', 'text: "Note"', '"Note"', '"Nota"'),
    ('quickshell/RulesPane.qml', 'sectionTitles', '"Ranuras scratch"', '"Scratchpads"'),
    ('quickshell/RulesPane.qml', '"Ranura scratch " + id', '"Ranura scratch "', '"Scratchpad "'),
    ('quickshell/LauncherPopup.qml', '"update-setup"', '"Configuración de actualización"', '"Actualizar butterdwm"'),
    ('quickshell/Commands.qml', 'label: "Configuración de actualización"', '"Configuración de actualización"', '"Actualizar butterdwm"'),
    # palabras de busqueda del lanzador: se agrega el espanol y se conserva el ingles
    ('quickshell/LauncherPopup.qml', '"wallpaper"', '"background theme colors colors"', '"fondo tema colores background theme colors"'),
    ('quickshell/LauncherPopup.qml', '"share-wifi"', '"qr code password guest phone join wifi wi-fi"', '"código qr contraseña invitado teléfono compartir wifi wi-fi qr code password guest phone join"'),
    ('quickshell/LauncherPopup.qml', '"screenshot-region"', '"capture grab snip select"', '"captura recorte región capture grab snip select"'),
    ('quickshell/LauncherPopup.qml', '"screenshot-full"', '"capture grab whole screen"', '"captura pantalla completa capture grab whole screen"'),
    ('quickshell/LauncherPopup.qml', '"screenshot-copy"', '"capture grab snip copy paste clipboard"', '"captura recorte copiar portapapeles capture grab snip copy paste clipboard"'),
    ('quickshell/LauncherPopup.qml', '"update-setup"', '"butterdwm git pull install upgrade config"', '"actualizar configuración butterdwm git pull install upgrade config"'),
    ('quickshell/LauncherPopup.qml', '"restart-bar"', '"quickshell panel reload"', '"barra panel recargar quickshell panel reload"'),
    ('quickshell/MetricsPopup.qml', 'row.armed ? "Fin "', '"Fin "', '"¿Terminar "'),
    ('quickshell/WallpaperPane.qml', '"No palette from "', '"No palette from "', '"Sin paleta de "'),
    ('quickshell/WallpaperPane.qml', 'is butterpal installed', '" (is butterpal installed? Run the installer)"', '" (¿está instalado butterpal? Ejecuta el instalador)"'),
    ('quickshell/WeatherPopup.qml', '  forecast"', '  forecast"', '  pronóstico"'),
    ('quickshell/RadarView.qml', '" · updating"', '" · updating"', '" · actualizando"'),
    ('quickshell/SettingsPopup.qml', 'close · esc', '  close · esc"', '  cerrar · esc"'),
    ('quickshell/DisplaysPane.qml', '" · off"', '" · off"', '" · apagada"'),
    ('quickshell-network/shell.qml', '"on · external"', '"on · external" : "external"', '"activa · externa" : "externa"'),
    ('quickshell-network/shell.qml', '"connecting to "', '"connecting to "', '"conectando a "'),
    ('quickshell-network/shell.qml', '"tailscale down…"', '"tailscale down…"', '"desconectando Tailscale…"'),
    ('quickshell-network/shell.qml', '"tailscale up…"', '"tailscale up…"', '"conectando Tailscale…"'),
    ('quickshell-network/shell.qml', '"Known networks"', '["Known networks", "Other networks"]', '["Redes conocidas", "Otras redes"]'),
    ('quickshell-network/shell.qml', '"none found"', '"scanning…"', '"escaneando…"'),
    ('quickshell-network/shell.qml', '"none found"', '"none found"', '"ninguna encontrada"'),
    ('quickshell-network/shell.qml', '"none in range"', '"none in range"', '"ninguna al alcance"'),
    ('quickshell-network/shell.qml', '"password, if any"', '"password, if any"', '"contraseña, si tiene"'),
    # pestañas del panel de configuracion: el ancho es fijo y los nombres largos se cortan
    ('quickshell/SettingsPopup.qml', 'key: "keybinds", label:', '"Atajos de teclado"', '"Atajos"'),
    ('quickshell/SettingsPopup.qml', 'key: "wallpaper", label:', '"Fondo de pantalla"', '"Fondo"'),
]
# nombres de los layouts (solo se muestran: Wm.qml indexa por posicion)
for en, es in [('tile', 'mosaico'), ('columns', 'columnas'), ('bstack', 'pila inferior'),
               ('n-row grid', 'rejilla de n filas'), ('deck', 'baraja'),
               ('gapless grid', 'rejilla sin huecos'), ('spiral', 'espiral'),
               ('monocle', 'monóculo'), ('grid', 'rejilla'), ('bstack horiz', 'pila inf. horiz.'),
               ('centered float', 'flotante centrada'), ('horiz grid', 'rejilla horiz.')]:
    T.append(('quickshell/Wm.qml', f'{{ name: "{en}",', f'name: "{en}",', f'name: "{es}",'))

for rel, ancla, en, es in T:
    p = os.path.join(V, rel); L = rd(p); n = 0
    for i, l in enumerate(L):
        if ancla in l and en in l:
            L[i] = l.replace(en, es); n += 1
    if n == 0: problemas.append(f'traduccion sin aplicar: {rel} «{en}»')
    wr(p, L)
print('reglas de traduccion nuevas:', len(T), '| sin aplicar:', sum(1 for x in problemas if x.startswith('traduccion')))

# ---------------------------------------------------------------- 3) parches funcionales
P = [
 ('quickshell/Batteries.qml',
  '    readonly property var laptop: devices.find(d => d.laptop) ?? null\n',
  '    readonly property var laptop: devices.find(d => d.laptop) ?? null\n'
  '\n'
  '    // UPower reports kinds in English, untranslated by the locale\n'
  '    readonly property var kindNames: ({\n'
  '        battery: "Batería", mouse: "Mouse", keyboard: "Teclado",\n'
  '        touchpad: "Touchpad", headset: "Audífonos", headphones: "Audífonos",\n'
  '        "gaming-input": "Control", phone: "Teléfono", pda: "PDA", ups: "UPS",\n'
  '        tablet: "Tableta", camera: "Cámara", wearable: "Wearable",\n'
  '        "media-player": "Reproductor", other: "Dispositivo"\n'
  '    })\n'),
 ('quickshell/Batteries.qml',
  '            if (!head || head[1].endsWith("DisplayDevice"))\n',
  '            // UPower\'s own aggregate is not a battery: on a desktop it\n'
  '            // reports 0% with no level and used to fire a bogus "battery\n'
  '            // low". Match the device path, either spelling.\n'
  '            if (!head || /DisplayDevice|Dispositivo de visualización/.test(head[1]))\n'),
 ('quickshell/Batteries.qml',
  '            if (kind === "line-power" || kind === "" || f.present === "no")\n',
  '            // line-power is the AC adapter; "unknown" is whatever UPower\n'
  '            // can\'t classify (the aggregate lands there too); present=no is\n'
  '            // an empty slot\n'
  '            if (kind === "line-power" || kind === "unknown" || kind === ""\n'
  '                    || f.present === "no")\n'),
 ('quickshell/Batteries.qml',
  '                name: laptop ? "Battery" : (f.model || kind.replace(/-/g, " ")),\n',
  '                name: laptop ? "Batería"\n'
  '                    : (f.model || root.kindNames[kind] || kind.replace(/-/g, " ")),\n'),
 ('quickshell/Batteries.qml',
  '    function isLow(d) {\n',
  '    function isLow(d) {\n'
  '        // 0% with no level is a slot with nothing in it, not a dead battery\n'
  '        if (d.pct <= 0 && d.level === "")\n'
  '            return false\n'),
 ('quickshell/Sys.qml',
  '        onLoaded: root.batteryCharging = text().trim() === "Charging"\n',
  '        // the kernel writes this in English whatever the locale is\n'
  '        onLoaded: root.batteryCharging = /^(Charging|Full)$/.test(text().trim())\n'),
 ('quickshell/Clock.qml',
  '    label: Qt.formatDateTime(clock.date, "ddd MMM d") + "  " + Qt.formatDateTime(clock.date, "h:mm AP")\n',
  '    // Qt.formatDateTime ignores the locale (gives "Fri 23 Oct 6:45 pm"\n'
  '    // even under es_MX); the Date.toLocale* calls do localize\n'
  '    label: clock.date.toLocaleString(Qt.locale(), "ddd d MMM") + "  "\n'
  '        + clock.date.toLocaleTimeString(Qt.locale(), "h:mm a")\n'),
 ('quickshell/RadarView.qml',
  '? Qt.formatTime(new Date(view.frames[view.frame].t * 1000), "h:mm AP") : "")',
  '? new Date(view.frames[view.frame].t * 1000).toLocaleTimeString(Qt.locale(), "h:mm a") : "")'),
 ('quickshell/CalendarPopup.qml',
  '    property date shown: new Date()\n',
  '    property date shown: new Date()\n'
  '\n'
  '    // Spanish names fixed in code: Qt.formatDate ignores the locale, and the\n'
  '    // week starts on Sunday as in Mexico (headers and grid share it)\n'
  '    property int firstDayOfWeek: 0\n'
  '    function monthName(m) {\n'
  '        return ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",\n'
  '                "agosto", "septiembre", "octubre", "noviembre", "diciembre"][m]\n'
  '    }\n'
  '    function weekdayName(d) {\n'
  '        return ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"][d]\n'
  '    }\n'),
 ('quickshell/CalendarPopup.qml',
  'text: Qt.formatDate(root.shown, "MMMM yyyy")',
  'text: root.monthName(root.shown.getMonth()) + " " + root.shown.getFullYear()'),
 ('quickshell/CalendarPopup.qml',
  'text: Qt.locale().dayName((Qt.locale().firstDayOfWeek + index) % 7, Locale.ShortFormat)',
  'text: root.weekdayName((root.firstDayOfWeek + index) % 7)'),
 ('quickshell/CalendarPopup.qml',
  'const offset = (first.getDay() - Qt.locale().firstDayOfWeek + 7) % 7',
  'const offset = (first.getDay() - root.firstDayOfWeek + 7) % 7'),
 ('quickshell-network/shell.qml',
  '                            color: win.status.indexOf("fail") !== -1\n'
  '                                || win.status.indexOf("Error") !== -1 ? Theme.alert : Theme.disabled\n',
  '                            // nmcli speaks the session language: "failed"/"Error"\n'
  '                            // in English, "falló"/"Error" in Spanish\n'
  '                            color: /fail|fall|rror/i.test(win.status) ? Theme.alert : Theme.disabled\n'),
]
PATCHED = set()
for rel, old, new in P:
    p = os.path.join(V, rel); t = open(p, encoding='utf-8').read()
    c = t.count(old)
    if c != 1: problemas.append(f'parche {rel}: el texto original aparece {c} veces'); continue
    open(p, 'w', encoding='utf-8').write(t.replace(old, new)); PATCHED.add(rel)
print('parches funcionales:', len(P), '| archivos:', len(PATCHED))

# ---------------------------------------------------------------- 4) validacion
LET = re.compile(r'[A-Za-zÁÉÍÓÚáéíóúÑñ]{2}')
for root, _, fs in os.walk(V):
    for f in fs:
        if not f.endswith('.qml'): continue
        rel = os.path.relpath(os.path.join(root, f), V)
        up, v4 = rd(os.path.join(U, rel)), rd(os.path.join(V, rel))
        if rel not in PATCHED:
            if len(up) != len(v4): problemas.append(f'{rel}: cambio el numero de lineas'); continue
            for i, (a, b) in enumerate(zip(up, v4), 1):
                if norm(a) != norm(b): problemas.append(f'{rel}:{i}: cambio fuera de comillas')
                for x, y in zip(STR.findall(a), STR.findall(b)):
                    if x != y and not LET.search(x): problemas.append(f'{rel}:{i}: cambio un glifo/simbolo {x}')
                if ("notify-send" in a or "'" in a) and a.count("'") != b.count("'"):
                    problemas.append(f'{rel}:{i}: cambio el numero de comillas simples')
        else:
            sm = difflib.SequenceMatcher(None, [norm(x) for x in up], [norm(x) for x in v4], autojunk=False)
            hunks = [op for op in sm.get_opcodes() if op[0] != 'equal']
            print(f'  {rel}: {len(hunks)} bloque(s) de parche')
print('PROBLEMAS:', len(problemas))
for x in problemas: print('  -', x)

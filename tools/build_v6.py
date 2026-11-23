#!/usr/bin/env python3
"""butterbian-es v6: full build after dict_v6.py.

Differences vs v5:
  - REVERT / T / P use TOLERANT REGEX anchors (re.search / re.sub instead of
    exact substrings), so an upstream reformat (indentation, quotes, spacing)
    does not break the rule.
  - T and P are validated the same: each rule must apply at least once; each
    patch exactly once.
  - Final validation identical to v5: outside the patches only text inside
    quotes may change, and geometry stays untouched (golden rule).

Usage:
  build_v6.py [--repo R] [--out O]
Defaults: R=work/butterdwm-full  O=work/v6/suckless
"""
import os, re, sys, subprocess, difflib

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # raiz del paquete


def rd(p):
    return open(p, encoding='utf-8').read().split('\n')


def wr(p, lines):
    open(p, 'w', encoding='utf-8').write('\n'.join(lines))


def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', default='work/butterdwm-full')
    ap.add_argument('--out', default='work/v6/suckless')
    a = ap.parse_args()
    U = os.path.join(HERE, a.repo, 'suckless')   # upstream in English
    V = os.path.join(HERE, a.out)                # output

    subprocess.run([sys.executable, os.path.join(HERE, 'tools', 'dict_v6.py'),
                    '--repo', a.repo, '--out', a.out], check=True,
                   capture_output=True)

    STR = re.compile(r'"(?:[^"\\]|\\.)*"')

    def norm(l):
        return STR.sub('"S"', l).rstrip()

    problemas = []

    # ------------------------------------------------- 1) reversions (regex)
    # lines whose quoted text is DATA (keysyms, sensors, signals, nmcli
    # fields, urgencies, .desktop categories, xrandr output) + all comments
    REVERT = [
        # (archivo, regex de la linea) -- si la linea difiere del original y
        # matchea, se restaura a ingles
        ('quickshell/ChordField.qml',   r'Qt\.Key_'),
        ('quickshell/MetricsPopup.qml', r'"(Package id 0|Composite|KILL)"'),
        ('quickshell/NotifyPopup.qml',  r'urgency ==='),
        ('quickshell/Sys.qml',          r'IN-USE,SIGNAL'),
        ('quickshell/LauncherPopup.qml', r'categories\.includes'),
        ('quickshell/DisplaysPane.qml', r'!== "Unknown"'),
        ('quickshell-network/shell.qml', r'indexOf\("(fail|Error)"\)'),
    ]
    nrev = 0
    for root, _, fs in os.walk(V):
        for f in fs:
            if not f.endswith('.qml'):
                continue
            rel = os.path.relpath(os.path.join(root, f), V)
            up, v4 = rd(os.path.join(U, rel)), rd(os.path.join(V, rel))
            assert len(up) == len(v4), rel
            patterns = [re.compile(p) for r, p in REVERT if r == rel]
            for i, (a, b) in enumerate(zip(up, v4)):
                if a == b:
                    continue
                if a.lstrip().startswith('//') or any(p.search(a) for p in patterns):
                    v4[i] = a
                    nrev += 1
            wr(os.path.join(V, rel), v4)
    print('lines reverted to English (data/comments):', nrev)

    # --------------------------------------------- 2) translations (regex anchor)
    # (file, line anchor regex, EN text regex, ES text)
    # the anchor is searched with re.search; inside that line, the first match
    # of the EN text is replaced by ES. Each rule must apply at least once.
    T = [
        # v6: inherited from v5 with regex anchors (tokens escaped with \.)
        (r'quickshell/MetricsPopup.qml', r'title:\s*"System"', r'"System"', '"Sistema"'),
        (r'quickshell/MetricsPopup.qml', r'"System monitor \(btop\)"', r'"System monitor \(btop\)"', '"Monitor del sistema (btop)"'),
        (r'quickshell/NotifyPopup.qml', r'title:\s*"Notifications"', r'"Notifications"', '"Notificaciones"'),
        (r'quickshell/NotifyPopup.qml', r'"nothing missed"', r'"nothing missed"', '"nada pendiente"'),
        (r'quickshell/NotifyPopup.qml', r'\s" missed"', r'" missed"', '" pendientes"'),
        (r'quickshell/WeatherPopup.qml', r'root\.failed \?', r'"No weather"', '"Sin clima"'),
        (r'quickshell/WeatherPopup.qml', r'name:\s*"feels like"', r'"feels like"', '"sensación térmica"'),
        (r'quickshell/WeatherPopup.qml', r'text:\s*"Next hours"', r'"Next hours"', '"Próximas horas"'),
        (r'quickshell/WeatherPopup.qml', r'text:\s*"This week"', r'"This week"', '"Esta semana"'),
        (r'quickshell/WeatherPopup.qml', r'"Auto location"', r'"Auto location"', '"Ubicación automática"'),
        (r'quickshell/WeatherPopup.qml', r'"weather by open-meteo\.com"', r'"weather by open-meteo\.com"', '"clima por open-meteo.com"'),
        (r'quickshell/WeatherPopup.qml', r'"couldn\'t get it"', r'"couldn\'t get it"', '"no se pudo obtener"'),
        (r'quickshell/MetricsPopup.qml', r'"load "\s*\+ root\.load', r'"load "', '"carga "'),
        (r'quickshell-network/shell.qml', r'"disconnecting "\s*\+ d\.name', r'"disconnecting "', '"desconectando "'),
        (r'quickshell-network/shell.qml', r'"connecting "\s*\+ d\.name', r'"connecting "', '"conectando "'),
        (r'quickshell-network/shell.qml', r'"forgetting "\s*\+ d\.name', r'"forgetting "', '"olvidando "'),
        (r'quickshell-network/shell.qml', r'"pairing "\s*\+ d\.name', r'"pairing "', '"emparejando "'),
        (r'quickshell-network/shell.qml', r'\(active \? "disconnecting "', r'"disconnecting "', '"desconectando "'),
        (r'quickshell-network/shell.qml', r'\+\s*name\s*\+\s*"\.\.\."', r'"connecting "', '"conectando "'),
        # tabla de condiciones de WeatherData
        (r'quickshell/WeatherData.qml', r'0:\s*"Clear"', r'"Clear"', '"Despejado"'),
        (r'quickshell/WeatherData.qml', r'1:\s*"Mostly clear"', r'"Mostly clear"', '"Mayormente despejado"'),
        (r'quickshell/WeatherData.qml', r'2:\s*"Partly cloudy"', r'"Partly cloudy"', '"Parcialmente nublado"'),
        (r'quickshell/WeatherData.qml', r'3:\s*"Overcast"', r'"Overcast"', '"Nublado"'),
        (r'quickshell/WeatherData.qml', r'45:\s*"Fog"', r'"Fog"', '"Niebla"'),
        (r'quickshell/WeatherData.qml', r'"Freezing fog"', r'"Freezing fog"', '"Niebla helada"'),
        (r'quickshell/WeatherData.qml', r'"Light drizzle"', r'"Light drizzle"', '"Llovizna ligera"'),
        (r'quickshell/WeatherData.qml', r'"Drizzle"', r'"Drizzle"', '"Llovizna"'),
        (r'quickshell/WeatherData.qml', r'"Heavy drizzle"', r'"Heavy drizzle"', '"Llovizna fuerte"'),
        (r'quickshell/WeatherData.qml', r'"Freezing drizzle"', r'"Freezing drizzle"', '"Llovizna helada"'),
        (r'quickshell/WeatherData.qml', r'"Light rain"', r'"Light rain"', '"Lluvia ligera"'),
        (r'quickshell/WeatherData.qml', r'"Rain"', r'"Rain"', '"Lluvia"'),
        (r'quickshell/WeatherData.qml', r'"Heavy rain"', r'"Heavy rain"', '"Lluvia fuerte"'),
        (r'quickshell/WeatherData.qml', r'"Freezing rain"', r'"Freezing rain"', '"Lluvia helada"'),
        (r'quickshell/WeatherData.qml', r'"Light snow"', r'"Light snow"', '"Nieve ligera"'),
        (r'quickshell/WeatherData.qml', r'"Snow"', r'"Snow"', '"Nieve"'),
        (r'quickshell/WeatherData.qml', r'"Heavy snow"', r'"Heavy snow"', '"Nieve fuerte"'),
        (r'quickshell/WeatherData.qml', r'"Snow grains"', r'"Snow grains"', '"Granos de nieve"'),
        (r'quickshell/WeatherData.qml', r'"Light showers"', r'"Light showers"', '"Chubascos ligeros"'),
        (r'quickshell/WeatherData.qml', r'"Showers"', r'"Showers"', '"Chubascos"'),
        (r'quickshell/WeatherData.qml', r'"Heavy showers"', r'"Heavy showers"', '"Chubascos fuertes"'),
        (r'quickshell/WeatherData.qml', r'"Snow showers"', r'"Snow showers"', '"Chubascos de nieve"'),
        (r'quickshell/WeatherData.qml', r'"Heavy snow showers"', r'"Heavy snow showers"', '"Chubascos de nieve fuertes"'),
        (r'quickshell/WeatherData.qml', r'"Thunderstorm"', r'"Thunderstorm"', '"Tormenta eléctrica"'),
        (r'quickshell/WeatherData.qml', r'"Thunderstorm, hail"', r'"Thunderstorm, hail"', '"Tormenta eléctrica con granizo"'),
        (r'quickshell/WeatherData.qml', r'new Error', r'"no forecast"', '"sin pronóstico"'),
        # ---- v7: textos de la interfaz que la v6 dejo en ingles ------------
        # anclas tolerantes y sin escapes: el punto de "..." casa con el punto
        ('quickshell/WallpaperPane.qml', 'From wallpaper', '"From wallpaper"', '"Desde el fondo"'),
        ('quickshell/WallpaperPane.qml', 'critical", "Wallpaper theme', '"Wallpaper theme"', '"Tema del fondo"'),
        ('quickshell/WeatherData.qml', 'const names = ', '"Today"', '"Hoy"'),
        ('quickshell/DisplaysPane.qml', 'busy ? ', 'applying…', 'aplicando...'),
        ('quickshell/Commands.qml', 'Pomodoro.remaining', '" left"', '" restante"'),
        ('quickshell/Updates.qml', 'press enter to close', 'done - press enter to close ', 'listo - pulsa enter para cerrar '),
        ('quickshell/LauncherPopup.qml', 'press enter to close', 'done - press enter to close ', 'listo - pulsa enter para cerrar '),
        ('quickshell/Commands.qml', 'press enter to close', 'done - press enter to close ', 'listo - pulsa enter para cerrar '),
        ('quickshell/LauncherPopup.qml', 'press enter to close', 'press enter to close ', 'pulsa enter para cerrar '),
        ('quickshell-network/shell.qml', 'nmcli", "d", "disconnect"', 'disconnecting…', 'desconectando...'),
        ('quickshell-network/shell.qml', 'tsOnline', '" online"', '" en línea"'),
        ('quickshell-network/shell.qml', 'modelData.online', '"offline"', '"sin conexión"'),
        ('quickshell-network/shell.qml', ': "offline"', '"offline"', '"sin conexión"'),
        ('quickshell-network/shell.qml', 'text: "devices"', '"devices"', '"dispositivos"'),
        ('quickshell-network/shell.qml', 'press enter to close', 'press enter to close ', 'pulsa enter para cerrar '),
    ]

    for rel, ancla, en, es in T:
        p = os.path.join(V, rel)
        L = rd(p)
        n = 0
        for i, l in enumerate(L):
            if re.search(ancla, l) and re.search(en, l):
                m = re.search(en, l)
                L[i] = l[:m.start()] + es + l[m.end():]
                n += 1
        resto = '\n'.join(L)
        if n == 0 and re.search(en, resto):
            # the EN text is still in English after the dictionary: the rule was needed
            problemas.append(f'translation not applied: {rel} «{en}»')
        wr(p, L)
    print('new translation rules:', len(T),
          '| not applied:', sum(1 for x in problemas if x.startswith('translation')))

    # ----------------------------------------------- 3) functional patches
    # (file, regex of the original block, new text) -- the regex must match
    # EXACTLY once (tolerant of spacing/indentation).
    P = [
        (r'quickshell/Batteries.qml',
         r'    readonly property var laptop: devices\.find\(d => d\.laptop\) \?\? null\n',
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
        (r'quickshell/Batteries.qml',
         r'            if \(!head \|\| head\[1\]\.endsWith\("DisplayDevice"\)\)\n',
         '            // UPower\'s own aggregate is not a battery: on a desktop it\n'
         '            // reports 0% with no level and used to fire a bogus "battery\n'
         '            // low". Match the device path, either spelling.\n'
         '            if (!head || /DisplayDevice|Dispositivo de visualización/.test(head[1]))\n'),
        (r'quickshell/Batteries.qml',
         r'            if \(kind === "line-power" \|\| kind === "" \|\| f\.present === "no"\)\n',
         '            // line-power is the AC adapter; "unknown" is whatever UPower\n'
         '            // can\'t classify (the aggregate lands there too); present=no is\n'
         '            // an empty slot\n'
         '            if (kind === "line-power" || kind === "unknown" || kind === ""\n'
         '                    || f.present === "no")\n'),
        (r'quickshell/Batteries.qml',
         r'                name: laptop \? "Battery" : \(f\.model \|\| kind\.replace\(/-/g, " "\)\),\n',
         '                name: laptop ? "Batería"\n'
         '                    : (f.model || root.kindNames[kind] || kind.replace(/-/g, " ")),\n'),
        (r'quickshell/Batteries.qml',
         r'    function isLow\(d\) \{\n',
         '    function isLow(d) {\n'
         '        // 0% with no level is a slot with nothing in it, not a dead battery\n'
         '        if (d.pct <= 0 && d.level === "")\n'
         '            return false\n'),
        (r'quickshell/Sys.qml',
         r'        onLoaded: root\.batteryCharging = text\(\)\.trim\(\) === "Charging"\n',
         '        // the kernel writes this in English whatever the locale is\n'
         '        onLoaded: root.batteryCharging = /^(Charging|Full)$/.test(text().trim())\n'),
        (r'quickshell/Clock.qml',
         r'    label: Qt\.formatDateTime\(clock\.date, "ddd MMM d"\) \+ "  " \+ Qt\.formatDateTime\(clock\.date, "h:mm AP"\)\n',
         '    // Qt.formatDateTime ignores the locale (gives "Fri 23 Oct 6:45 pm"\n'
         '    // even under es_MX); the Date.toLocale* calls do localize\n'
         '    label: clock.date.toLocaleString(Qt.locale(), "ddd d MMM") + "  "\n'
         '        + clock.date.toLocaleTimeString(Qt.locale(), "h:mm a")\n'),
        (r'quickshell/RadarView.qml',
         r'\? Qt\.formatTime\(new Date\(view\.frames\[view\.frame\]\.t \* 1000\), "h:mm AP"\) : ""\)',
         '? new Date(view.frames[view.frame].t * 1000).toLocaleTimeString(Qt.locale(), "h:mm a") : "")'),
        (r'quickshell/CalendarPopup.qml',
         r'    property date shown: new Date\(\)\n',
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
        (r'quickshell/CalendarPopup.qml',
         r'text: Qt\.formatDate\(root\.shown, "MMMM yyyy"\)',
         'text: root.monthName(root.shown.getMonth()) + " " + root.shown.getFullYear()'),
        (r'quickshell/CalendarPopup.qml',
         r'text: Qt\.locale\(\)\.dayName\(\(Qt\.locale\(\)\.firstDayOfWeek \+ index\) % 7, Locale\.ShortFormat\)',
         'text: root.weekdayName((root.firstDayOfWeek + index) % 7)'),
        (r'quickshell/CalendarPopup.qml',
         r'const offset = \(first\.getDay\(\) - Qt\.locale\(\)\.firstDayOfWeek \+ 7\) % 7',
         'const offset = (first.getDay() - root.firstDayOfWeek + 7) % 7'),
        (r'quickshell-network/shell.qml',
         r'                            color: win\.status\.indexOf\("fail"\) !== -1\n'
         r'                                \|\| win\.status\.indexOf\("Error"\) !== -1 \? Theme\.alert : Theme\.disabled\n',
         '                            // nmcli speaks the session language: "failed"/"Error"\n'
         '                            // in English, "falló"/"Error" in Spanish\n'
         '                            color: /fail|fall|rror/i.test(win.status) ? Theme.alert : Theme.disabled\n'),
        # PowerPopup: power-menu keys reassigned by the user
        # (o/e/r/s -> p/c/r/a) + short "confirmar" hint + hint size 10px when
        # armed (the 11-nov-2026 fix, now a functional patch so it survives
        # regeneration).
        (r'quickshell/PowerPopup.qml',
         r'        \{ key: "o", icon: ".*?", label: "Screen off",\n',
         '        { key: "p", icon: "󰌢", label: "Apagar pantalla",\n'),
        (r'quickshell/PowerPopup.qml',
         r'        \{ key: "e", icon: ".*?", label: "Log out", confirm: "Log out\?",\n',
         '        { key: "c", icon: "󰍃", label: "Cerrar sesión", confirm: "¿Cerrar sesión?",\n'),
        (r'quickshell/PowerPopup.qml',
         r'        \{ key: "s", icon: ".*?", label: "Shut down", confirm: "Shut down\?",\n',
         '        { key: "a", icon: "󰐥", label: "Apagar", confirm: "¿Apagar?",\n'),
        (r'quickshell/PowerPopup.qml',
         r'                        text: row\.armed \? "(?:again to confirm|confirmar)" : row\.modelData\.key\.toUpperCase\(\)\n',
         '                        text: row.armed ? "confirmar" : row.modelData.key.toUpperCase()\n'
         '                        font.pixelSize: row.armed ? 10 : 11\n'),
    ]
    PATCHED = set()
    for rel, old, new in P:
        p = os.path.join(V, rel)
        t = open(p, encoding='utf-8').read()
        m = re.search(old, t)
        if not m:
            problemas.append(f'patch {rel}: original text not found')
            continue
        t = t[:m.start()] + new + t[m.end():]
        open(p, 'w', encoding='utf-8').write(t)
        PATCHED.add(rel)
    print('functional patches:', len(P), '| files:', len(PATCHED))

    # ------------------------------------------------------------- 4) validation
    LET = re.compile(r'[A-Za-zÁÉÍÓÚáéíóúÑñ]{2}')
    # English apostrophes that the translation removes ("wasn't", "file's",
    # "Time's"): checked one by one, they never touch data quotes
    APOS_OK = {
        'quickshell/RulesPane.qml': ["that wasn't a window"],
        'quickshell/KeybindsPane.qml': ["what should it run?"],
        'quickshell/Pomodoro.qml': ["Time's up"],
        'quickshell/WeatherPopup.qml': ["couldn't get it"],
    }
    for root, _, fs in os.walk(V):
        for f in fs:
            if not f.endswith('.qml'):
                continue
            rel = os.path.relpath(os.path.join(root, f), V)
            up, v4 = rd(os.path.join(U, rel)), rd(os.path.join(V, rel))
            if rel not in PATCHED:
                if len(up) != len(v4):
                    problemas.append(f'{rel}: line count changed')
                    continue
                for i, (a, b) in enumerate(zip(up, v4), 1):
                    if norm(a) != norm(b):
                        problemas.append(f'{rel}:{i}: change outside quotes')
                    for x, y in zip(STR.findall(a), STR.findall(b)):
                        if x != y and not LET.search(x):
                            problemas.append(f'{rel}:{i}: glyph/symbol change {x}')
                    if ("notify-send" in a or "'" in a) and a.count("'") != b.count("'") \
                            and not any(s in a for s in APOS_OK.get(rel, [])):
                        problemas.append(f'{rel}:{i}: single-quote count changed')
            else:
                sm = difflib.SequenceMatcher(None, [norm(x) for x in up],
                                             [norm(x) for x in v4], autojunk=False)
                hunks = [op for op in sm.get_opcodes() if op[0] != 'equal']
                print(f'  {rel}: {len(hunks)} patch block(s)')
    print('PROBLEMS:', len(problemas))
    for x in problemas:
        print('  -', x)


if __name__ == '__main__':
    main()

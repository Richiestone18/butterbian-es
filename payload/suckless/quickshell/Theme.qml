pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Live palette sourced from the bspwm theme switcher. The switcher rewrites
// polybar/colors.ini (and colors.sh) in place on every switch, so watching
// that file re-colors the bar with no restart — polybar itself can be
// retired without breaking this. Defaults are github_dark placeholders.
//
// The polybar palette is smaller than dwm's xresources+ANSI set, so the
// semantic names below collapse onto it: red→alert, yellow→primary,
// blue/green/cyan/magenta→secondary. Cohesive by construction.
Singleton {
    id: root

    // FileView watching a file, re-read whenever it changes
    component StateFile: FileView { watchChanges: true; onFileChanged: reload() }

    // config root = parent of the running quickshell dir, derived rather
    // than hardcoded so vendored copies (openbox etc.) need no path edits
    readonly property string configDir: {
        let sd = String(Quickshell.shellDir ?? "")
        if (sd.startsWith("file://"))
            sd = sd.slice(7)
        return sd.substring(0, sd.lastIndexOf("/"))
    }

    // bar height (px) and element scale, persisted to plain files (like
    // weather-location) so the tweaks sliders survive restarts
    property int barHeight: 42
    property real barUserScale: 1.0

    // both state files attempted (present or not); bars gate their first
    // map on this to appear once, at final size. The timer failsafe
    // guarantees the bar always maps.
    property int _barStateLoads: 0
    readonly property bool barStateReady: _barStateLoads >= 2
    Timer {
        running: !root.barStateReady
        interval: 1000
        onTriggered: root._barStateLoads = 2
    }

    // `bar toggle` (Super+Ctrl+b) takes every bar off screen and puts it
    // back; the window manager gives the space to the windows meanwhile
    // (the bar's strut goes with it). Not kept across a bar restart, so a
    // restart always brings the bar back.
    property bool barHidden: false

    property color bg: "#0d1117"
    property color altbg: "#161b22"
    property color fg: "#c9d1d9"
    property color border: "#30363d"
    property color primary: "#58a6ff"
    property color secondary: "#8b949e"
    property color alert: "#f85149"
    property color disabled: "#484f58"

    readonly property color accent: primary
    readonly property color selbg: primary
    readonly property color selfg: bg
    readonly property color red: alert
    readonly property color yellow: primary
    readonly property color blue: secondary
    readonly property color green: secondary
    readonly property color cyan: secondary
    readonly property color magenta: secondary

    readonly property string fontFamily: "RobotoMono Nerd Font"

    // Resolution-aware base scale from the outputs' logical short side:
    // 1.0 at 1080p, 1.33 at 1440p, 2.0 at unscaled 4K. A Qt/X11 scale factor
    // (QT_SCALE_FACTOR, the proper hi-dpi fix) shrinks the logical size, so this
    // stays at 1.0 there and nothing is scaled twice. The short side keeps
    // portrait monitors from inflating it; with mixed outputs the smallest
    // wins, so the result doesn't depend on output order and no bar is
    // oversized (the scale slider bumps it up if wanted).
    readonly property real autoScale: {
        const screens = Quickshell.screens
        let side = 0
        for (let i = 0; i < screens.length; i++) {
            const edge = Math.min(screens[i].width, screens[i].height)
            if (side === 0 || edge < side)
                side = edge
        }
        return Math.min(Math.max((side || 1080) / 1080, 0.75), 2.5)
    }

    // The bar's inset from the screen edges. Match it with gappx in
    // config.h so windows sit with the same margin.
    readonly property int edgeInset: Math.round(8 * autoScale)
    // corner radius of the bar window
    readonly property int barRadius: 8

    // In-bar elements follow autoScale × the scale slider. barHeight is a
    // floor: the window grows when scaled modules (26px at 1.0, + inset
    // above + 8px padding) outgrow it.
    readonly property real barScale: autoScale * barUserScale
    readonly property int fontSize: Math.round(13 * barScale)
    readonly property int iconSize: Math.round(15 * barScale)
    readonly property int moduleHeight: Math.round(26 * barScale)
    readonly property int effectiveBarHeight: Math.max(barHeight, moduleHeight + edgeInset + 8)

    // Popups follow the popup size slider (persisted to popup-scale), not
    // the screen resolution. Popout scales each card as a whole, so popups
    // are written at one set of sizes and never scale themselves.
    property real popupUserScale: 1.0
    readonly property real popupScale: popupUserScale

    StateFile {
        path: root.configDir + "/bar-height"
        onLoadFailed: root._barStateLoads++
        onLoaded: {
            root._barStateLoads++
            const v = parseInt(text())
            if (!isNaN(v))
                root.barHeight = Math.min(Math.max(v, 32), 80)
        }
    }

    StateFile {
        path: root.configDir + "/bar-scale"
        onLoadFailed: root._barStateLoads++
        onLoaded: {
            root._barStateLoads++
            const v = parseFloat(text())
            if (!isNaN(v))
                root.barUserScale = Math.min(Math.max(v, 0.7), 2.0)
        }
    }

    // the bar's modules: which zone each sits in (left, center, right),
    // in what order, shown or hidden — the Bar tab's Modules lists.
    // bar-modules holds one "zone key" per line, a "-" before the key
    // for hidden (a bare key means the right zone); no file = the
    // default below. Keys missing from the file (a new module) are
    // appended to their default zone. The launcher
    // (first, left) and the command menu (last, right) are fixed: they
    // host the launcher, settings, power and notification popups.
    readonly property var moduleDefs: [
        { key: "tags",       label: "Etiquetas",           zone: "left" },
        { key: "layout",     label: "Botón de diseño",  zone: "left" },
        { key: "follow",     label: "Seguir",         zone: "left" },
        { key: "title",      label: "Título de ventana",   zone: "center" },
        { key: "media",      label: "Reproduciendo ahora",    zone: "right" },
        { key: "weather",    label: "Clima",        zone: "right" },
        { key: "metrics",    label: "CPU · RAM · disco", zone: "right" },
        { key: "volume",     label: "Volumen",         zone: "right" },
        { key: "network",    label: "Red",        zone: "right" },
        { key: "updates",    label: "Actualizaciones",        zone: "right" },
        { key: "tray",       label: "Bandeja del sistema",           zone: "right" },
        { key: "bell",       label: "Notificaciones",  zone: "right" },
        { key: "clock",      label: "Reloj",          zone: "right" },
        { key: "micmute",    label: "Micrófono silenciado",       zone: "right" },
        { key: "capslock",   label: "Bloq Mayús",      zone: "right" },
        { key: "screenshot", label: "Captura",     zone: "right" }
    ]
    readonly property var zones: ["left", "center", "right"]
    function defaultModules() { return moduleDefs.map(d => ({ key: d.key, zone: d.zone, on: true })) }
    property var modules: defaultModules()
    function parseModules(t) {
        const out = []
        for (let l of t.split("\n")) {
            l = l.trim(); if (l === "") continue
            const parts = l.split(/\s+/)
            let zone = "right", key = parts[0]
            if (parts.length > 1 && zones.indexOf(parts[0]) >= 0) { zone = parts[0]; key = parts[1] }
            const on = key[0] !== "-"; if (!on) key = key.slice(1)
            if (moduleDefs.find(d => d.key === key) && !out.find(m => m.key === key)) out.push({ key: key, zone: zone, on: on })
        }
        for (const d of moduleDefs) if (!out.find(m => m.key === d.key)) out.push({ key: d.key, zone: d.zone, on: true })
        return out
    }
    function setModules(list) {
        modules = list
        writeState("bar-modules", list.map(m => m.zone + " " + (m.on ? "" : "-") + m.key).join("\n"))
    }
    // text and a newline to the state file name, as an argument, never
    // spliced into the shell; after (argv, optional) runs once it's written
    function writeState(name, text, after) {
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$2" > "$1" && shift 2 && exec "$@"',
                                 "sh", configDir + "/" + name, String(text)].concat(after ?? []))
    }
    StateFile {
        path: root.configDir + "/bar-modules"
        onLoaded: root.modules = root.parseModules(text())
        // the file deleted = back to the default
        onLoadFailed: root.modules = root.defaultModules()
    }

    // the Tags strip shows which apps sit on each tag (Bar tab toggle)
    property bool tagIcons: false
    StateFile {
        path: root.configDir + "/tag-icons"
        onLoaded: root.tagIcons = text().trim() === "1"
    }
    // how many empty tags the strip shows (the first N, 0 = all) and
    // whether it hides them all; tags with windows always show (Bar tab)
    property int tagsShown: 0
    StateFile {
        path: root.configDir + "/tags-shown"
        onLoaded: root.tagsShown = Math.max(parseInt(text()) || 0, 0)
        onLoadFailed: root.tagsShown = 0
    }
    property bool tagsHideEmpty: false
    StateFile {
        path: root.configDir + "/tags-hide-empty"
        onLoaded: root.tagsHideEmpty = text().trim() === "1"
        onLoadFailed: root.tagsHideEmpty = false
    }

    // not part of barStateReady: popups aren't open at start
    StateFile {
        path: root.configDir + "/popup-scale"
        onLoadFailed: root.popupUserScale = 1.0
        onLoaded: {
            const v = parseFloat(text())
            root.popupUserScale = isNaN(v) ? 1.0 : Math.min(Math.max(v, 0.8), 2.0)
        }
    }

    StateFile {
        path: root.configDir + "/polybar/colors.ini"
        onLoaded: root.parseIni(text())
    }

    function parseIni(t) {
        const map = {}
        for (const line of t.split("\n")) {
            const m = line.match(/^\s*([A-Za-z-]+)\s*=\s*(#[0-9a-fA-F]{3,8})/)
            if (m)
                map[m[1]] = m[2]
        }
        if (map["background"]) bg = map["background"]
        if (map["background-alt"]) altbg = map["background-alt"]
        if (map["foreground"]) fg = map["foreground"]
        if (map["border"]) border = map["border"]
        if (map["primary"]) primary = map["primary"]
        if (map["secondary"]) secondary = map["secondary"]
        if (map["alert"]) alert = map["alert"]
        if (map["disabled"]) disabled = map["disabled"]
    }
}

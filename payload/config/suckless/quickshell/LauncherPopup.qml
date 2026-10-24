import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// App launcher (Super+space, or left-click the Debian swirl): a grid of
// every installed app, centered on screen. Type to search (name, generic
// name, keywords, program); arrows move, Enter launches, Esc clears and
// then closes. Chips narrow it to Apps or Settings (the .desktop
// "Configuración" category: display, sound, GTK, power and the like — not the
// broader "Sistema", which also claims terminals and file managers);
// Ctrl+Tab cycles them.
// Actions: the bar's own tools (power menu, keybindings, wallpaper,
// screen off, screenshots, updates…) are searchable too, drawn as glyph tiles
// so they read differently from apps. They show up in All once you type,
// and all together under the Actions chip; most just open the popup their
// shortcut opens, over the same IPC.
// With nothing typed the grid is alphabetical, so every app keeps its
// spot. How often and how recently you launch something (launcher-history
// in the config folder) only breaks ties between search matches.
// Windows chip (Super+Tab, or `launcher toggle windows`): every open
// window on every tag and monitor as a thumbnail (winshot reads each
// window's composite pixmap, so windows parked on other tags have one as
// long as picom runs; the app icon otherwise), most recently focused
// first, with a tag badge. Enter raises it and dwm switches to its tag.
// Alt-Tab feel: while it's open on this chip dwm lets go of its key
// grabs (_DWM_SETGRAB), so Tab / Shift+Tab reach the popup and cycle,
// and releasing Super raises the selection — only once you've cycled,
// so opening and letting go of Super to type a filter doesn't jump.
// Icons follow the GTK icon theme: scripts/bar hands it to quickshell
// through QS_ICON_THEME at start.
Popout {
    id: root
    ipcNames: ["launcher"]

    property string query: ""
    property int chip: 0                 // index into chips
    property int selected: 0
    property var history: ({})           // id → {count, last (epoch s)}

    readonly property var chips: ["Todo", "Aplicaciones", "Configuración", "Acciones", "Ventanas"]
    readonly property int windowsChip: 4
    readonly property bool windowsMode: chip === windowsChip
    readonly property int columns: windowsMode ? 3 : 6
    readonly property int cellW: windowsMode ? 224 : 112
    readonly property int cellH: windowsMode ? 184 : 100
    readonly property int thumbW: 208
    readonly property int thumbH: 126
    readonly property string thumbDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/dwm-thumbs"
    property string thumbRun: ""     // folder of the last finished winshot run
    property bool switcher: false   // opened as the window switcher
    property bool cycled: false     // Tab pressed since it opened
    property bool grabsDropped: false
    readonly property string historyFile: Theme.configDir + "/launcher-history"

    // quickshell fills the application list in the background after start,
    // one entry at a time. Bound directly, every arrival re-ran the search
    // and rebuilt the grid: quadratic in the number of apps, 18 s of main
    // thread for 570 .desktop files, the bar undrawn and deaf to ipc the
    // whole time. Coalesced here: the list is taken once the arrivals pause.
    property var apps: []
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { appsRefresh.restart() }
    }
    Timer {
        id: appsRefresh
        interval: 150
        onTriggered: root.apps = DesktopEntries.applications.values.filter(a => !a.noDisplay)
    }
    Component.onCompleted: appsRefresh.start()
    readonly property var results: search(apps, actions, windows, query, chip, history)

    // open windows as launcher entries; tags as "3" or "3+5", the icon
    // looked up by class like the tag icons are
    readonly property var windows: Wm.clients.map(c => {
        const tags = []
        for (let i = 0; i < Wm.tagCount; i++)
            if (c.tags & (1 << i)) tags.push(i + 1)
        const r = Wm.mru.indexOf(c.win)
        return { isWindow: true, id: "win:" + c.win, win: c.win, name: c.title,
                 icon: DesktopEntries.heuristicLookup(c.appid)?.icon ?? "application-x-executable",
                 // with several monitors the badge says which: "2 · 5"
                 tagLabel: (Quickshell.screens.length > 1 ? (c.mon + 1) + " · " : "") + tags.join("+"),
                 mon: c.mon, tagSort: c.mon * 100 + (tags[0] ?? 0),
                 recency: r < 0 ? 9999 : r,
                 keywords: [c.appid], genericName: c.appid, command: [], categories: [] }
    })

    // thumbnails are taken when the chip opens, one winshot run for all
    // each run writes a fresh folder (Qt caches by path, and a file URL
    // can't carry a cache-busting query); the previous run is removed
    Process {
        id: thumbProc
        property string run: ""
        onExited: root.thumbRun = run
    }
    function takeThumbs() {
        const wins = Wm.clients.map(c => c.win)
        if (!wins.length) return
        thumbProc.running = false
        const run = thumbDir + "/" + Date.now()
        thumbProc.run = run
        // only this instance's previous run is removed: each bar has its
        // own launcher and they share the folder
        thumbProc.command = ["sh", "-c", 'p=$1; r=$2; w=$3; shift 3; [ -n "$p" ] && rm -rf "$p"; mkdir -p "$r"; exec winshot "$r" "$w" "$@"',
                             "sh", thumbRun, run, String(thumbW * 2)].concat(wins)
        thumbProc.running = true
    }
    function thumbSource(win) {
        return thumbRun === "" ? "" : "file://" + thumbRun + "/" + win + ".ppm"
    }

    // dwm holds every bound key; let go while the switcher is up so Tab
    // and the Super release arrive here, take them back on close
    readonly property bool wantsKeys: visible && chip === windowsChip
    onWantsKeysChanged: {
        if (wantsKeys === grabsDropped) return
        grabsDropped = wantsKeys
        Wm.setKeyGrab(!wantsKeys)
    }
    onChipChanged: {
        grid.forceLayout()
        if (chip === windowsChip) { Wm.refreshClients(); takeThumbs() }
    }

    // toggle/open with "windows" lands on that chip; a second toggle
    // while it shows closes, like the plain launcher
    function ipc(fn, arg) {
        const toWindows = arg === "windows"
        const wasOpen = visible
        if (fn === "close") visible = false
        else if (fn === "open") visible = true
        else if (toWindows) visible = true
        else visible = !visible
        if (!visible) return
        if (toWindows && chip === windowsChip && fn === "toggle" && wasOpen) {
            // Super+Tab again while open: cycle, like Alt-Tab
            cycled = true
            move(1)
            return
        }
        if (toWindows) {
            switcher = true
            cycled = false
            chip = windowsChip
            if (wasOpen) { Wm.refreshClients(); takeThumbs() }
        }
    }

    // name/keywords feed the same search as apps; run is what Enter does
    // (the launcher has already closed by then)
    readonly property var actions: [
        action("power", "Menú de energía", "󰐥", "apagar reiniciar cerrar sesión salir energía power off shut down reboot",
               () => openPopup("power")),
        action("keybinds", "Atajos de teclado", "󰌌", "teclas atajos ayuda shortcuts hotkeys cheatsheet",
               () => ipcCall("settings", "open", "keybinds")),
        action("settings", "Configuración", "󰒓", "configurar reglas flotante scratchpad barra alto escala ajustes preferencias",
               () => ipcCall("settings", "toggle")),
        action("displays", "Pantallas", "󰍹", "monitor pantalla salida resolución rotar refresco organizar arrange",
               () => ipcCall("settings", "open", "displays")),
        action("wallpaper", "Fondo de pantalla", "󰋩", "colores de fondo y tema",
               () => openPopup("wallpapers")),
        action("layout", "Diseño y ajustes", "󰕰", "mosaico huecos bordes desenfoque sombras animaciones opacidad barra alto escala efectos",
               () => openPopup("layouts")),
        action("commands", "Menú de comandos", "󰘳", "ajustes rápidos luz nocturna mantener despierto no molestar pomodoro temporizador brillo perfil energía",
               () => openPopup("commands")),
        action("weather", "Clima", "󰖐", "pronóstico temperatura ubicación clima forecast",
               () => openPopup("weather")),
        action("network", "Red", "󰖩", "wifi vpn bluetooth ethernet internet red conexión",
               () => run(["scripts/network"])),
        action("share-wifi", "Compartir Wi-Fi", "󰐲", "qr code password guest phone join wifi wi-fi",
               () => run(["scripts/network", "share"])),
        action("screen-off", "Apagar pantalla", "󰌢", "monitor pantalla apagar blank",
               () => run(["scripts/screen-off"])),
        // a beat for the launcher to unmap before flameshot grabs the screen
        action("screenshot-region", "Captura (región)", "󰻛", "capture grab snip select",
               () => Quickshell.execDetached(["sh", "-c", "sleep 0.2; exec \"$0\" region",
                                              Theme.configDir + "/scripts/screenshot"])),
        action("screenshot-full", "Captura (pantalla completa)", "󰻛", "capture grab whole screen",
               () => Quickshell.execDetached(["sh", "-c", "sleep 0.2; exec \"$0\" full",
                                              Theme.configDir + "/scripts/screenshot"])),
        action("screenshot-copy", "Captura (región al portapapeles)", "󰅍", "capture grab snip copy paste clipboard",
               () => Quickshell.execDetached(["sh", "-c", "sleep 0.2; exec \"$0\" copy",
                                              Theme.configDir + "/scripts/screenshot"])),
        action("updates", "Buscar actualizaciones", "󰚰", "actualizar apt paquetes software upgrade",
               () => Quickshell.execDetached(["kitty", "-e", "sh", "-c",
                   "sudo apt update && apt list --upgradable; " +
                   "qs -p \"$0\" ipc call updates check >/dev/null 2>&1; " +
                   "\"$1\" offer; " +
                   "printf '\\ndone - press enter to close '; read _",
                   Theme.configDir + "/quickshell", Theme.configDir + "/scripts/setup-update"])),
        action("update-setup", "Configuración de actualización", "󰊢", "butterdwm git pull install upgrade config",
               () => Quickshell.execDetached(["kitty", "-e", Theme.configDir + "/scripts/setup-update"])),
        action("restart-bar", "Reiniciar la barra", "󰑓", "quickshell panel reload",
               () => run(["scripts/bar", "restart"])),
        action("restart-dwm", "Reiniciar dwm", "󰑐", "gestor de ventanas wm config.h recargar reload",
               () => Wm.restart()),
        action("about", "Acerca de este sistema", "󰋼", "información del sistema fastfetch versión hardware specs",
               () => Quickshell.execDetached(["kitty", "-e", "sh", "-c",
                   "fastfetch || echo 'fastfetch is not installed: sudo apt install fastfetch'; " +
                   "printf '\\npress enter to close '; read _"]))
    ]

    centered: true
    cardWidth: columns * cellW + 2 * cardPadding
    // sized for every app, not the current matches, so typing doesn't
    // make the card jump
    // the switcher sizes to its windows (two rows at least) instead
    cardHeight: Math.min(header.height + 12
                         + Math.max(windowsMode ? 2 : 1, Math.ceil(Math.max(windowsMode ? windows.length : apps.length, 1) / columns)) * cellH
                         + 12 + footer.height + 2 * cardPadding,
                         fitHeight * 0.85)

    onVisibleChanged: {
        if (!visible)
            return
        field.text = ""
        switcher = false
        cycled = false
        chip = 0
        selected = 0
        grid.positionViewAtBeginning()
        // after Popout's own focus grab on open
        Qt.callLater(() => field.forceActiveFocus())
    }
    // the switcher rests on the previously focused window, like Alt-Tab
    onResultsChanged: selected = (chip === windowsChip && switcher && !cycled && query === "" && results.length > 1) ? 1 : 0

    FileView {
        path: root.historyFile
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const h = {}
            for (const l of text().split("\n")) {
                const f = l.split("\t")
                if (f.length === 3)
                    h[f[2]] = { count: Number(f[0]), last: Number(f[1]) }
            }
            root.history = h
        }
    }

    function action(id, name, glyph, keywords, fn) {
        return { isAction: true, id: "action:" + id, name: name, glyph: glyph,
                 keywords: keywords.split(" "), genericName: "", command: [],
                 categories: [], run: fn, family: familyOf(id) }
    }

    // Action tiles are tinted by family so a grid of them scans like app
    // icons do, but the tints come from the theme: the accent's hue
    // turned by a fixed amount per family (and the alert colour for the
    // ones that end your session), so they re-colour with the wallpaper.
    readonly property var families: [
        { key: "system",  label: "Sistema" },
        { key: "capture", label: "Capturas" },
        { key: "network", label: "Red" },
        { key: "scene",   label: "Fondo de pantalla y clima" },
        { key: "power",   label: "Sesión" }
    ]
    // the Actions tab at rest: one family per row group, a label over
    // each, rows padded with blank cells so a group always starts a row
    readonly property bool groupedView: chip === 3 && query === ""
    function grouped(acts) {
        const out = []
        for (const f of families) {
            const items = acts.filter(a => a.family === f.key)
                              .sort((a, b) => a.name.localeCompare(b.name))
            if (!items.length)
                continue
            items[0] = Object.assign({}, items[0], { section: f.label })
            out.push(...items)
            while (out.length % columns)
                out.push({ spacer: true, isAction: false, id: "spacer:" + out.length, name: "" })
        }
        return out
    }
    function familyOf(id) {
        if (/^(power|screen-off)$/.test(id)) return "power"
        if (/^screenshot/.test(id)) return "capture"
        if (/^network$/.test(id)) return "network"
        if (/^(weather|wallpaper)$/.test(id)) return "scene"
        return "system"
    }
    function tint(family) {
        if (family === "power")
            return Theme.alert
        const turn = { system: 0, capture: 150, network: 210, scene: 300 }[family] ?? 0
        const a = Theme.accent
        return Qt.hsla((a.hslHue + turn / 360) % 1,
                       Math.max(a.hslSaturation, 0.45),
                       Math.min(Math.max(a.hslLightness, 0.52), 0.66), 1)
    }

    function openPopup(target) { ipcCall(target, "toggle") }
    function ipcCall(target, fn, arg) {
        const cmd = ["qs", "-p", Theme.configDir + "/quickshell", "ipc", "call", target, fn]
        Quickshell.execDetached(arg !== undefined ? cmd.concat([arg]) : cmd)
    }

    // a script from the config folder: ["scripts/bar", "restart"]
    function run(argv) {
        Quickshell.execDetached([Theme.configDir + "/" + argv[0]].concat(argv.slice(1)))
    }

    function isSettings(a) {
        return a.categories.includes("Configuración")
    }

    // how well one lowercase word matches an app: 0 = not at all
    function wordScore(a, w) {
        const name = a.name.toLowerCase()
        if (name.startsWith(w)) return 100
        if (name.split(/[\s\-_.]+/).some(p => p.startsWith(w))) return 80
        if (name.includes(w)) return 60
        const prog = (a.command[0] ?? "").split("/").pop().toLowerCase()
        if (prog.startsWith(w)) return 50
        const extra = [a.genericName, ...a.keywords].join(" ").toLowerCase()
        if (extra.split(/[\s;,\-]+/).some(p => p.startsWith(w))) return 40
        if (extra.includes(w) || prog.includes(w)) return 25
        return 0
    }

    // launches, fading with time since the last one (half weight a week on)
    function frecency(id, hist) {
        const h = hist[id]
        if (!h) return 0
        const days = (Date.now() / 1000 - h.last) / 86400
        return h.count / (1 + Math.max(days, 0) / 7)
    }

    function search(list, acts, wins, q, chipIndex, hist) {
        const words = q.toLowerCase().split(/\s+/).filter(w => w !== "")
        let pool = list
        if (chipIndex === 1) pool = pool.filter(a => !isSettings(a))
        else if (chipIndex === 2) pool = pool.filter(a => isSettings(a))
        else if (chipIndex === 3) {
            if (!words.length)
                return grouped(acts)
            pool = acts
        }
        else if (chipIndex === windowsChip) {
            if (!words.length)
                return wins.slice().sort((a, b) => a.recency - b.recency || a.tagSort - b.tagSort || a.name.localeCompare(b.name))
            pool = wins
        }
        // All: apps only until you type, so the resting grid stays apps
        else if (words.length) pool = pool.concat(acts)

        if (!words.length)
            return pool.slice().sort((a, b) => a.name.localeCompare(b.name))

        const scored = []
        for (const a of pool) {
            let s = 0
            for (const w of words) {
                const ws = wordScore(a, w)
                if (!ws) { s = 0; break }
                s += ws
            }
            if (s)
                scored.push({ app: a, s: s, f: frecency(a.id, hist) })
        }
        // ties: your launch history first, then the bar's own actions over
        // apps ("shut" is the power menu before any app with it in its
        // keywords), then A–Z
        scored.sort((x, y) => y.s - x.s || y.f - x.f
                    || (y.app.isAction ? 1 : 0) - (x.app.isAction ? 1 : 0)
                    || x.app.name.localeCompare(y.app.name))
        return scored.map(x => x.app)
    }

    function launch(a) {
        if (!a || a.spacer)
            return
        if (a.isWindow) {
            root.visible = false
            Wm.activate(a.win)
            return
        }
        remember(a.id)
        root.visible = false
        if (a.isAction)
            a.run()
        else if (a.runInTerminal)
            Quickshell.execDetached(["kitty", "-e"].concat(a.command))
        else
            a.execute()
    }

    // count + last launch per app id; the whole file is rewritten, one
    // line per app, values passed as arguments (never spliced into sh)
    function remember(id) {
        const h = Object.assign({}, history)
        const prev = h[id] ?? { count: 0, last: 0 }
        h[id] = { count: prev.count + 1, last: Math.floor(Date.now() / 1000) }
        history = h
        const lines = Object.keys(h).map(k => h[k].count + "\t" + h[k].last + "\t" + k)
        Quickshell.execDetached(["sh", "-c", "f=$1; shift; printf '%s\\n' \"$@\" > \"$f\"",
                                 "sh", historyFile].concat(lines))
    }

    function move(d) {
        if (!results.length)
            return
        // the switcher wraps, like Alt-Tab; the app grid stops at the ends
        let i = windowsMode ? (selected + d + results.length) % results.length
                            : Math.max(0, Math.min(results.length - 1, selected + d))
        // over the blank cells that pad a group, in the direction of travel
        const step = d < 0 ? -1 : 1
        while (i >= 0 && i < results.length && results[i].spacer)
            i += step
        if (i < 0 || i >= results.length)
            return
        selected = i
        grid.positionViewAtIndex(selected, GridView.Contain)
    }

    Column {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10

        Rectangle {
            width: parent.width
            height: 36
            radius: 8
            color: Qt.alpha(Theme.fg, 0.06)
            border.width: 1
            border.color: field.activeFocus ? Qt.alpha(Theme.accent, 0.5) : "transparent"

            Txt {
                id: searchIcon
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                color: Theme.accent
                font.pixelSize: 14
            }

            TextInput {
                id: field
                anchors.left: searchIcon.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.fg
                selectionColor: Qt.alpha(Theme.accent, 0.4)
                font.family: Theme.fontFamily
                font.pixelSize: 13
                clip: true
                onTextChanged: root.query = text

                Keys.onPressed: event => {
                    const k = event.key
                    const ctrl = event.modifiers & Qt.ControlModifier
                    if (k === Qt.Key_Tab && ctrl || k === Qt.Key_Backtab && ctrl) {
                        root.chip = (root.chip + (k === Qt.Key_Backtab ? root.chips.length - 1 : 1)) % root.chips.length
                    } else if (k === Qt.Key_Right || k === Qt.Key_Tab) {
                        if (k === Qt.Key_Tab && root.windowsMode) root.cycled = true
                        root.move(1)
                    } else if (k === Qt.Key_Left || k === Qt.Key_Backtab) {
                        if (k === Qt.Key_Backtab && root.windowsMode) root.cycled = true
                        root.move(-1)
                    }
                    else if (k === Qt.Key_Down)
                        root.move(root.columns)
                    else if (k === Qt.Key_Up)
                        root.move(-root.columns)
                    else if (k === Qt.Key_PageDown)
                        root.move(root.columns * Math.max(1, Math.floor(grid.height / root.cellH)))
                    else if (k === Qt.Key_PageUp)
                        root.move(-root.columns * Math.max(1, Math.floor(grid.height / root.cellH)))
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter)
                        root.launch(root.results[root.selected])
                    else if (k === Qt.Key_Escape && text !== "")
                        text = ""
                    else {
                        // typing, and a plain Escape on to Popout (closes)
                        event.accepted = false
                        return
                    }
                    event.accepted = true
                }

                Keys.onReleased: event => {
                    const k = event.key
                    if (root.switcher && root.cycled
                    && (k === Qt.Key_Super_L || k === Qt.Key_Super_R || k === Qt.Key_Meta)) {
                        event.accepted = true
                        root.launch(root.results[root.selected])
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: field.text === ""
                    text: root.chip === root.windowsChip ? "Buscar ventanas abiertas" : "Buscar aplicaciones y acciones"
                    color: Qt.alpha(Theme.fg, 0.35)
                    font: field.font
                }
            }
        }

        Row {
            spacing: 6

            Repeater {
                model: root.chips

                Rectangle {
                    id: chipItem
                    required property string modelData
                    required property int index
                    readonly property bool active: root.chip === index
                    width: chipText.implicitWidth + 20
                    height: 24
                    radius: 12
                    color: active ? Theme.accent
                         : chipMa.containsMouse ? Qt.alpha(Theme.fg, 0.14) : Qt.alpha(Theme.fg, 0.06)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Txt {
                        id: chipText
                        anchors.centerIn: parent
                        text: chipItem.modelData
                        color: chipItem.active ? Theme.bg : Qt.alpha(Theme.fg, 0.8)
                        font.bold: chipItem.active
                    }

                    MouseArea {
                        id: chipMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.chip = chipItem.index
                            field.forceActiveFocus()
                        }
                    }
                }
            }
        }
    }

    GridView {
        id: grid
        anchors.top: header.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.bottomMargin: 12
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cellWidth: root.cellW
        cellHeight: root.groupedView ? root.cellH + 18 : root.cellH
        model: root.results
        currentIndex: root.selected
        highlightFollowsCurrentItem: false

        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            readonly property bool current: root.selected === index
            readonly property bool blank: !!cell.modelData.spacer
            width: root.cellW
            height: grid.cellHeight
            visible: !blank

            // the group's label, over its first row
            Txt {
                visible: !!cell.modelData.section
                x: 6
                y: 2
                width: root.columns * root.cellW - 12
                text: cell.modelData.section ?? ""
                color: Qt.alpha(Theme.fg, 0.45)
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                anchors.topMargin: root.groupedView ? 19 : 3
                radius: 10
                color: cell.current ? Qt.alpha(Theme.fg, 0.12) : "transparent"
                border.width: cell.current ? 1 : 0
                border.color: Qt.alpha(Theme.accent, 0.5)
            }

            // the card is scaled as a whole; the icon is drawn at its
            // on-screen size and scaled back down, so it stays sharp
            Item {
                id: icon
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.groupedView ? 28 : 12
                width: cell.modelData.isWindow ? root.thumbW : 44
                height: cell.modelData.isWindow ? root.thumbH : 44

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 44 * root.s
                    scale: 1 / root.s
                    // windows: the icon only until (or unless) a thumbnail exists
                    visible: !cell.modelData.isAction && !(cell.modelData.isWindow && thumb.status === Image.Ready)
                    source: cell.modelData.isAction ? ""
                          : Quickshell.iconPath(cell.modelData.icon, "application-x-executable")
                }

                // windows: the thumbnail, letterboxed, with the app icon
                // in its corner so a wall of terminals still reads
                Rectangle {
                    anchors.fill: parent
                    visible: !!cell.modelData.isWindow
                    radius: 6
                    color: Qt.alpha(Theme.fg, 0.05)
                    border.width: 1
                    border.color: Qt.alpha(Theme.fg, 0.12)
                    clip: true

                    Image {
                        id: thumb
                        anchors.fill: parent
                        anchors.margins: 1
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                        smooth: true
                        source: cell.modelData.isWindow ? root.thumbSource(cell.modelData.win) : ""
                    }

                    IconImage {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 4
                        implicitSize: 18
                        visible: thumb.status === Image.Ready
                        source: Quickshell.iconPath(cell.modelData.icon ?? "", "application-x-executable")
                    }
                }
            }

            // actions: a tinted tile with the bar's glyph, not an app icon
            Rectangle {
                anchors.fill: icon
                visible: !!cell.modelData.isAction
                readonly property color ink: root.tint(cell.modelData.family)
                radius: 10
                color: Qt.alpha(ink, 0.16)
                border.width: 1
                border.color: Qt.alpha(ink, 0.35)

                Txt {
                    anchors.centerIn: parent
                    text: cell.modelData.glyph ?? ""
                    color: parent.ink
                    font.pixelSize: 22
                }
            }

            // windows: the tag(s) the window sits on, top right of the tile
            Rectangle {
                visible: !!cell.modelData.isWindow
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 7
                width: tagBadge.implicitWidth + 10
                height: 16
                radius: 8
                color: Qt.alpha(Theme.accent, 0.18)
                Txt {
                    id: tagBadge
                    anchors.centerIn: parent
                    text: cell.modelData.tagLabel ?? ""
                    color: Theme.accent
                    font.pixelSize: 10
                    font.bold: true
                }
            }

            Txt {
                anchors.top: icon.bottom
                anchors.topMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 12
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: cell.modelData.name
                color: cell.current ? Theme.accent : Qt.alpha(Theme.fg, 0.85)
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selected = cell.index
                onClicked: root.launch(cell.modelData)
            }
        }

        Txt {
            anchors.centerIn: parent
            visible: root.results.length === 0
            text: root.chip === root.windowsChip
                  ? (root.windows.length === 0 ? "No hay ventanas abiertas" : "Ninguna ventana coincide con \"" + root.query + "\"")
                  : root.apps.length === 0 ? "cargando aplicaciones…" : "Ninguna aplicación coincide con \"" + root.query + "\""
            color: Qt.alpha(Theme.fg, 0.5)
            font.pixelSize: 12
        }
    }

    // only when the grid is taller than the card (768p laptops)
    Rectangle {
        visible: grid.contentHeight > grid.height
        anchors.right: grid.right
        anchors.rightMargin: -8
        y: grid.y + grid.visibleArea.yPosition * grid.height
        width: 3
        height: grid.visibleArea.heightRatio * grid.height
        radius: 2
        color: Qt.alpha(Theme.fg, 0.3)
    }

    Txt {
        id: footer
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        text: (root.windowsMode ? "↵ o soltar super para levantar · tab cambia · " : "↵ abrir · flechas mueven · ")
            + "ctrl+tab " + root.chips[(root.chip + 1) % root.chips.length].toLowerCase() + " · esc cerrar"
        color: Qt.alpha(Theme.fg, 0.35)
        font.pixelSize: 10
    }
}

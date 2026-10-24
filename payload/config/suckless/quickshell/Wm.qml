pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Tag state + control — dwm backend. Requires the quickshell-extbar patch
// (suckless/dwm/patches/dwm-quickshell-extbar.diff): it publishes
// _DWM_SELTAGS (raw tagset bitmask, faithful for multi-tag views) plus
// the layout/tweak atoms below, and accepts _NET_CURRENT_DESKTOP /
// _NET_WM_DESKTOP client messages so xdotool works for actions.
// Occupancy is recomputed from each client's _NET_CLIENT_INFO tag
// bitmask (debounced). The focused window title comes from the same
// two-stage xprop spy as the other backends.
Singleton {
    id: root

    property int seltags: 1
    property int occtags: 0
    property int urgtags: 0     // dwm exports no urgency atom yet
    property int tagCount: 12
    // focused output name, from the focused flag in _DWM_MONTAGS
    property string monitor: ""
    property bool identifyOutputs: false   // Displays tab: name on every screen
    // Per-monitor tag state. _DWM_MONTAGS carries, per dwm monitor in
    // its list order: tagset[0], tagset[1], seltags, x, y, w, h, focused.
    // A screen finds its entry by matching x/y; monState is keyed by
    // screen name and of() hands Tags.qml that entry (root, with the
    // focused monitor's tagset, when nothing matches).
    property var mons: []          // [{num, x, y, w, h, seltags, focused}]
    property var monState: ({})    // screen name -> {num, seltags, occtags, urgtags, tagCount}
    function of(name) { return monState[name] ?? root }
    function monNum(name) { return monState[name]?.num }
    function rebuildMons() {
        const st = {}, apps = {}
        let focused = ""
        for (const s of Quickshell.screens) {
            const m = root.mons.find(m => m.x === s.x && m.y === s.y)
            if (!m) continue
            st[s.name] = { num: m.num, seltags: m.seltags,
                           occtags: (root._occByMon[m.num] ?? 0) & ((1 << root.tagCount) - 1),
                           urgtags: 0, tagCount: root.tagCount }
            apps[s.name] = root._appsByMon[m.num] ?? ({})
            if (m.focused) focused = s.name
        }
        root.monState = st
        root.tagApps = Theme.tagIcons ? apps : ({})
        root.monitor = focused
    }
    Connections {
        target: Quickshell
        function onScreensChanged() { root.rebuildMons() }
    }
    // output name -> tag index -> [{appid, icon, count}] behind the "Tag
    // icons" toggle, built in the same client walk as occupancy from each
    // window's _NET_CLIENT_INFO (tag mask, monitor) and WM_CLASS.
    property var tagApps: ({})
    property var _iconCache: ({})
    function appIcon(appid) {
        if (_iconCache[appid] !== undefined) return _iconCache[appid]
        const entry = DesktopEntries.heuristicLookup(appid)
        const icon = entry?.icon ? Quickshell.iconPath(entry.icon, "application-x-executable") : ""
        _iconCache[appid] = icon
        return icon
    }
    property string title: ""
    property string activeWinId: ""

    // --- layout: _DWM_LAYOUT publishes the current layouts[] index;
    // writing one to _DWM_SETLAYOUT applies it (a root property, so
    // plain xprop drives it and keybind-less layouts are reachable).
    // Order, glyphs, and the mfact/nmaster does-this-layout-use-them
    // flags mirror layouts[] in suckless/dwm/config.h — keep in sync. ---
    readonly property var layouts: [
        { name: "dwindle",        glyph: "󰕴", mfact: true,  nmaster: false },
        { name: "mosaico",        glyph: "󰙀", mfact: true,  nmaster: true  },
        { name: "columnas",       glyph: "󰕭", mfact: false, nmaster: false },
        { name: "centrada",       glyph: "󰕬", mfact: true,  nmaster: true  },
        { name: "flotante",       glyph: "󰕰", mfact: false, nmaster: false },
        { name: "pila inferior",  glyph: "󱒈", mfact: true,  nmaster: true  },
        { name: "rejilla de n filas", glyph: "󰕯", mfact: false, nmaster: true  },
        { name: "baraja",         glyph: "󱇙", mfact: true,  nmaster: true  },
        { name: "rejilla sin huecos", glyph: "󰕫", mfact: false, nmaster: false },
        { name: "espiral",        glyph: "󰪷", mfact: true,  nmaster: false },
        { name: "monóculo",       glyph: "󰕮", mfact: false, nmaster: false },
        { name: "rejilla",        glyph: "󰝘", mfact: false, nmaster: false },
        { name: "pila inf. horiz.", glyph: "󱒉", mfact: true,  nmaster: true  },
        { name: "flotante centrada", glyph: "󰕱", mfact: true,  nmaster: true  },
        { name: "rejilla horiz.", glyph: "󱇚", mfact: false, nmaster: false }
    ]
    property int layoutIndex: 0

    // desktop tweaks, same publish/set mechanism (_DWM_GAPS/_DWM_MFACT/
    // _DWM_NMASTER read, _DWM_SET* written). mfact is a percent; mfact
    // and nmaster are pertag — they follow the focused tag.
    property int gaps: 8
    property int borderpx: 4
    property int mfact: 50
    property int nmaster: 1
    property bool follow: true  // window-follow on tag/monitor send (wfsymbol)

    property bool _followSeen: false
    function _setFollow(f) {
        // notify on real changes only — click and Mod+n both land here
        if (_followSeen && f !== follow)
            Quickshell.execDetached(["notify-send", "-a", "dwm", "-t", "1500",
                "Seguir ventana", f ? "Las ventanas enviadas se siguen" : "Las ventanas enviadas se quedan"])
        _followSeen = true
        follow = f
    }

    function _setProp(atom, v) {
        Quickshell.execDetached(["xprop", "-root", "-f", atom, "32c",
            "-set", atom, String(v)])
    }
    function setLayout(i) { _setProp("_DWM_SETLAYOUT", i) }
    // the keybind editor records a chord: dwm lets go of its key grabs
    // meanwhile (_DWM_SETGRAB 0), or the chord would act instead of arrive
    function setKeyGrab(on) { _setProp("_DWM_SETGRAB", on ? 1 : 0) }
    function cycleLayout(dir) {
        setLayout(((layoutIndex + dir) % layouts.length + layouts.length) % layouts.length)
    }
    function setGaps(v) { _setProp("_DWM_SETGAPS", v) }
    function setBorder(v) { _setProp("_DWM_SETBORDER", v) }
    // picom's effects — blur, shadows, animations and the dimming of
    // unfocused windows (percent, 100 = none) — live in picom.conf, read
    // once here and set through scripts/picom-effects (which has picom
    // reload). Nothing to persist: the file is the state.
    property bool blur: false
    property bool shadows: true
    property bool animations: true
    property int unfocusedOpacity: 100
    Process {
        id: effectsRead
        command: [Theme.configDir + "/scripts/picom-effects"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const [k, v] = line.split("=")
                    if (k === "blur") root.blur = v === "1"
                    else if (k === "shadows") root.shadows = v === "1"
                    else if (k === "animations") root.animations = v === "1"
                    else if (k === "opacity" && !isNaN(parseInt(v))) root.unfocusedOpacity = parseInt(v)
                }
            }
        }
    }
    function setEffect(name, on) {
        root[name] = on
        Quickshell.execDetached([Theme.configDir + "/scripts/picom-effects", name, on ? "1" : "0"])
    }
    function setUnfocusedOpacity(v) {
        unfocusedOpacity = v
        Quickshell.execDetached([Theme.configDir + "/scripts/picom-effects", "opacity", String(v)])
    }
    function setMfact(pct) { _setProp("_DWM_SETMFACT", pct) }
    function setNmaster(n) { _setProp("_DWM_SETNMASTER", n) }
    function toggleFollow() { _setProp("_DWM_SETFOLLOW", follow ? 0 : 1) }

    // xprop -spy silently drops atoms that don't exist when it starts
    // ("no such atom", then never reports them) — and on login the bar
    // can beat dwm's atom seeding. Restart the spy until every atom
    // resolves; bounded, since an unpatched dwm never publishes them.
    property int _spyRetries: 0
    Timer {
        id: spyRetry
        interval: 2000
        onTriggered: { spy.running = false; spy.running = true }
    }
    Process {
        id: spy
        command: ["xprop", "-spy", "-root",
                  "_DWM_SELTAGS", "_DWM_MONTAGS", "_NET_NUMBER_OF_DESKTOPS", "_NET_CLIENT_LIST",
                  "_DWM_LAYOUT", "_DWM_GAPS", "_DWM_MFACT", "_DWM_NMASTER",
                  "_DWM_FOLLOW", "_DWM_BORDER"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("no such atom") >= 0) {
                    if (root._spyRetries++ < 15)
                        spyRetry.restart()
                    return
                }
                // tweak atoms never affect occupancy — parse and bail
                const tweaks = {"_DWM_LAYOUT":  v => root.layoutIndex = v,
                                "_DWM_GAPS":    v => root.gaps = v,
                                "_DWM_BORDER":  v => root.borderpx = v,
                                "_DWM_MFACT":   v => root.mfact = v,
                                "_DWM_NMASTER": v => root.nmaster = v,
                                "_DWM_FOLLOW":  v => root._setFollow(v > 0)}
                const eq = line.indexOf("(")
                const key = eq > 0 ? line.slice(0, eq) : ""
                if (tweaks[key]) {
                    const m = line.match(/= (\d+)/)
                    if (m)
                        tweaks[key](parseInt(m[1]))
                    return
                }
                if (line.indexOf("_DWM_MONTAGS") === 0) {
                    const nums = (line.split("=")[1] ?? "").split(",").map(x => parseInt(x)).filter(x => !isNaN(x))
                    if (nums.length % 8 === 0) {
                        const ms = []
                        for (let i = 0; i < nums.length; i += 8)
                            ms.push({ num: i / 8, x: nums[i + 3], y: nums[i + 4], w: nums[i + 5], h: nums[i + 6],
                                      seltags: nums[i + 2] & 1 ? nums[i + 1] : nums[i], focused: nums[i + 7] === 1 })
                        root.mons = ms
                        root.rebuildMons()
                    }
                    return
                }
                if (line.indexOf("_DWM_SELTAGS") === 0) {
                    const m = line.match(/= (\d+)/)
                    if (m)
                        root.seltags = parseInt(m[1])
                } else if (line.indexOf("_NET_NUMBER_OF_DESKTOPS") === 0) {
                    const m = line.match(/= (\d+)/)
                    if (m)
                        root.tagCount = parseInt(m[1])
                }
                // any of these events can change occupancy (open/close/move)
                occRefresh.restart()
            }
        }
    }

    Timer {
        id: occRefresh
        interval: 150
        onTriggered: {
            occProc.running = false
            occProc.running = true
        }
    }

    property int _occ: 0
    property var _occByMon: ({})
    property var _appsByMon: ({})
    // every managed window, for the launcher's Windows chip:
    // [{win, title, appid, icon, tags, mon}] in _NET_CLIENT_LIST order
    property var clients: []
    // focus history, most recent first: the switcher's resting order
    property var mru: []
    property var _clients: []
    function refreshClients() { occRefresh.restart() }
    // raise through dwm (_DWM_SETACTIVE): xdotool windowactivate would
    // first switch the focused monitor's tag as well
    function activate(win) { _setProp("_DWM_SETACTIVE", parseInt(win)) }
    Process {
        id: occProc
        // one line per client: id, then _NET_CLIENT_INFO, WM_CLASS and
        // _NET_WM_NAME joined (the title last: it may hold anything)
        command: ["sh", "-c",
            "for w in $(xprop -root _NET_CLIENT_LIST 2>/dev/null | grep -oE '0x[0-9a-f]+'); do " +
            "printf '%s ' $w; xprop -id $w _NET_CLIENT_INFO WM_CLASS _NET_WM_NAME 2>/dev/null | tr '\\n' ' '; echo; done"]
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/^(0x[0-9a-f]+) .*_NET_CLIENT_INFO\(CARDINAL\) = (\d+), (\d+)/)
                if (!m) return
                const win = m[1], t = parseInt(m[2]), mon = parseInt(m[3])
                root._occ |= t
                root._occByMon[mon] = (root._occByMon[mon] ?? 0) | t
                const c = line.match(/WM_CLASS\(STRING\) = "[^"]*", "([^"]*)"/)
                const appid = c ? c[1] : ""
                const n = line.match(/_NET_WM_NAME\(UTF8_STRING\) = "(.*)" $/)
                const title = n ? n[1].replace(/\\"/g, '"').replace(/\\\\/g, "\\") : appid
                root._clients.push({ win: win, title: title, appid: appid,
                                     icon: appid ? root.appIcon(appid) : "", tags: t, mon: mon })
                if (!Theme.tagIcons) return
                if (!appid) return
                if (!root._appsByMon[mon]) root._appsByMon[mon] = {}
                const apps = root._appsByMon[mon]
                for (let i = 0; i < root.tagCount; i++) {
                    if (!(t & (1 << i))) continue
                    if (!apps[i]) apps[i] = []
                    const hit = apps[i].find(a => a.appid === appid)
                    if (hit) hit.count++
                    else apps[i].push({ appid: appid, icon: root.appIcon(appid), count: 1 })
                }
            }
        }
        onRunningChanged: {
            if (running) { root._occ = 0; root._occByMon = ({}); root._appsByMon = ({}); root._clients = []; return }
            // mask off scratchpad/hidden tag bits above the visible tags
            root.occtags = root._occ & ((1 << root.tagCount) - 1)
            root.clients = root._clients
            root.rebuildMons()
        }
    }
    Connections {
        target: Theme
        function onTagIconsChanged() { occRefresh.restart() }
    }

    // --- focused window title ---

    Process {
        command: ["xprop", "-spy", "-root", "_NET_ACTIVE_WINDOW"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/window id # (0x[0-9a-fA-F]+)/)
                const id = m ? m[1] : ""
                if (id !== root.activeWinId) {
                    root.activeWinId = id
                    if (id !== "")
                        root.mru = [id].concat(root.mru.filter(w => w !== id)).slice(0, 64)
                    titleSpy.running = false
                    if (id !== "")
                        titleSpy.running = true
                    else
                        root.title = ""
                }
            }
        }
    }

    Process {
        id: titleSpy
        command: ["xprop", "-spy", "-id", root.activeWinId, "_NET_WM_NAME"]
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/= "([\s\S]*)"$/)
                if (m)
                    root.title = m[1].replace(/\\"/g, '"').replace(/\\\\/g, "\\")
            }
        }
    }

    // --- actions (handled by the extbar patch's clientmessage additions) ---

    // A bar acts on its own output: when that isn't the focused monitor,
    // ask dwm to focus it first (_DWM_SETMON) in the same shell so the
    // two land in order.
    function onMon(mon, cmd) {
        const num = monNum(mon)
        const pre = (num !== undefined && mon !== monitor)
            ? "xprop -root -f _DWM_SETMON 32c -set _DWM_SETMON " + num + "; " : ""
        Quickshell.execDetached(["sh", "-c", pre + cmd])
    }
    function viewTag(i, mon) { onMon(mon, "xdotool set_desktop " + i) }
    function toggleViewTag(i, mon) { viewTag(i, mon) }
    function sendToTag(i, mon) { onMon(mon, "xdotool getactivewindow set_desktop_for_window " + i) }
    function cycleTag(dir, mon) { onMon(mon, "xdotool set_desktop --relative -- " + dir) }

    // processes this session can't lose: the metrics card won't offer to
    // end them (it adds the ones every setup shares). xsettingsd feeds GTK
    // its theme, unclutter hides the idle pointer.
    readonly property var sessionProcs: /^(dwm|Xorg|X|picom|xsettingsd|unclutter|slstatus|xss-lock)$/
    // scripts/power opens PowerPopup over IPC (rofi when the bar is down)
    function openPowerMenu() {
        Quickshell.execDetached([Theme.configDir + "/scripts/power"])
    }
    function logout() { Quickshell.execDetached(["pkill", "-x", "dwm"]) }
    // SIGHUP: dwm execs itself, keeping tags and windows (Mod+Shift+r).
    // It acts once its event loop wakes, so a root property write follows.
    function restart() {
        Quickshell.execDetached(["sh", "-c",
            "pkill -HUP -x dwm; xprop -root -f _DWM_WAKE 32c -set _DWM_WAKE 1"])
    }
}

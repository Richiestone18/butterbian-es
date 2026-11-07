import QtQuick
import Quickshell
import Quickshell.Io

// Settings (Super+/ opens it on Keybinds; Settings in the command menu and
// the launcher): a floating window, the tabs down the left and the tab's
// content on the right. scripts/rules-gen floats it by its title, and dwm
// moves and resizes it like any other window. This
// is where the setup is configured; the bar's modules and their popups
// keep state and quick actions. Apply at the foot of the strip shows once
// the Keybinds or Rules tab has saved something dwm isn't running yet; it
// rebuilds and restarts dwm in place (scripts/keybinds-apply regenerates
// keys.h and rules.h both).
// IPC: `settings toggle | close | open <tab>`; a tab's own name (keybinds,
// rules, layouts / tweaks, wallpapers, displays) toggles or opens that
// tab, and `wallpapers random | set <path>` go to the Wallpaper pane.
FloatingWindow {
    id: root
    title: "butterdwm settings"
    color: Theme.bg
    visible: false

    // content lays out at 1080p sizes and scales whole, like the popups
    readonly property real s: Theme.popupScale
    minimumSize: Qt.size(760 * s, 480 * s)

    readonly property var ipcNames: ["settings", "keybinds", "rules", "layouts", "tweaks", "wallpapers", "displays"]
    Connections {
        target: BarIpc
        function onCall(target, fn, arg) {
            if (root.ipcNames.indexOf(target) >= 0)
                root.ipc(fn, arg, target)
        }
    }

    // focused: toggling closes it; open on another tag or output: toggling
    // brings it to where you are. An item has active focus only while its
    // window is the active one, so this holds on any WM.
    readonly property bool focused: scope.activeFocus
    // the first open sizes it to the focused output (the first screen when
    // Wm can't tell); later opens keep the size it was given, shrunk to fit
    // a smaller output without forgetting it
    property size wanted: Qt.size(0, 0)
    property size applied: Qt.size(0, 0)
    function show() {
        if (visible && focused)
            return
        if (visible) {
            // open elsewhere: unmapped first, mapped a tick later (the same
            // tick is a no-op), sized while unmapped; dwm maps it on the
            // focused monitor's current tag
            visible = false
            Qt.callLater(show)
            return
        }
        const scr = Quickshell.screens.find(o => o.name === Wm.monitor) ?? Quickshell.screens[0]
        const sw = scr ? scr.width : 1920
        const sh = scr ? scr.height : 1080
        if (wanted.width === 0)
            wanted = Qt.size(Math.round(Math.min(1560, sw / s - 64) * s), Math.round(sh * 0.8))
        else if (width !== applied.width || height !== applied.height)
            wanted = Qt.size(width, height)   // resized since the last open
        applied = Qt.size(Math.min(wanted.width, sw - 64 * s), Math.min(wanted.height, Math.round(sh * 0.9)))
        implicitWidth = applied.width
        implicitHeight = applied.height
        forget.running = true
    }
    // dwm keeps a window's tags and monitor in _NET_CLIENT_INFO and restores
    // them when it maps again: dropped first, so it opens on the current tag
    // of the focused output
    Process {
        id: forget
        command: ["xprop", "-name", root.title, "-remove", "_NET_CLIENT_INFO"]
        onExited: root.visible = true
    }
    // dwm's close (Super+q) ends the window without telling `visible`
    onClosed: visible = false

    function ipc(fn, arg, target) {
        if (target === "wallpapers" && fn === "random") { wallpaper.applyRandom(); return }
        if (target === "wallpapers" && fn === "set") { wallpaper.apply(arg); return }
        const own = { keybinds: "keybinds", rules: "rules", layouts: "layout", tweaks: "layout", wallpapers: "wallpaper", displays: "displays" }
        if (fn === "close") {
            visible = false
        } else if (fn === "toggle") {
            const i = target in own ? tabs.findIndex(t => t.key === own[target]) : tab
            if (visible && focused && tab === i) { visible = false; return }
            tab = i
            show()
        } else if (fn === "open") {
            const i = tabs.findIndex(t => t.key === (target in own ? own[target] : arg))
            tab = i < 0 ? 0 : i
            show()
        }
    }
    function takeFocus() { inner.forceActiveFocus() }

    property int tab: 0
    readonly property var tabs: [
        { key: "keybinds", label: "Atajos", icon: "󰌌" },
        { key: "rules",    label: "Reglas",    icon: "󰖲" },
        { key: "layout",   label: "Diseño",   icon: "󰕰" },
        { key: "bar",      label: "Barra",      icon: "󰍜" },
        { key: "wallpaper", label: "Fondo", icon: "󰸉" },
        { key: "displays", label: "Pantallas", icon: "󰍹" }
    ]
    readonly property bool dirty: keybinds.dirty || rules.dirty
    readonly property int stripWidth: 150

    // the panes that hear shown() and hidden(), by tab key; the Rules pane
    // keeps its editor while the panel is closed for its window pick
    readonly property var panes: ({ keybinds: keybinds, rules: rules, wallpaper: wallpaper, displays: displays })
    function sync(hide) {
        if (hide)
            for (const k in panes)
                if (k !== "rules" || !rules.pickFor) panes[k].hidden()
        if (visible)
            panes[tabs[tab].key]?.shown()
    }
    onVisibleChanged: {
        if (visible)
            takeFocus()
        sync(!visible)
    }
    // Ctrl+PageDown / Ctrl+PageUp walk the tabs (Ctrl+Tab is the
    // Keybinds tab's chips). Window shortcuts: they fire before the
    // search field or the wallpaper grid can swallow the key.
    Shortcut { sequences: ["Ctrl+PgDown"]; onActivated: root.tab = (root.tab + 1) % root.tabs.length }
    Shortcut { sequences: ["Ctrl+PgUp"]; onActivated: root.tab = (root.tab + root.tabs.length - 1) % root.tabs.length }
    onTabChanged: {
        takeFocus()
        if (visible)
            sync(true)
    }
    // Apply is shared: keybinds-apply regenerates both files
    function apply() {
        rules.dirty = false
        keybinds.apply()
    }

    FocusScope {
        id: scope
        width: parent.width / root.s
        height: parent.height / root.s
        scale: root.s
        transformOrigin: Item.TopLeft
        focus: true

        Item {
            id: inner
            anchors.fill: parent
            anchors.margins: 14
            focus: true
            Keys.onEscapePressed: root.visible = false

            // --- tab strip ---
            Column {
                id: strip
                width: root.stripWidth
                spacing: 4

                Repeater {
                    model: root.tabs

                    ListRow {
                        required property var modelData
                        required property int index
                        glyph: modelData.icon
                        text: modelData.label
                        active: root.tab === index
                        height: 36
                        leftMargin: 12
                        glyphWidth: 18
                        glyphSize: 15
                        fontSize: 13
                        activeColor: Theme.selbg
                        glyphInk: active ? Theme.selfg : Theme.cyan
                        ink: active ? Theme.selfg : Qt.alpha(Theme.fg, 0.9)
                        onClicked: root.tab = index
                    }
                }
            }

            // saved changes dwm isn't running yet: one click rebuilds it
            Btn {
                visible: root.dirty
                anchors.left: parent.left
                anchors.bottom: closeHint.top
                anchors.bottomMargin: 10
                width: root.stripWidth
                height: 36
                text: "󰑓  Aplicar"
                active: true
                fontSize: 12
                activeHoverColor: Qt.lighter(Theme.accent, 1.1)
                fadeMs: 0
                onClicked: root.apply()
            }
            // no click-outside here: this, Esc, or dwm's close
            Txt {
                id: closeHint
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 12
                anchors.bottomMargin: 10
                text: "󰅖  cerrar · esc"
                color: closeArea.containsMouse ? Theme.fg : Qt.alpha(Theme.fg, 0.35)
                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.visible = false
                }
            }

            // divider
            Rectangle {
                x: root.stripWidth + 10
                width: 1
                height: parent.height
                color: Qt.alpha(Theme.fg, 0.1)
            }

            // --- the tabs' content ---
            Item {
                id: content
                x: root.stripWidth + 24
                width: parent.width - x
                height: parent.height

                KeybindsPane {
                    id: keybinds
                    popup: root
                    anchors.fill: parent
                    visible: root.tab === 0
                }

                RulesPane {
                    id: rules
                    popup: root
                    anchors.fill: parent
                    visible: root.tab === 1
                }

                Flickable {
                    visible: root.tab === 2
                    anchors.fill: parent
                    contentHeight: layoutTweaks.implicitHeight
                    clip: true
                    LayoutTweaks { id: layoutTweaks; width: Math.min(420, parent.width) }
                }

                Flickable {
                    visible: root.tab === 3
                    anchors.fill: parent
                    contentHeight: barTweaks.implicitHeight
                    clip: true
                    BarTweaks { id: barTweaks; width: Math.min(420, parent.width) }
                }

                WallpaperPane {
                    id: wallpaper
                    popup: root
                    anchors.fill: parent
                    visible: root.tab === 4
                }

                DisplaysPane {
                    id: displays
                    anchors.fill: parent
                    visible: root.tab === 5
                }
            }
        }
    }
}

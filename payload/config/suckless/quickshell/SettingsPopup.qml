import QtQuick
import Quickshell
import Quickshell.Io

// Settings panel (Super+/ opens it on Atajos de teclado; Settings in the command
// menu and the launcher): one centered card with the tabs down the left
// — Atajos de teclado, Reglas, Layout, Bar — and the tab's content on the right.
// This is where the setup is configured; the bar's modules and their
// popups stay what they are (state and quick actions) and nothing moves
// in here from them. Apply at the foot of the tab strip lights once a
// tab has saved something dwm isn't running yet; it rebuilds and
// restarts dwm in place (scripts/keybinds-apply regenerates keys.h and
// rules.h both).
// IPC: `settings toggle`, `settings open <tab>`; `keybinds toggle` opens
// the Atajos de teclado tab (parity with the other ports' keybinds popup).
Popout {
    id: root
    // the retired popups' names still answer: layouts / tweaks open the
    // Layout tab, keybinds the Atajos de teclado tab, wallpapers the Fondo de pantalla tab
    // (random and set go to the pane; it opens the panel for the
    // extraction if need be)
    ipcNames: ["settings", "keybinds", "layouts", "tweaks", "wallpapers", "displays"]
    function ipc(fn, arg, target) {
        if (target === "wallpapers" && fn === "random") { wallpaper.applyRandom(); return }
        if (target === "wallpapers" && fn === "set") { wallpaper.apply(arg); return }
        const own = { keybinds: "keybinds", layouts: "layout", tweaks: "layout", wallpapers: "wallpaper", displays: "displays" }
        if (target in own && (fn === "toggle" || fn === "open")) {
            const i = tabs.findIndex(t => t.key === own[target])
            if (fn === "toggle" && visible && tab === i) { visible = false; return }
            tab = i
            visible = true
            return
        }
        if (fn === "toggle") {
            visible = !visible
        } else if (fn === "close") {
            visible = false
        } else if (fn === "open") {
            const i = tabs.findIndex(t => t.key === arg)
            tab = i < 0 ? 0 : i
            visible = true
        }
    }

    property int tab: 0
    readonly property var tabs: [
        { key: "keybinds", label: "Atajos de teclado", icon: "󰌌" },
        { key: "rules",    label: "Reglas",    icon: "󰖲" },
        { key: "layout",   label: "Diseño",   icon: "󰕰" },
        { key: "bar",      label: "Barra",      icon: "󰍜" },
        { key: "wallpaper", label: "Fondo de pantalla", icon: "󰸉" },
        { key: "displays", label: "Pantallas", icon: "󰍹" }
    ]
    readonly property bool dirty: keybinds.dirty || rules.dirty
    readonly property int stripWidth: 150

    centered: true
    cardWidth: Math.min(1560, fitWidth - 64)
    cardHeight: fitHeight * 0.8

    onVisibleChanged: {
        if (visible) {
            if (tab === 0) keybinds.shown()
            if (tab === 1) rules.shown()
            if (tab === 4) wallpaper.shown()
            if (tab === 5) displays.shown()
        } else {
            keybinds.hidden()
            if (!rules.pickFor) rules.hidden()
            wallpaper.hidden()
            displays.hidden()
        }
    }
    // Ctrl+PageDown / Ctrl+PageUp walk the tabs (Ctrl+Tab is the
    // Atajos de teclado tab's chips). Window shortcuts: they fire before the
    // search field or the wallpaper grid can swallow the key.
    Shortcut { sequences: ["Ctrl+PgDown"]; onActivated: root.tab = (root.tab + 1) % root.tabs.length }
    Shortcut { sequences: ["Ctrl+PgUp"]; onActivated: root.tab = (root.tab + root.tabs.length - 1) % root.tabs.length }
    onTabChanged: {
        takeFocus()
        if (!visible)
            return
        keybinds.hidden()
        rules.hidden()
        wallpaper.hidden()
        displays.hidden()
        if (tab === 0) keybinds.shown()
        if (tab === 1) rules.shown()
        if (tab === 4) wallpaper.shown()
        if (tab === 5) displays.shown()
    }
    // Apply is shared: keybinds-apply regenerates both files
    function apply() {
        rules.dirty = false
        keybinds.apply()
    }

    // --- tab strip ---
    Column {
        id: strip
        width: root.stripWidth
        spacing: 4

        Repeater {
            model: root.tabs

            Rectangle {
                id: tabItem
                required property var modelData
                required property int index
                readonly property bool active: root.tab === index
                width: strip.width
                height: 36
                radius: 8
                color: active ? Theme.selbg
                     : tabMa.containsMouse ? Qt.alpha(Theme.fg, 0.12) : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    spacing: 10
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        horizontalAlignment: Text.AlignHCenter
                        text: tabItem.modelData.icon
                        color: tabItem.active ? Theme.selfg : Theme.cyan
                        font.pixelSize: 15
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tabItem.modelData.label
                        color: tabItem.active ? Theme.selfg : Qt.alpha(Theme.fg, 0.9)
                        font.pixelSize: 13
                        font.bold: tabItem.active
                    }
                }
                MouseArea {
                    id: tabMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.tab = tabItem.index
                }
            }
        }
    }

    // saved changes dwm isn't running yet: one click rebuilds it
    Rectangle {
        id: applyBtn
        visible: root.dirty
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: root.stripWidth
        height: 36
        radius: 8
        color: applyMa.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent
        Txt {
            anchors.centerIn: parent
            text: "󰑓  Aplicar"
            color: Theme.bg
            font.bold: true
            font.pixelSize: 12
        }
        MouseArea {
            id: applyMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.apply()
        }
    }
    Txt {
        visible: !root.dirty
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.bottomMargin: 10
        text: "Esc cierra"
        color: Qt.alpha(Theme.fg, 0.35)
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
            popup: root
            anchors.fill: parent
            visible: root.tab === 5
        }
    }
}

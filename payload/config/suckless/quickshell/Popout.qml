import QtQuick
import Quickshell
import Quickshell.Io

// Shared shell for every bar popup: a fullscreen transparent catcher
// window with the styled card anchored under its bar item. Clicking
// anywhere outside the card closes it; Escape too (when X grants the
// popup key focus). All popups use this, so chrome and behavior stay
// identical.
// dwm hands keyboard focus only to its clients, never to these
// override-redirect windows, so a popup that opens asks scripts/popup-focus
// to focus it (Escape, the launcher's search, the weather field). Closing
// it gives the keyboard back to the client.
// Without a compositor the "transparent" catcher would render opaque
// black — blacking out the whole screen — so when picom isn't running
// (Sys.composited) the window degrades to card-only: same card, same
// spot, no catcher. Click-outside close is lost in that mode; Escape
// and the module's own toggle still close.
// Multi-monitor: the catcher covers the output whose bar owns the anchor
// item, and all offsets are relative to that output, not the X root.
PopupWindow {
    id: root
    function takeFocus() { inner.forceActiveFocus() }

    property Item anchorItem
    property real cardWidth: 300
    property real cardHeight: 300
    readonly property real cardPadding: 14
    // right-edge panel mode (control center) instead of centered-under-anchor
    property bool alignRight: false
    // floating in the middle of the output instead: for popups summoned
    // from the keyboard (launcher, power) rather than from a bar module
    property bool centered: false

    readonly property bool catcher: Sys.composited

    // the whole card scales (Theme.popupScale), so popups lay themselves
    // out at 1080p sizes; these are the output's size in those units, for
    // popups that size themselves to the screen (launcher)
    readonly property real s: Theme.popupScale
    readonly property real fitWidth: screenW / s
    readonly property real fitHeight: screenH / s
    // the card's on-screen size
    readonly property real vw: cardWidth * s
    readonly property real vh: cardHeight * s

    // `qs ipc call <name> toggle`: BarIpc passes the call to every screen's
    // copy of this popup; one answers. The extbar patch doesn't publish the
    // focused monitor, so while Wm.monitor is empty that's the first
    // output's bar. Popups with more verbs than toggle replace ipc().
    property var ipcNames: []
    readonly property bool onFocusedOutput: !barScreen
        || (Wm.monitor !== "" ? barScreen.name === Wm.monitor
                              : barScreen === Quickshell.screens[0])
    // toggle, or open / close outright (scripts that must not guess)
    function ipc(fn, arg) {
        if (fn === "toggle") visible = !visible
        else if (fn === "open") visible = true
        else if (fn === "close") visible = false
    }
    Connections {
        target: BarIpc
        enabled: root.ipcNames.length > 0
        function onCall(target, fn, arg) {
            if (root.ipcNames.indexOf(target) >= 0 && root.onFocusedOutput)
                root.ipc(fn, arg, target)
        }
    }

    default property alias content: inner.data

    // X11: take the keyboard while open (see above); off for a popup
    // that should leave the focused client's keys alone
    property bool takesKeys: true
    Process {
        id: focusProc
        command: [Theme.configDir + "/scripts/popup-focus"]
    }
    Process {
        id: releaseProc
        command: [Theme.configDir + "/scripts/popup-focus", "release"]
    }

    // the output whose bar owns the anchor item (falls back to the first)
    readonly property var barScreen: anchorItem?.QsWindow?.window?.screen
        ?? (Quickshell.screens.length ? Quickshell.screens[0] : null)
    readonly property real screenX: barScreen?.x ?? 0
    readonly property real screenY: barScreen?.y ?? 0
    readonly property real screenW: barScreen?.width ?? 1920
    readonly property real screenH: barScreen?.height ?? 1080

    visible: false
    color: "transparent"

    anchor.item: anchorItem
    // catcher mode: stretch the window over the whole screen so outside
    // clicks land on it; card-only mode: the window IS the card
    anchor.rect.x: catcher ? (anchorItem ? screenX - anchorItem.mapToGlobal(0, 0).x : 0)
                           : uOffsetX
    anchor.rect.y: catcher ? (anchorItem ? screenY - anchorItem.mapToGlobal(0, 0).y : 0)
                           : uOffsetY
    implicitWidth: catcher ? screenW : vw
    implicitHeight: catcher ? screenH : vh

    // anchor's position on its output, captured at open time — mapToGlobal
    // in a static binding evaluates before the item is mapped and returns 0
    property real ax: 0
    property real ay: 0
    // card-only mode: window offset from the anchor item, clamped to
    // the screen like the catcher-mode card
    property real uOffsetX: 0
    property real uOffsetY: 0

    onVisibleChanged: {
        if (visible && anchorItem) {
            const p = anchorItem.mapToGlobal(0, 0)
            ax = p.x - screenX
            ay = p.y - screenY
            const sw = screenW
            const desired = alignRight ? sw - vw - 8
                : centered ? Math.round((sw - vw) / 2)
                : Math.min(Math.max(ax + anchorItem.width / 2 - vw / 2, 8),
                           sw - vw - 8)
            uOffsetX = desired - ax
            uOffsetY = centered ? Math.round((screenH - vh) / 2) - ay
                                : anchorItem.height + 12
            inner.forceActiveFocus()
            enterAnim.restart()
            if (takesKeys)
                focusProc.running = true
        } else if (!visible && takesKeys) {
            releaseProc.running = true
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    Rectangle {
        id: card

        // placed by its on-screen (scaled) size
        scale: root.s
        transformOrigin: Item.TopLeft

        x: !root.catcher ? 0
         : root.alignRight ? root.width - root.vw - 8
         : root.centered ? Math.round((root.width - root.vw) / 2)
         : Math.min(Math.max(root.ax + (root.anchorItem?.width ?? 0) / 2 - root.vw / 2, 8),
                    root.width - root.vw - 8)
        y: !root.catcher ? 0
         : root.centered ? Math.round((root.height - root.vh) / 2)
         : root.ay + (root.anchorItem?.height ?? 0) + 12

        transform: Translate { id: slide; y: 0 }

        ParallelAnimation {
            id: enterAnim
            NumberAnimation { target: slide; property: "y"; from: -10; to: 0
                              duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: card; property: "opacity"; from: 0; to: 1
                              duration: 160 }
        }
        width: root.cardWidth
        height: root.cardHeight
        // centered popups (launcher, power) look like a floating window:
        // solid accent border, the bar's corner radius. Drop-downs stay
        // light: thin border, rounder.
        radius: root.centered ? Theme.barRadius : 12
        color: Theme.bg
        border.width: root.centered ? 2 : 1
        border.color: root.centered ? Theme.accent : Qt.alpha(Theme.accent, 0.4)

        Behavior on color { ColorAnimation { duration: 250 } }

        // swallow card clicks so they don't fall through to the catcher
        MouseArea { anchors.fill: parent }

        Item {
            id: inner
            anchors.fill: parent
            anchors.margins: root.cardPadding
            focus: true
            Keys.onEscapePressed: root.visible = false
        }
    }
}

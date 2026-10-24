import QtQuick

// Window-follow toggle — the native bar's `>`/`v` wfsymbol as a module:
// when on, sending a window to another tag/monitor follows it. Click
// toggles (Mod+n does the same; _DWM_FOLLOW keeps them in sync).
BarModule {
    icon: Wm.follow ? "󰁔" : "󰁅"
    iconColor: Wm.follow ? Theme.accent : Qt.alpha(Theme.fg, 0.45)
    onClicked: Wm.toggleFollow()
}

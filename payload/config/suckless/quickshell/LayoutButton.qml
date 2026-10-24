import QtQuick

// Current layout as its nerd-font glyph — the same symbols dwm's retired
// native bar used (layouts[] in config.h). Scroll cycles layouts, click
// opens the settings panel's Layout tab.
BarModule {
    id: root

    icon: Wm.layouts[Wm.layoutIndex].glyph
    iconColor: Theme.fg

    onClicked: BarIpc.call("settings", "open", "layout")
    onScrolled: dir => Wm.cycleLayout(dir)
}

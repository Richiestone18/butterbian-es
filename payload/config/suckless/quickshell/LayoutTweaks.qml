import QtQuick
import Quickshell

// The layout grid and the live desktop tweaks (gap, master width and
// count, border width) and picom's effects, as a column for the settings
// panel's Layout tab. Click a tile to apply; gap and border persist to state files
// autostart.sh re-applies.
Column {
    id: root
    spacing: 6
    function persistFile(name, v) {
        Quickshell.execDetached(["sh", "-c",
            "printf '%s\\n' " + v + " > '" + Theme.configDir + "/" + name + "'"])
    }

        SectionLabel { text: "Diseño" }

        Grid {
            id: layoutGrid
            width: parent.width
            columns: 3
            spacing: 4

            Repeater {
                model: Wm.layouts

                Rectangle {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool current: Wm.layoutIndex === index

                    width: (layoutGrid.width - 8) / 3
                    height: 52
                    radius: 8
                    color: current ? Theme.selbg
                         : tileMa.containsMouse ? Qt.alpha(Theme.fg, 0.12)
                         : Qt.alpha(Theme.fg, 0.04)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.modelData.glyph
                            color: tile.current ? Theme.selfg : Theme.cyan
                            font.pixelSize: 18
                        }
                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.modelData.name
                            color: tile.current ? Theme.selfg : Qt.alpha(Theme.fg, 0.8)
                            font.pixelSize: 10
                            font.bold: tile.current
                        }
                    }

                    MouseArea {
                        id: tileMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Wm.setLayout(tile.index)
                    }
                }
            }
        }

        SectionLabel { text: "Escritorio" }

        TweakSlider {
            label: "espacio entre ventanas"
            from: 0; to: 40
            value: Wm.gaps
            suffix: " px"
            applyFn: v => Wm.setGaps(v)
            persistFn: v => root.persistFile("dwm-gaps", v)
        }
        TweakSlider {
            label: "ancho del borde"
            from: 0; to: 6
            value: Wm.borderpx
            suffix: " px"
            applyFn: v => Wm.setBorder(v)
            persistFn: v => root.persistFile("dwm-border", v)
        }
        // master sliders dim in layouts whose arrange ignores them
        TweakSlider {
            label: "ancho del maestro (esta etiqueta)"
            from: 20; to: 80
            value: Wm.mfact
            suffix: "%"
            applyFn: v => Wm.setMfact(v)
            persistFn: v => {}   // pertag — session state, nothing to persist
            enabled: Wm.layouts[Wm.layoutIndex].mfact
            opacity: enabled ? 1 : 0.35
        }
        TweakSlider {
            label: "conteo del maestro (esta etiqueta)"
            from: 1; to: 6
            value: Wm.nmaster
            applyFn: v => Wm.setNmaster(v)
            persistFn: v => {}   // pertag — session state, nothing to persist
            enabled: Wm.layouts[Wm.layoutIndex].nmaster
            opacity: enabled ? 1 : 0.35
        }

        SectionLabel { text: "Efectos" }

        // picom's, through scripts/picom-effects (Wm.qml): the file is the
        // state. No blur pill: on the xrender backend picom only has the
        // 3x3 kernel blur, a faint smear behind dimmed windows at a CPU
        // cost (the script still takes `blur 1` for a glx setup).
        Grid {
            id: fxGrid
            width: parent.width
            columns: 2
            spacing: 4

            Repeater {
                model: [
                    { icon: "󰘷", label: "Sombras", active: Wm.shadows,
                      run: () => Wm.setEffect("shadows", !Wm.shadows) },
                    { icon: "󰐊", label: "Animar", active: Wm.animations,
                      run: () => Wm.setEffect("animations", !Wm.animations) }
                ]
                TogglePill { width: (fxGrid.width - 4) / 2 }
            }
        }
        // windows without focus fade toward the wallpaper; 100 = off
        TweakSlider {
            label: "opacidad sin enfoque"
            from: 50; to: 100
            value: Wm.unfocusedOpacity
            suffix: "%"
            applyFn: v => Wm.setUnfocusedOpacity(v)
            persistFn: v => {}   // lives in picom.conf, written by the script
        }

}

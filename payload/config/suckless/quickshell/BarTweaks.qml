import QtQuick
import Quickshell

// The bar's own settings, as a column for the settings panel's Bar tab:
// height, element scale, popup size and the tag-icons toggle, each
// persisted to a state file Theme.qml watches, and the Modules list:
// the right cluster's modules shown or hidden and reordered (arrows),
// applied live through Theme.setModules.
Column {
    id: root
    spacing: 6
    function persistFile(name, v) {
        Quickshell.execDetached(["sh", "-c",
            "printf '%s\\n' " + v + " > '" + Theme.configDir + "/" + name + "'"])
    }

        SectionLabel { text: "Barra" }
        Grid {
            id: barGrid
            width: parent.width
            columns: 3
            spacing: 4
            Repeater {
                model: [
                    { icon: "󱂬", label: "Iconos de etiqueta", active: Theme.tagIcons,
                      run: () => {
                          Theme.tagIcons = !Theme.tagIcons
                          root.persistFile("tag-icons", Theme.tagIcons ? 1 : 0)
                      } }
                ]
                TogglePill { width: (barGrid.width - 8) / 3 }
            }
        }

        TweakSlider {
            label: "alto de la barra"
            from: 36; to: 72
            value: Theme.barHeight
            suffix: " px"
            applyFn: v => Theme.barHeight = v
            persistFn: v => root.persistFile("bar-height", v)
        }
        TweakSlider {
            label: "escala de elementos"
            from: 0.7; to: 2.0
            value: Theme.barUserScale
            isInt: false
            suffix: "×"
            applyFn: v => Theme.barUserScale = v
            persistFn: v => root.persistFile("bar-scale", v)
        }
        TweakSlider {
            label: "tamaño de las ventanas"
            from: 0.8; to: 2.0
            value: Theme.popupUserScale
            isInt: false
            suffix: "×"
            live: false
            applyFn: v => Theme.popupUserScale = v
            persistFn: v => root.persistFile("popup-scale", v)
        }

        SectionLabel { text: "Módulos" }
        Txt {
            width: parent.width
            wrapMode: Text.Wrap
            text: "tres zonas, cada una de izquierda a derecha · un interruptor oculta un módulo, L C R lo pasa a otra zona, las flechas lo reordenan · el lanzador va siempre primero y el menú de comandos al final"
            color: Qt.alpha(Theme.fg, 0.5)
            bottomPadding: 4
        }
        // moves swap within the zone; a zone change appends to the new zone
        function move(key, d) {
            const l = Theme.modules.slice()
            const i = l.findIndex(m => m.key === key)
            if (i < 0) return
            let j = i + d
            while (j >= 0 && j < l.length && l[j].zone !== l[i].zone) j += d
            if (j < 0 || j >= l.length) return
            const t = l[i]; l[i] = l[j]; l[j] = t
            Theme.setModules(l)
        }
        function flip(key) {
            const l = Theme.modules.slice()
            const i = l.findIndex(m => m.key === key)
            if (i >= 0) { l[i] = { key: l[i].key, zone: l[i].zone, on: !l[i].on }; Theme.setModules(l) }
        }
        function rezone(key, zone) {
            const l = Theme.modules.filter(m => m.key !== key)
            const m = Theme.modules.find(m => m.key === key)
            if (!m || m.zone === zone) return
            l.push({ key: key, zone: zone, on: m.on })
            Theme.setModules(l)
        }
        function inZone(zone) { return Theme.modules.filter(m => m.zone === zone) }
        Repeater {
            model: Theme.zones
            Column {
                id: zoneCol
                required property string modelData
                readonly property var members: root.inZone(modelData)
                width: parent.width
                spacing: 2
                Txt {
                    leftPadding: 6
                    topPadding: 6
                    text: zoneCol.modelData
                    color: Theme.accent
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1
                }
                Txt {
                    visible: zoneCol.members.length === 0
                    leftPadding: 6
                    text: "No hay nada aquí"
                    color: Qt.alpha(Theme.fg, 0.35)
                }
                Repeater {
                    model: zoneCol.members
                    Rectangle {
                        id: modRow
                        required property var modelData
                        required property int index
                        readonly property var def: Theme.moduleDefs.find(d => d.key === modelData.key)
                        width: parent.width
                        height: 30
                        radius: 6
                        color: rowMa.containsMouse ? Qt.alpha(Theme.fg, 0.06) : "transparent"
                        MouseArea { id: rowMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.flip(modRow.modelData.key) }
                        Toggle {
                            id: modToggle
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            on: modRow.modelData.on
                            onToggled: root.flip(modRow.modelData.key)
                        }
                        Txt {
                            anchors.left: modToggle.right
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: modRow.def ? modRow.def.label : modRow.modelData.key
                            color: modRow.modelData.on ? Theme.fg : Qt.alpha(Theme.fg, 0.45)
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            // the zone: L C R
                            Repeater {
                                model: Theme.zones
                                Rectangle {
                                    required property string modelData
                                    readonly property bool here: modRow.modelData.zone === modelData
                                    width: 22; height: 22; radius: 6
                                    color: here ? Qt.alpha(Theme.accent, 0.25) : zoneMa.containsMouse ? Qt.alpha(Theme.fg, 0.14) : "transparent"
                                    Txt { anchors.centerIn: parent; text: parent.modelData[0].toUpperCase(); color: parent.here ? Theme.accent : Qt.alpha(Theme.fg, 0.5); font.pixelSize: 10; font.bold: parent.here }
                                    MouseArea { id: zoneMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.rezone(modRow.modelData.key, parent.modelData) }
                                }
                            }
                            Item { width: 6; height: 1 }
                            Repeater {
                                model: [["󰅃", -1], ["󰅀", 1]]
                                Rectangle {
                                    required property var modelData
                                    readonly property bool can: modelData[1] < 0 ? modRow.index > 0 : modRow.index < zoneCol.members.length - 1
                                    width: 26; height: 24; radius: 6
                                    color: arrowMa.containsMouse && can ? Qt.alpha(Theme.fg, 0.14) : "transparent"
                                    opacity: can ? 1 : 0.25
                                    Txt { anchors.centerIn: parent; text: parent.modelData[0]; color: Theme.accent; font.pixelSize: 14 }
                                    MouseArea {
                                        id: arrowMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: parent.can
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.move(modRow.modelData.key, parent.modelData[1])
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        Txt {
            text: "Restablecer diseño predeterminado"
            color: Theme.accent
            font.pixelSize: 11
            topPadding: 4
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Theme.setModules(Theme.defaultModules()) }
        }
}

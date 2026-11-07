import QtQuick
import Quickshell
import Quickshell.Io

// The command menu: batteries (when UPower reports any), quick-settings
// tiles (QuickTile; they stay open so the change shows, right click opens
// the fuller tool), a brightness slider on laptops, and system rows that
// close the menu. A running focus timer shows its countdown on this pill.
// dwm: keep awake is xset's screensaver/DPMS switch and night light a
// one-shot redshift, so those two are tracked here rather than read back;
// no lock rows (butterdwm ships no locker) and no Displays card.
BarModule {
    id: root

    icon: "󰘳"
    iconColor: Pomodoro.done ? Theme.bg
             : Pomodoro.running ? Theme.accent : Qt.alpha(Theme.fg, 0.7)
    label: Pomodoro.running ? Pomodoro.fmt(Pomodoro.remaining) : Pomodoro.done ? "0:00" : ""
    // time's up: the pill stays red until acknowledged, so the signal
    // survives DND (which holds the dunst notification back)
    alert: Pomodoro.done
    progress: Pomodoro.running ? Pomodoro.remaining / Pomodoro.total : -1

    onClicked: {
        Pomodoro.done = false
        menu.visible = !menu.visible
    }

    // polled on every open; everything with a query is read back from the
    // system so a bar restart can't desync the pills
    property string profile: "balanced"
    property bool caffeine: false
    property bool nightLight: false
    property bool hasBacklight: false
    property int brightness: 50
    property bool btPresent: false
    property bool btOn: false
    property bool hasTimeshift: false

    Process {
        id: stateProc
        // one printf, one guaranteed line per field — a missing tool
        // yields an empty line instead of shifting the indices below
        command: ["sh", "-c",
            "printf '%s\\n' " +
            "\"$(powerprofilesctl get 2>/dev/null)\" " +
            "\"$(brightnessctl -m -c backlight 2>/dev/null | head -n1)\" " +
            "\"$(xset q | awk '/timeout:/{print $2}')\" " +
            "\"$(bluetoothctl show 2>/dev/null | awk '/Powered:/ { print $2; exit }')\" " +
            "\"$(command -v timeshift-launcher >/dev/null && echo timeshift)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n")
                if (root.profileOrder.indexOf(lines[0]) >= 0)
                    root.profile = lines[0]
                const bl = (lines[1] ?? "").split(",")
                root.hasBacklight = bl.length >= 4
                if (root.hasBacklight)
                    root.brightness = parseInt(bl[3]) || root.brightness
                // screensaver timeout 0 = blanking disabled = kept awake
                if (lines[2] !== undefined && lines[2] !== "")
                    root.caffeine = lines[2] === "0"
                // "yes"/"no" from a controller; empty = no adapter
                root.btPresent = (lines[3] ?? "") !== ""
                root.btOn = lines[3] === "yes"
                root.hasTimeshift = lines[4] === "timeshift"
            }
        }
    }

    readonly property var profileOrder: ["performance", "balanced", "power-saver"]
    readonly property var profileIcons: ({ performance: "󰓅", balanced: "󰾅", "power-saver": "󰾆" })
    readonly property var profileNames: ({ performance: "Rendimiento", balanced: "Equilibrado", "power-saver": "Ahorro de energía" })

    function toggleBluetooth() {
        root.btOn = !root.btOn
        Quickshell.execDetached(["bluetoothctl", "power", root.btOn ? "on" : "off"])
    }

    function cycleProfile() {
        const next = profileOrder[(profileOrder.indexOf(profile) + 1) % profileOrder.length]
        Quickshell.execDetached(["powerprofilesctl", "set", next])
        profile = next
    }

    // history home while the Bell is hidden (it only shows during DND)
    NotifyPopup {
        id: notifHistory
        anchorItem: root
    }

    // Super+x (scripts/power) and the Power menu row below
    PowerPopup {
        id: power
        anchorItem: root
    }

    Popout {
        id: menu
        ipcNames: ["commands"]
        anchorItem: root
        cardWidth: 350
        cardHeight: col.implicitHeight + 2 * cardPadding

        onVisibleChanged: if (visible) {
            stateProc.running = true
            Batteries.refresh()
        }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 6

            // --- Batteries: only when something reports one ---
            SectionLabel {
                visible: Batteries.devices.length > 0
                topPadding: 0
                text: "Baterías"
            }

            Repeater {
                model: Batteries.devices

                Item {
                    id: bat
                    required property var modelData
                    readonly property bool low: Batteries.isLow(modelData) && !modelData.charging
                    readonly property string more: Batteries.detail(modelData)
                    width: parent.width
                    height: more !== "" ? 36 : 24

                    Txt {
                        id: batGlyph
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        horizontalAlignment: Text.AlignHCenter
                        text: Batteries.glyph(bat.modelData)
                        color: bat.low ? Theme.red : Theme.cyan
                        font.pixelSize: 15
                    }
                    Column {
                        anchors.left: batGlyph.right
                        anchors.leftMargin: 10
                        anchors.right: batCharge.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Txt {
                            width: parent.width
                            text: bat.modelData.name
                            color: Qt.alpha(Theme.fg, 0.9)
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        Txt {
                            visible: bat.more !== ""
                            width: parent.width
                            text: bat.more
                            color: Qt.alpha(Theme.fg, 0.5)
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }
                    Txt {
                        id: batCharge
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: Batteries.charge(bat.modelData)
                        color: bat.low ? Theme.red
                             : bat.modelData.pct < 0 && bat.modelData.level === "unknown" ? Qt.alpha(Theme.fg, 0.4)
                             : Theme.fg
                        font.pixelSize: 12
                        font.bold: bat.low
                    }
                }
            }

            // --- Quick settings ---
            SectionLabel {
                topPadding: Batteries.devices.length > 0 ? 6 : 0
                text: "Configuración rápida"
            }

            Grid {
                width: parent.width
                columns: 2
                spacing: 6

                Repeater {
                    model: [
                        { icon: root.profileIcons[root.profile] ?? "󰾅",
                          name: "Perfil de energía",
                          state: root.profileNames[root.profile] ?? root.profile,
                          active: root.profile !== "balanced",
                          run: () => root.cycleProfile() },
                        { icon: "󰅶", name: "Mantener despierto",
                          state: root.caffeine ? "Encendido" : "Apagado",
                          active: root.caffeine,
                          run: () => {
                              root.caffeine = !root.caffeine
                              Quickshell.execDetached(["sh", "-c",
                                  root.caffeine ? "xset s off -dpms" : "xset s on +dpms"])
                          } },
                        { icon: Sys.micMuted ? "󰍭" : "󰍬", name: "Micrófono",
                          state: Sys.micMuted ? "Silenciado" : "Activo",
                          alert: Sys.micMuted,
                          altFn: () => {
                              menu.visible = false
                              Quickshell.execDetached(["pavucontrol", "-t", "4"])
                          },
                          run: () => Sys.toggleMicMute() },
                        { icon: "󱩌", name: "Luz nocturna",
                          state: root.nightLight ? "Encendido" : "Apagado",
                          active: root.nightLight,
                          run: () => {
                              root.nightLight = !root.nightLight
                              Quickshell.execDetached(["sh", "-c",
                                  root.nightLight ? "redshift -P -O 4500" : "redshift -x"])
                          } },
                        { icon: Sys.dndOn ? "󰂛" : "󰂚", name: "No molestar",
                          state: Sys.dndOn ? "Encendido" : "Apagado",
                          alert: Sys.dndOn,
                          altFn: () => {
                              menu.visible = false
                              notifHistory.visible = true
                          },
                          run: () => Sys.toggleDnd() },
                        root.btPresent ? {
                          icon: root.btOn ? "󰂯" : "󰂲", name: "Bluetooth",
                          state: root.btOn ? "Encendido" : "Apagado",
                          active: root.btOn,
                          altFn: () => {
                              menu.visible = false
                              Quickshell.execDetached([Theme.configDir + "/scripts/network"])
                          },
                          run: () => root.toggleBluetooth() } : null,
                        { icon: "󰔟", name: "Temporizador de enfoque",
                          state: Pomodoro.running ? Pomodoro.fmt(Pomodoro.remaining) + " left"
                                                  : Pomodoro.minutes + " min",
                          active: Pomodoro.running,
                          adjust: Pomodoro.running ? null : dir => Pomodoro.nudge(dir),
                          run: () => Pomodoro.toggle() }
                    ].filter(t => t)
                    QuickTile {}
                }
            }

            TweakSlider {
                visible: root.hasBacklight
                label: "brillo"
                from: 5; to: 100
                value: root.brightness
                suffix: "%"
                applyFn: v => Quickshell.execDetached(
                    ["brightnessctl", "-c", "backlight", "set", v + "%"])
                persistFn: v => {}   // hardware remembers; nothing to persist
            }

            // --- System ---
            SectionLabel { text: "Sistema" }

            Repeater {
                model: [
                    { icon: "󰂚", label: "Notificaciones",
                      run: () => notifHistory.visible = true },
                    // Timeshift: roll back a bad update. timeshift-launcher
                    // asks for the password itself.
                    root.hasTimeshift ? { icon: "󰁯", label: "Instantáneas",
                      run: () => Quickshell.execDetached(["timeshift-launcher"]) } : null,
                    { icon: "󰚰", label: "Buscar actualizaciones",
                      run: () => Quickshell.execDetached(["kitty", "-e", "sh", "-c",
                          "sudo apt update && apt list --upgradable; " +
                          "qs -p \"$0\" ipc call updates check >/dev/null 2>&1; " +
                          "\"$1\" offer; " +
                          "printf '\\ndone - press enter to close '; read _",
                          Theme.configDir + "/quickshell", Theme.configDir + "/scripts/setup-update"]) },
                    // this setup, from its git clone: nothing checks on its own
                    { icon: "󰊢", label: "Actualizar butterdwm",
                      run: () => Quickshell.execDetached(["kitty", "-e",
                          Theme.configDir + "/scripts/setup-update"]) },
                    { icon: "󰌌", label: "Atajos de teclado",
                      run: () => BarIpc.call("settings", "open", "keybinds") },
                    { icon: "󰒓", label: "Configuración",
                      run: () => BarIpc.call("settings", "open", "rules") },
                    { icon: "󰑓", label: "Reiniciar la barra",
                      run: () => Quickshell.execDetached([Theme.configDir + "/scripts/bar", "restart"]) },
                    { icon: "󰐥", label: "Menú de energía",
                      run: () => power.visible = true }
                ].filter(r => r)
                ListRow {
                    required property var modelData
                    height: 34
                    glyphSize: 15
                    fontSize: 13
                    glyphWidth: 0
                    pointer: false
                    glyph: modelData.icon
                    text: modelData.label
                    onClicked: {
                        menu.visible = false
                        modelData.run()
                    }
                }
            }
        }
    }
}

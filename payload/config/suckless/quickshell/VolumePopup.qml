import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Volume popup (right-click the Volume module), in sections:
//   header — the output you're hearing, its level, a mute pill
//   Output — volume slider; every audio output PipeWire knows, click one
//     to make it the default (headphones vs speakers vs HDMI)
//   Profile — a sound card's profile, when it has more than one: a card
//     on "Salida de estéreo analógico" has no HDMI output to pick until it is on
//     a HDMI profile (scripts/audio-profiles, pactl underneath; otherwise
//     pavucontrol's Configuration tab)
//   Input — only with a microphone: its level, a live meter (runs only
//     while this is open), the microphones to pick from, a mute pill
//   Apps — only while something plays: each app's own volume
//   Mixer (pavucontrol) for the rest (routing, profiles).
// All of it straight from the Pipewire service, so changes made anywhere
// else show here too.
Popout {
    id: root
    ipcNames: ["volume"]

    cardWidth: 340
    cardHeight: col.implicitHeight + 2 * cardPadding

    // Filters use only what PipeWire announces up front (sink/stream, node
    // name): a node's audio and properties arrive after it's bound, and a
    // list that changed with them would bind, unbind and rebind forever.
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)
    // microphones only: cameras are non-stream nodes too
    readonly property var sources: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioSource)
    // what apps are playing (output streams; the meter below is an input
    // stream, so it never shows), grouped by app: Firefox's four tabs are
    // one Firefox slider that moves them all
    readonly property var outStreams: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioOutStream)
    readonly property var apps: {
        const groups = []
        for (const n of outStreams) {
            const name = appLabel(n)
            const g = groups.find(g => g.name === name)
            if (g) g.nodes.push(n)
            else groups.push({ name: name, nodes: [n] })
        }
        return groups
    }

    // bound so their audio state (volume, mute) stays live while listed
    PwObjectTracker { objects: root.sinks.concat(root.sources, root.outStreams) }

    // the cards' profiles, read when the popup opens and after a change
    property var profiles: []   // {card, desc, profile, label, active}
    readonly property var cards: {
        const out = []
        for (const p of profiles) {
            let c = out.find(x => x.card === p.card)
            if (!c) { c = { card: p.card, desc: p.desc, rows: [] }; out.push(c) }
            c.rows.push(p)
        }
        return out.filter(c => c.rows.length > 1)
    }
    Process {
        id: profilesRead
        command: [Theme.configDir + "/scripts/audio-profiles"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const l of text.split("\n")) {
                    const f = l.split("\t")
                    if (f.length >= 5) out.push({ card: f[0], desc: f[1], profile: f[2], label: f[3], active: f[4] === "1" })
                }
                root.profiles = out
            }
        }
    }
    Process {
        id: profileSet
        onExited: profilesRead.running = true
    }
    function setProfile(card, profile) {
        profileSet.command = [Theme.configDir + "/scripts/audio-profiles", "set", card, profile]
        profileSet.running = true
    }
    onVisibleChanged: if (visible) profilesRead.running = true

    readonly property var current: Pipewire.defaultAudioSink
    readonly property var audio: current?.audio ?? null
    // the default source only if it really is a microphone: with none
    // chosen, PipeWire can hand back an output here (butterbian does),
    // and "mute input" would mute the speakers
    readonly property var mic: Pipewire.defaultAudioSource?.type === PwNodeType.AudioSource
                               ? Pipewire.defaultAudioSource : null
    readonly property var micAudio: mic?.audio ?? null

    // the microphone's live level, only while the popup is open
    PwNodePeakMonitor {
        id: meter
        node: root.mic
        enabled: root.visible && root.mic !== null
    }

    function label(n) {
        return n.description || n.nickname || n.name
    }
    function appLabel(n) {
        return n.properties?.["application.name"] || n.name || "aplicación"
    }
    function pct(a) {
        return a ? Math.round(a.volume * 100) : 0
    }

    // mute pill: soft like the bar's pills, red while muted
    component MutePill: Rectangle {
        property bool muted: false
        signal toggled()
        width: muteText.implicitWidth + 36
        height: 24
        radius: 8
        color: muted ? Theme.red
             : muteMa.containsMouse ? Qt.alpha(Theme.fg, 0.14) : Qt.alpha(Theme.fg, 0.07)
        Behavior on color { ColorAnimation { duration: 150 } }
        Row {
            anchors.centerIn: parent
            spacing: 6
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.muted ? "󰖁" : "󰕾"
                color: parent.parent.muted ? Theme.bg : Theme.cyan
                font.pixelSize: 13
            }
            Txt {
                id: muteText
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.muted ? "silenciado" : "silenciar"
                color: parent.parent.muted ? Theme.bg : Theme.fg
                font.bold: parent.parent.muted
            }
        }
        MouseArea {
            id: muteMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.toggled()
        }
    }

    // one device row: glyph, name; the default one highlighted
    component DeviceRow: Rectangle {
        id: dev
        required property var modelData
        property var chosen: null
        property string glyph: "󰓃"
        signal picked()
        readonly property bool active: modelData === chosen

        width: parent.width
        height: 32
        radius: 8
        color: active ? Qt.alpha(Theme.accent, 0.18)
             : devMa.containsMouse ? Qt.alpha(Theme.fg, 0.12) : "transparent"

        Behavior on color { ColorAnimation { duration: 120 } }

        Txt {
            id: devGlyph
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            horizontalAlignment: Text.AlignHCenter
            text: dev.active ? "󰄬" : dev.glyph
            color: dev.active ? Theme.accent : Theme.cyan
            font.pixelSize: 14
        }
        Txt {
            anchors.left: devGlyph.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: root.label(dev.modelData)
            elide: Text.ElideRight
            color: dev.active ? Theme.fg : Qt.alpha(Theme.fg, 0.9)
            font.pixelSize: 12
            font.bold: dev.active
        }
        MouseArea {
            id: devMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: dev.picked()
        }
    }

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 6

        // --- header: what you're hearing ---
        Item {
            width: parent.width
            height: 48

            // the media popup's tile
            Rectangle {
                id: tile
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                radius: 8
                color: Qt.alpha(Theme.fg, 0.06)

                Txt {
                    anchors.centerIn: parent
                    text: root.audio?.muted ? "󰝟"
                        : root.pct(root.audio) < 25 ? "󰕿"
                        : root.pct(root.audio) < 65 ? "󰖀" : "󰕾"
                    color: root.audio?.muted ? Qt.alpha(Theme.fg, 0.45) : Theme.green
                    font.pixelSize: 22
                }
            }

            Column {
                anchors.left: tile.right
                anchors.leftMargin: 12
                anchors.right: outMute.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Txt {
                    text: "Volumen"
                    font.pixelSize: 13
                    font.bold: true
                }
                Txt {
                    width: parent.width
                    text: (root.current ? root.label(root.current) : "sin salida")
                        + " · " + (root.audio?.muted ? "silenciado" : root.pct(root.audio) + "%")
                    color: Qt.alpha(Theme.fg, 0.55)
                    elide: Text.ElideRight
                }
            }

            MutePill {
                id: outMute
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                muted: root.audio?.muted ?? false
                onToggled: if (root.audio) root.audio.muted = !root.audio.muted
            }
        }

        // --- Output ---
        SectionLabel { text: "Salida" }

        TweakSlider {
            label: "volumen"
            from: 0; to: 100
            value: root.pct(root.audio)
            suffix: "%"
            applyFn: v => {
                if (!root.audio) return
                root.audio.muted = false
                root.audio.volume = v / 100
            }
            persistFn: v => {}   // PipeWire remembers
        }

        Repeater {
            model: root.sinks
            DeviceRow {
                chosen: root.current
                glyph: "󰓃"
                onPicked: Pipewire.preferredDefaultAudioSink = modelData
            }
        }

        Txt {
            visible: root.sinks.length === 0
            text: "Sin salidas"
            color: Qt.alpha(Theme.fg, 0.5)
            font.pixelSize: 12
            leftPadding: 10
        }

        // --- Profile: per card with a choice; the outputs above follow ---
        Repeater {
            model: root.cards
            Column {
                id: cardCol
                required property var modelData
                width: parent.width
                spacing: 2
                SectionLabel { text: root.cards.length > 1 ? "Perfil · " + cardCol.modelData.desc : "Perfil" }
                Repeater {
                    model: cardCol.modelData.rows
                    Rectangle {
                        id: prof
                        required property var modelData
                        width: parent.width
                        height: 28
                        radius: 8
                        color: modelData.active ? Qt.alpha(Theme.accent, 0.18)
                             : profMa.containsMouse ? Qt.alpha(Theme.fg, 0.12) : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Txt {
                            id: profGlyph
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            horizontalAlignment: Text.AlignHCenter
                            text: prof.modelData.active ? "󰄬" : "󰋋"
                            color: prof.modelData.active ? Theme.accent : Theme.cyan
                            font.pixelSize: 13
                        }
                        Txt {
                            anchors.left: profGlyph.right
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: prof.modelData.label
                            elide: Text.ElideRight
                            color: prof.modelData.active ? Theme.fg : Qt.alpha(Theme.fg, 0.9)
                            font.pixelSize: 12
                            font.bold: prof.modelData.active
                        }
                        MouseArea {
                            id: profMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setProfile(prof.modelData.card, prof.modelData.profile)
                        }
                    }
                }
            }
        }

        // --- Input: only with a microphone ---
        Item {
            visible: root.sources.length > 0
            width: parent.width
            height: 30

            SectionLabel {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                topPadding: 0
                text: "Entrada"
            }
            MutePill {
                visible: root.micAudio !== null
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                muted: root.micAudio?.muted ?? false
                onToggled: if (root.micAudio) root.micAudio.muted = !root.micAudio.muted
            }
        }

        TweakSlider {
            visible: root.micAudio !== null
            label: "micrófono"
            from: 0; to: 100
            value: root.pct(root.micAudio)
            suffix: "%"
            applyFn: v => {
                if (!root.micAudio) return
                root.micAudio.volume = v / 100
            }
            persistFn: v => {}
        }

        // live level: square root so speech fills a useful part of the
        // bar; red near clipping
        Rectangle {
            visible: root.micAudio !== null
            width: parent.width - 8
            anchors.horizontalCenter: parent.horizontalCenter
            height: 4
            radius: 2
            color: Qt.alpha(Theme.fg, 0.1)

            Rectangle {
                readonly property real level: root.micAudio?.muted ? 0 : Math.min(1, Math.sqrt(meter.peak))
                width: parent.width * level
                height: parent.height
                radius: 2
                color: level > 0.95 ? Theme.red : Theme.accent
                Behavior on width { NumberAnimation { duration: 80 } }
            }
        }

        Repeater {
            model: root.sources
            DeviceRow {
                chosen: root.mic
                glyph: "󰍬"
                onPicked: Pipewire.preferredDefaultAudioSource = modelData
            }
        }

        // --- Apps: each thing playing, its own level ---
        SectionLabel {
            visible: root.apps.length > 0
            text: "Aplicaciones"
        }

        Repeater {
            model: root.apps

            TweakSlider {
                id: appSlider
                required property var modelData
                label: modelData.name
                from: 0; to: 100
                value: root.pct(modelData.nodes[0].audio)
                suffix: "%"
                applyFn: v => {
                    for (const n of appSlider.modelData.nodes)
                        if (n.audio) n.audio.volume = v / 100
                }
                persistFn: v => {}
            }
        }

        Rectangle {
            width: parent.width - 8
            anchors.horizontalCenter: parent.horizontalCenter
            height: 1
            color: Qt.alpha(Theme.fg, 0.15)
        }

        Rectangle {
            width: parent.width
            height: 34
            radius: 8
            color: mixMa.containsMouse ? Qt.alpha(Theme.fg, 0.12) : "transparent"

            Behavior on color { ColorAnimation { duration: 120 } }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 10
                spacing: 10

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰕾"
                    color: Theme.cyan
                    font.pixelSize: 15
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Mezclador (pavucontrol)"
                    color: Qt.alpha(Theme.fg, 0.9)
                    font.pixelSize: 13
                }
            }

            MouseArea {
                id: mixMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.visible = false
                    Quickshell.execDetached(["pavucontrol"])
                }
            }
        }
    }
}

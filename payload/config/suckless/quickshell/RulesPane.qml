import QtQuick
import Quickshell
import Quickshell.Io

// Rules tab of the settings panel: dwm/rules.conf as a list — what a
// rule matches and what it does — with an editor built around the
// decisions rather than the file's fields. A new rule starts from a
// window: pick one (xprop on a click) or type the app; the match shows
// as one chip, the raw class / instance / title stay behind "edit
// match". Then floating (centered under it), the tag it opens on, the
// monitor when there is more than one, a note. "Ranura scratch" is a
// switch: on, it asks for the id, the command that opens it and the key
// that toggles it — saving writes the rule and the keybind both, and
// deleting removes both. Every write goes through the generators first,
// so a bad rule is refused with its reason. scripts/rules and
// scripts/keybinds are the back ends.
Item {
    id: root
    required property var popup

    property var rows: []        // {section, match, detail, line}
    property var editing: null   // {line, section, isNew, title}
    property bool floating: false
    property bool centered: false
    property var tags: []        // selected tag numbers
    property string monitor: ""
    property bool scratch: false
    property bool showMatch: false
    property int bindLine: 0     // the scratchpad's keybind, when editing one
    property bool dirty: false
    property string status: ""
    property bool statusBad: false
    readonly property string tool: Theme.configDir + "/scripts/rules"
    readonly property string ktool: Theme.configDir + "/scripts/keybinds"

    function shown() { status = ""; loader.running = true }
    function hidden() { chordField.stop(); editing = null }

    Process {
        id: loader
        command: [root.tool]
        stdout: StdioCollector { onStreamFinished: root.rows = root.parse(text) }
    }
    function parse(t) {
        const out = []
        for (const l of t.split("\n")) {
            const f = l.split("\t")
            if (f.length < 4) continue
            out.push({ section: f[0], match: f[1], detail: f[2], line: parseInt(f[3]) })
        }
        return out
    }
    readonly property var sectionTitles: ({ floating: "Ventanas flotantes", tags: "Se abre en etiqueta", scratchpads: "Ranuras scratch" })
    readonly property var sections: {
        const s = []
        for (const r of rows) {
            let sec = s.find(x => x.key === r.section)
            if (!sec) { sec = { key: r.section, title: sectionTitles[r.section] ?? r.section, rows: [] }; s.push(sec) }
            sec.rows.push(r)
        }
        return s
    }

    // one verb at a time, for either script; the exit code rides on the first line
    Process {
        id: proc
        property var done: null
        stdout: StdioCollector {
            onStreamFinished: {
                const f = proc.done; proc.done = null
                const i = text.indexOf("\n")
                if (f) f(parseInt(text.slice(0, i)), text.slice(i + 1))
            }
        }
    }
    function run(script, args, cb) {
        proc.done = cb
        proc.command = ["sh", "-c", 'o=$("$0" "$@" 2>&1); r=$?; printf "%s\\n%s" "$r" "$o"', script].concat(args)
        proc.running = true
    }
    function setStatus(s, bad) { status = s; statusBad = bad }

    function fill(f) {
        classField.text = f[0] ?? ""; instField.text = f[1] ?? ""; titleField.text = f[2] ?? ""
        tags = (f[3] ?? "").split(",").filter(x => x !== "").map(x => parseInt(x))
        floating = f[4] === "yes"; centered = f[5] === "yes"
        monitor = f[6] ?? ""; scratch = (f[7] ?? "") !== ""
        scratchField.text = f[7] ?? ""; runField.text = f[8] ?? ""; descField.text = f[9] ?? ""
        chordField.text = ""; bindLine = 0; pickedCmd = ""
        showMatch = false
    }
    readonly property string matchText: {
        const parts = []
        if (classField.text.trim() !== "") parts.push("class " + classField.text.trim())
        if (instField.text.trim() !== "") parts.push("instance " + instField.text.trim())
        if (titleField.text.trim() !== "") parts.push("title " + titleField.text.trim())
        return parts.join("  ·  ")
    }
    function openEditor(line, section, match) {
        run(root.tool, ["get", String(line)], (rc, out) => {
            const f = out.replace(/\n$/, "").split("\t")
            if (rc !== 0 || f.length < 10) return
            editing = { line: line, section: section, isNew: false, title: match }
            fill(f)
            if (scratch) findBind(scratchField.text)
            focusEditor()
        })
    }
    // the keybind that toggles scratchpad ID, from the keybinds rows
    function findBind(id) {
        run(root.ktool, [], (rc, out) => {
            bindLine = 0
            for (const l of out.split("\n")) {
                const f = l.split("\t")
                if (f.length >= 6 && f[5] === "togglescratch " + id) {
                    bindLine = parseInt(f[3])
                    // the raw chord, not the keycaps: get gives mod and key
                    run(root.ktool, ["get", String(bindLine)], (rc2, out2) => {
                        const g = out2.replace(/\n$/, "").split("\t")
                        if (rc2 === 0 && g.length >= 2)
                            chordField.text = (g[0] === "none" || g[0] === "" ? "" : g[0] + "+") + g[1]
                    })
                    return
                }
            }
        })
    }
    function addRule() {
        editing = { line: 0, section: "", isNew: true, title: "" }
        fill([])
        showMatch = true
        focusEditor()
    }
    function focusEditor() { status = ""; Qt.callLater(() => classField.input.forceActiveFocus()) }
    function cancelEdit() { chordField.stop(); editing = null }
    // where a rule files by what it does
    function sectionFor() { return scratch ? "scratchpads" : tags.length ? "tags" : "floating" }
    function save() {
        if (!editing) return
        chordField.stop()
        const e = editing
        if (classField.text.trim() === "" && instField.text.trim() === "" && titleField.text.trim() === "") {
            setStatus("elige una ventana primero, o escribe su clase", true); return
        }
        if (scratch && scratchField.text.trim() === "") { setStatus("un scratchpad necesita un id de una letra", true); return }
        if (scratch && runField.text.trim() === "") { setStatus("un scratchpad necesita el comando que lo abre", true); return }
        const id = scratch ? scratchField.text.trim() : ""
        const args = (e.isNew ? ["add", sectionFor()] : ["set", String(e.line)]).concat([
            classField.text.trim(), instField.text.trim(), titleField.text.trim(), tags.slice().sort((a, b) => a - b).join(","),
            floating ? "yes" : "no", centered ? "yes" : "no", monitor,
            id, scratch ? runField.text.trim() : "", descField.text.trim()])
        run(root.tool, args, (rc, out) => {
            if (rc !== 0) { setStatus(out.trim(), true); return }
            // the rule is in the file now: a second Save edits it
            const line = parseInt(out.trim())
            if (e.isNew && !isNaN(line)) editing = { line: line, section: sectionFor(), isNew: false, title: matchText }
            if (scratch && chordField.text.trim() !== "")
                saveBind(id)
            else
                saved()
        })
    }
    // the scratchpad's toggle key: a new bind, or the one it already has
    function saveBind(id) {
        const ck = chordField.split(chordField.text)
        const desc = descField.text.trim() !== "" ? descField.text.trim() : "Ranura scratch " + id
        const args = (bindLine ? ["set", String(bindLine)] : ["add", "scratchpads"])
            .concat([ck[0], ck[1], desc, "do", "togglescratch " + id])
        run(root.ktool, args, (rc, out) => {
            if (rc !== 0) { setStatus("regla guardada, pero la tecla: " + out.trim().replace(/^keybinds-gen: \S+:\d+: /gm, ""), true); dirty = true; loader.running = true; return }
            saved()
        })
    }
    function saved() {
        dirty = true; editing = null
        setStatus("guardado · Aplicar recompila dwm con él", false)
        loader.running = true
    }
    function remove() {
        const e = editing
        if (!e || e.isNew) { cancelEdit(); return }
        const dropRule = () => run(root.tool, ["delete", String(e.line)], (rc, out) => {
            if (rc !== 0) { setStatus(out.trim(), true); return }
            dirty = true; editing = null
            setStatus("eliminado · Aplicar recompila dwm sin él", false)
            loader.running = true
        })
        // a scratchpad's bind goes first, or the generator refuses the rule
        if (scratch && bindLine)
            run(root.ktool, ["delete", String(bindLine)], (rc, out) => { if (rc !== 0) setStatus(out.trim(), true); else dropRule() })
        else
            dropRule()
    }
    // xprop waits for a click; the panel closes so the click lands on a
    // real window, then comes back with the match filled
    property var pickFor: null
    function pick() {
        pickFor = editing ?? { line: 0, section: "", isNew: true, title: "" }
        popup.visible = false
        run(root.tool, ["pick"], (rc, out) => {
            const f = out.replace(/\n$/, "").split("\t")
            popup.ipc("open", "rules")
            if (rc !== 0 || f.length < 3 || (f[0] === "" && f[1] === "" && f[2] === "")) {
                setStatus("eso no era una ventana (el escritorio no tiene clase ni título)", true)
                pickFor = null
                return
            }
            if (!editing || editing.line !== pickFor.line) {
                editing = pickFor
                if (pickFor.isNew) fill([])
            }
            classField.text = ""; instField.text = ""; titleField.text = ""
            const inner = f[4] ?? ""
            if (inner !== "") {
                // a terminal showing a program: match the instance the
                // terminal is told to use, and reopen it the same way
                // (kitty --name pulsemixer -e pulsemixer), not every kitty
                const prog = inner.split(" ")[0].split("/").pop()
                const term = ((f[3] ?? "").split(" ")[0] || f[0]).split("/").pop()
                instField.text = prog
                pickedCmd = term + " " + (nameFlag[term] ?? "--name") + " " + prog + " -e " + inner
                if (scratch && runField.text.trim() === "") runField.text = pickedCmd
                setStatus(term + " muestra " + prog + ": coincide por instancia " + prog + ", abierto por " + pickedCmd, false)
            } else {
                classField.text = f[0]
                if (f[0] === "") { instField.text = f[1]; if (f[1] === "") titleField.text = f[2] }
                pickedCmd = f[3] ?? ""
                status = ""
            }
            pickFor = null
            showMatch = false
        })
    }
    // how each terminal is told its instance name
    readonly property var nameFlag: ({ kitty: "--name", st: "-n", alacritty: "--class", xterm: "-name", urxvt: "-name" })
    property string pickedCmd: ""   // what reopens the picked window: the scratchpad's command
    function edit(line) {
        popup.visible = false
        Quickshell.execDetached([root.tool, "open", String(line)])
    }

    component Pill: Rectangle {
        property string label
        property bool active: false
        signal clicked()
        width: pillText.implicitWidth + 18
        height: 24
        radius: 8
        color: active ? Theme.accent : pillMa.containsMouse ? Qt.alpha(Theme.fg, 0.14) : Qt.alpha(Theme.fg, 0.06)
        Behavior on color { ColorAnimation { duration: 120 } }
        Txt { id: pillText; anchors.centerIn: parent; text: parent.label; color: parent.active ? Theme.bg : Qt.alpha(Theme.fg, 0.85); font.bold: parent.active }
        MouseArea { id: pillMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }
    component Lbl: Txt {
        width: 110
        anchors.verticalCenter: parent.verticalCenter
        color: Qt.alpha(Theme.fg, 0.7)
    }
    component Switch: Item {
        id: sw
        property string label
        property bool on: false
        property bool enabled: true
        signal toggled()
        anchors.verticalCenter: parent.verticalCenter
        width: swText.x + swText.implicitWidth
        height: 24
        opacity: enabled ? 1 : 0.4
        Toggle { id: swToggle; anchors.verticalCenter: parent.verticalCenter; on: sw.on; enabled: sw.enabled; onToggled: sw.toggled() }
        Txt { id: swText; x: swToggle.width + 8; anchors.verticalCenter: parent.verticalCenter; text: sw.label; color: Qt.alpha(Theme.fg, 0.9) }
        MouseArea { anchors.fill: parent; enabled: sw.enabled; cursorShape: Qt.PointingHandCursor; onClicked: sw.toggled() }
    }

    // --- header ---
    Rectangle {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        height: 34
        radius: 8
        color: Qt.alpha(Theme.fg, 0.06)
        Txt {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "󰖲  Reglas de ventana y scratchpads"
            color: Qt.alpha(Theme.fg, 0.8)
            font.pixelSize: 12
        }
        EditButton {
            anchors.right: hint.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: 24
            label: "+ Nueva regla"
            primary: true
            onClicked: root.addRule()
        }
        Txt {
            id: hint
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width * 0.4)
            elide: Text.ElideRight
            text: root.status !== "" ? root.status : "clic en una regla para editarla · clic derecho abre el archivo"
            color: root.status === "" ? Qt.alpha(Theme.fg, 0.35) : root.statusBad ? Theme.red : Qt.alpha(Theme.fg, 0.7)
        }
    }

    // --- list ---
    Flickable {
        id: body
        anchors.top: header.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: root.editing ? editorPanel.top : parent.bottom
        anchors.bottomMargin: root.editing ? 14 : 0
        contentWidth: width
        contentHeight: list.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: list
            width: parent.width
            spacing: 14

            Txt {
                visible: root.rows.length === 0
                text: "Sin reglas aún. Nueva regla → elige una ventana → indica qué debe hacer."
                color: Qt.alpha(Theme.fg, 0.5)
            }

            Repeater {
                model: root.sections

                Column {
                    id: section
                    required property var modelData
                    width: parent.width
                    spacing: 1

                    Txt {
                        leftPadding: 6
                        bottomPadding: 4
                        text: section.modelData.title
                        color: Theme.accent
                        font.bold: true
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1
                    }

                    Repeater {
                        model: section.modelData.rows

                        Rectangle {
                            id: ruleRow
                            required property var modelData
                            width: parent.width
                            height: Math.max(matchCap.height, detail.implicitHeight) + 8
                            radius: 6
                            color: rowMa.containsMouse ? Qt.alpha(Theme.fg, 0.08) : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Rectangle {
                                id: matchCap
                                x: 6; y: 4
                                height: 20
                                width: matchText.implicitWidth + 12
                                radius: 4
                                color: Qt.alpha(Theme.fg, 0.08)
                                border.width: 1
                                border.color: Qt.alpha(Theme.fg, 0.16)
                                Txt { id: matchText; anchors.centerIn: parent; text: ruleRow.modelData.match; color: Theme.fg }
                            }
                            Txt {
                                id: detail
                                x: 260; y: 6
                                width: parent.width - x - 50
                                text: ruleRow.modelData.detail
                                wrapMode: Text.Wrap
                                color: Qt.alpha(Theme.fg, 0.9)
                                font.pixelSize: 12
                            }
                            Txt {
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                y: 7
                                text: "L" + ruleRow.modelData.line
                                opacity: rowMa.containsMouse ? 1 : 0
                                color: Qt.alpha(Theme.fg, 0.4)
                                font.pixelSize: 10
                            }
                            MouseArea {
                                id: rowMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: m => {
                                    if (m.button === Qt.RightButton) root.edit(ruleRow.modelData.line)
                                    else root.openEditor(ruleRow.modelData.line, ruleRow.modelData.section, ruleRow.modelData.match)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- editor ---
    Rectangle {
        id: editorPanel
        visible: root.editing !== null
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: edCol.implicitHeight + 24
        radius: 10
        color: Qt.alpha(Theme.fg, 0.05)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.3)

        Column {
            id: edCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 8

            Txt {
                width: parent.width
                text: !root.editing ? "" : root.editing.isNew ? "Nueva regla"
                    : "Editando: " + root.editing.title + "  ·  línea " + root.editing.line
                color: Theme.accent
                font.bold: true
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            // 1. the window
            Row {
                spacing: 8
                Lbl { text: "Ventana" }
                EditButton { anchors.verticalCenter: parent.verticalCenter; label: "󰆞 Elegir ventana"; primary: root.matchText === ""; onClicked: root.pick() }
                Rectangle {
                    visible: root.matchText !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    height: 24
                    width: matchChip.implicitWidth + 18
                    radius: 8
                    color: Qt.alpha(Theme.accent, 0.18)
                    border.width: 1
                    border.color: Qt.alpha(Theme.accent, 0.4)
                    Txt { id: matchChip; anchors.centerIn: parent; text: root.matchText; color: Theme.fg }
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.showMatch ? "ocultar campos de coincidencia" : (root.matchText === "" ? "o escribe su clase" : "editar coincidencia")
                    color: Theme.accent
                    font.pixelSize: 11
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.showMatch = !root.showMatch }
                }
            }
            Row {
                visible: root.showMatch
                spacing: 8
                Lbl { text: "" }
                EditField { id: classField; width: 200; placeholder: "clase"; onAccepted: root.save(); onEscaped: root.cancelEdit() }
                EditField { id: instField; width: 200; placeholder: "instancia"; onAccepted: root.save(); onEscaped: root.cancelEdit() }
                EditField { id: titleField; width: 260; placeholder: "título"; onAccepted: root.save(); onEscaped: root.cancelEdit() }
                Txt { anchors.verticalCenter: parent.verticalCenter; text: "xprop: WM_CLASS es instancia, clase; WM_NAME es el título"; color: Qt.alpha(Theme.fg, 0.4); font.pixelSize: 10 }
            }

            // 2. what it does
            Row {
                spacing: 24
                Lbl { text: "La ventana está" }
                Switch { label: "flotante"; on: root.floating; onToggled: { root.floating = !root.floating; if (!root.floating) root.centered = false } }
                Switch { label: "centrada"; on: root.centered; enabled: root.floating; onToggled: root.centered = !root.centered }
            }
            Row {
                spacing: 8
                Lbl { text: "Se abre en etiqueta" }
                Repeater {
                    model: 12
                    Pill {
                        required property int index
                        label: String(index + 1)
                        active: root.tags.indexOf(index + 1) >= 0
                        onClicked: {
                            const t = root.tags.slice()
                            const i = t.indexOf(index + 1)
                            if (i >= 0) t.splice(i, 1); else t.push(index + 1)
                            root.tags = t
                        }
                    }
                }
                Txt { anchors.verticalCenter: parent.verticalCenter; leftPadding: 6; text: root.tags.length ? "" : "ninguna: la etiqueta actual"; color: Qt.alpha(Theme.fg, 0.4) }
            }
            Row {
                visible: Quickshell.screens.length > 1
                spacing: 8
                Lbl { text: "En monitor" }
                Pill { label: "actual"; active: root.monitor === ""; onClicked: root.monitor = "" }
                Repeater {
                    model: Quickshell.screens.length
                    Pill { required property int index; label: String(index); active: root.monitor === String(index); onClicked: root.monitor = String(index) }
                }
            }

            // 3. scratchpad
            Row {
                spacing: 8
                Lbl { text: "Bloc rápido" }
                Switch {
                    label: root.scratch ? "un scratchpad: una tecla lo muestra y lo oculta" : "convertirla en scratchpad"
                    on: root.scratch
                    onToggled: {
                        root.scratch = !root.scratch
                        if (root.scratch) {
                            root.floating = true; root.centered = true
                            if (runField.text.trim() === "") runField.text = root.pickedCmd
                        }
                    }
                }
            }
            Row {
                visible: root.scratch
                spacing: 8
                Lbl { text: "" }
                EditField { id: scratchField; width: 110; placeholder: "id (una letra)"; onAccepted: root.save(); onEscaped: root.cancelEdit() }
                EditField { id: runField; width: 420; placeholder: "comando que lo abre, p.ej. kitty --name notes"; onAccepted: root.save(); onEscaped: root.cancelEdit() }
            }
            Row {
                visible: root.scratch
                spacing: 8
                Lbl { text: "Tecla de alternancia" }
                ChordField { id: chordField; onAccepted: root.save(); onEscaped: root.cancelEdit() }
                Txt { anchors.verticalCenter: parent.verticalCenter; text: root.bindLine ? "" : "se escribe en keybinds.conf al guardar"; color: Qt.alpha(Theme.fg, 0.4) }
            }

            Row {
                spacing: 8
                Lbl { text: "Nota" }
                EditField { id: descField; width: 420; placeholder: "opcional"; onAccepted: root.save(); onEscaped: root.cancelEdit() }
            }

            Row {
                spacing: 8
                EditButton { label: "Guardar"; primary: true; onClicked: root.save() }
                EditButton { label: "Cancelar"; onClicked: root.cancelEdit() }
                EditButton { visible: root.editing && !root.editing.isNew; label: "Eliminar"; ink: Theme.red; onClicked: root.remove() }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: 8
                    width: edCol.width - 300
                    elide: Text.ElideRight
                    visible: root.status !== ""
                    text: root.status
                    color: root.statusBad ? Theme.red : Qt.alpha(Theme.fg, 0.7)
                    font.bold: root.statusBad
                }
            }
        }
    }
}

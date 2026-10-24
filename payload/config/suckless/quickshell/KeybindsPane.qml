import QtQuick
import Quickshell
import Quickshell.Io

// Atajos de teclado tab of the settings panel (SettingsPopup): every bind in the
// WM config, grouped by its sections and laid out in columns. Type to
// filter; the chips narrow it to launchers (run=) or dwm's own actions
// (do=). Click a row to edit it in the panel below: record a chord (dwm
// lets go of its grabs meanwhile), change the label and what it does,
// Save; "+" on a section adds a bind; right-click a row to open the file
// at that line instead. Every write goes through the generator first,
// so a bad bind is refused with its reason and the file stays as it
// was. Saves pile up until the panel's Apply rebuilds and restarts dwm
// with them. Rows come from scripts/keybinds, re-read after every
// change. Nothing here is WM-specific: each setup's scripts/keybinds
// reads its own config format and answers the same verbs (rows, get,
// set, add, delete, check, apply).
Item {
    id: root
    required property var popup     // the SettingsPopup: closed around apply
    property int kindFilter: 0      // 0 all, 1 run, 2 do
    readonly property var kinds: ["Todo", "Aplicaciones", "dwm"]
    // sections folded to their header (click a header).
    // A search looks through folded sections too.
    property var collapsed: ({})
    // sections that start folded regardless of room: the power features
    readonly property var foldByDefault: ["scratch slots"]
    property int collapseGen: 0     // bumps so bindings re-read `collapsed`
    property int _autoFolded: 0
    function toggleSection(title) {
        const c = Object.assign({}, collapsed)
        if (c[title]) delete c[title]; else c[title] = true
        collapsed = c
        collapseGen++
    }
    function foldAll(fold) {
        const c = {}
        if (fold) for (const r of rows) c[r.section] = true
        collapsed = c
        collapseGen++
    }

    property var rows: []   // {section, keys: [["Super", "Q"], ...], desc, line, kind, cmd}
    property string query: ""
    // the unfiltered layout's height, so the card doesn't shrink as you type
    property real fullHeight: 0

    // the bind in the panel: {line, section, isNew}; the fields hold the rest
    property var editing: null
    property string editKind: "run"
    property bool dirty: false        // saved binds dwm isn't running yet
    property string status: ""
    property bool statusBad: false
    readonly property string tool: Theme.configDir + "/scripts/keybinds"

    readonly property int colSpacing: 24
    readonly property real innerWidth: width
    readonly property int columnCount:
        Math.max(1, Math.floor((innerWidth + colSpacing) / (440 + colSpacing)))
    readonly property real columnWidth:
        (innerWidth - (columnCount - 1) * colSpacing) / columnCount
    readonly property int keysWidth: 170
    readonly property var columns: layout(rows, query, kindFilter, columnCount, collapseGen)

    // the panel shows or hides this tab
    function shown() {
        search.text = ""
        status = ""
        loader.running = true
        Qt.callLater(() => search.forceActiveFocus())
    }
    function hidden() {
        stopRecording()
        editing = null
    }

    // one verb at a time; the exit code rides on the first output line
    Process {
        id: proc
        property var done: null
        stdout: StdioCollector {
            onStreamFinished: {
                const f = proc.done
                proc.done = null
                const i = text.indexOf("\n")
                if (f) f(parseInt(text.slice(0, i)), text.slice(i + 1))
            }
        }
    }
    function run(args, cb) {
        proc.done = cb
        proc.command = ["sh", "-c", 'o=$("$0" "$@" 2>&1); r=$?; printf "%s\\n%s" "$r" "$o"', root.tool].concat(args)
        proc.running = true
    }
    function setStatus(s, bad) { status = s; statusBad = bad }

    function openEditor(line, section) {
        run(["get", String(line)], (rc, out) => {
            const f = out.replace(/\n$/, "").split("\t")
            if (rc !== 0 || f.length < 5)
                return
            editing = { line: line, section: section, isNew: false,
                        title: (f[2] !== "" ? f[2].replace(/^!/, "") : f[4]) }
            chordField.text = (f[0] === "none" || f[0] === "" ? "" : f[0] + "+") + f[1]
            descField.text = f[2]
            editKind = f[3] === "do" ? "do" : "run"
            valueField.text = f[4]
            focusEditor()
        })
    }
    function addBind(section) {
        editing = { line: 0, section: section, isNew: true }
        chordField.text = "super+"
        descField.text = ""
        editKind = "run"
        valueField.text = ""
        focusEditor()
    }
    function focusEditor() {
        status = ""
        Qt.callLater(() => chordField.input.forceActiveFocus())
    }
    function cancelEdit() {
        stopRecording()
        editing = null
        Qt.callLater(() => search.forceActiveFocus())
    }
    function stopRecording() { chordField.stop() }
    function save() {
        if (!editing)
            return
        stopRecording()
        const e = editing
        const ck = chordField.split(chordField.text)
        if (ck[1] === "") { setStatus("la combinación necesita una tecla", true); return }
        if (valueField.text.trim() === "") {
            setStatus(editKind === "run" ? "¿qué debería ejecutar?" : "¿qué acción? (ver la cabecera del archivo)", true)
            return
        }
        const args = (e.isNew ? ["add", e.section] : ["set", String(e.line)])
            .concat([ck[0], ck[1], descField.text.trim(), editKind, valueField.text.trim()])
        run(args, (rc, out) => {
            if (rc !== 0) {
                setStatus(out.trim().replace(/^keybinds-gen: \S+:\d+: /gm, ""), true)
                return
            }
            dirty = true
            editing = null
            setStatus("guardado · Aplicar recompila dwm con él", false)
            loader.running = true
            Qt.callLater(() => search.forceActiveFocus())
        })
    }
    function remove() {
        const e = editing
        if (!e || e.isNew) { cancelEdit(); return }
        run(["delete", String(e.line)], (rc, out) => {
            if (rc !== 0) { setStatus(out.trim(), true); return }
            dirty = true
            editing = null
            setStatus("eliminado · Aplicar recompila dwm sin él", false)
            loader.running = true
        })
    }
    // the panel's Apply: it closes first (keybinds-apply may open a
    // terminal for the password and the panel holds the keyboard), then
    // keybinds-apply reports the outcome with a notification
    function apply() {
        stopRecording()
        dirty = false
        editing = null
        status = ""
        popup.visible = false
        Quickshell.execDetached([root.tool, "apply"])
    }

    Process {
        id: loader
        command: [Theme.configDir + "/scripts/keybinds"]
        stdout: StdioCollector {
            onStreamFinished: root.rows = root.parse(text)
        }
    }

    function parse(t) {
        const out = []
        for (const l of t.split("\n")) {
            const f = l.split("\t")
            if (f.length < 4)
                continue
            out.push({ section: f[0], desc: f[2], line: parseInt(f[3]), kind: f[4] ?? "", cmd: f[5] ?? "",
                       keys: f[1].split("|").map(k => k.split("+")) })
        }
        return out
    }

    function scrollBy(dy) {
        body.contentY = Math.max(0, Math.min(body.contentY + dy,
                                             body.contentHeight - body.height))
    }

    function edit(line) {
        popup.visible = false
        Quickshell.execDetached([root.tool, "open", String(line)])
    }


    // Filter (every typed word must match the label, keys, section or the
    // command / action behind the bind — "geany" finds Super+e),
    // group by section in config order, then fill the columns masonry-style:
    // each section goes to the currently shortest one.
    function layout(rows, q, kind, n, gen) {
        const words = q.toLowerCase().split(/\s+/).filter(w => w !== "")
        const sections = []
        for (const r of rows) {
            if (kind === 1 && r.kind !== "run") continue
            if (kind === 2 && r.kind !== "do") continue
            // a folded section keeps its header (and a count) while nothing is typed
            if (!words.length && collapsed[r.section]) {
                let s = sections.find(s => s.title === r.section)
                if (!s) { s = { title: r.section, rows: [], folded: true, hidden: 0 }; sections.push(s) }
                s.hidden++
                continue
            }
            if (words.length) {
                const hay = (r.section + " " + r.desc + " " + r.cmd + " "
                             + r.keys.map(k => k.join(" ")).join(" ")).toLowerCase()
                if (!words.every(w => hay.includes(w)))
                    continue
            }
            let s = sections.find(s => s.title === r.section)
            if (!s) {
                s = { title: r.section, rows: [], folded: false, hidden: 0 }
                sections.push(s)
            }
            s.rows.push(r)
        }
        const cols = [], heights = []
        for (let i = 0; i < n; i++) {
            cols.push([])
            heights.push(0)
        }
        for (const s of sections) {
            let c = 0
            for (let i = 1; i < n; i++)
                if (heights[i] < heights[c])
                    c = i
            cols[c].push(s)
            heights[c] += s.rows.length + 2   // + the header
        }
        return cols
    }

    // keycaps for a row: alternatives that share modifiers show them once
    // (Super ← / H), otherwise each combo in full (Vol Up / Super F12)
    function caps(alts) {
        const out = []
        const mods = a => a.slice(0, -1).join("+")
        if (alts.every(a => mods(a) === mods(alts[0]))) {
            alts[0].slice(0, -1).forEach(k => out.push({ t: k, cap: true }))
            alts.forEach((a, i) => {
                if (i) out.push({ t: "/", cap: false })
                out.push({ t: a[a.length - 1], cap: true })
            })
        } else {
            alts.forEach((a, i) => {
                if (i) out.push({ t: "/", cap: false })
                a.forEach(k => out.push({ t: k, cap: true }))
            })
        }
        return out
    }

    Rectangle {
        id: searchBox
        anchors.left: parent.left
        anchors.right: parent.right
        height: 34
        radius: 8
        color: Qt.alpha(Theme.fg, 0.06)
        border.width: 1
        border.color: search.activeFocus ? Qt.alpha(Theme.accent, 0.5) : "transparent"

        Txt {
            id: searchIcon
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "󰌌"
            color: Theme.accent
            font.pixelSize: 15
        }

        TextInput {
            id: search
            anchors.left: searchIcon.right
            anchors.leftMargin: 10
            anchors.right: hint.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.fg
            selectionColor: Qt.alpha(Theme.accent, 0.4)
            font.family: Theme.fontFamily
            font.pixelSize: 13
            clip: true
            onTextChanged: root.query = text
            // Escape clears the search first, then closes (Popout's handler)
            Keys.onEscapePressed: event => {
                if (text !== "")
                    text = ""
                else
                    event.accepted = false
            }
            // the list scrolls from the keyboard while you type
            Keys.onUpPressed: root.scrollBy(-60)
            Keys.onDownPressed: root.scrollBy(60)
            Keys.onPressed: event => {
                const ctrl = event.modifiers & Qt.ControlModifier
                if (!ctrl && (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown)) {
                    root.scrollBy((event.key === Qt.Key_PageUp ? -1 : 1) * body.height * 0.9)
                    event.accepted = true
                } else if (ctrl && (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)) {
                    // Ctrl+Tab cycles All · Apps · dwm, as the launcher's chips do
                    const n = root.kinds.length
                    root.kindFilter = (root.kindFilter + (event.key === Qt.Key_Backtab ? n - 1 : 1)) % n
                    event.accepted = true
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text === ""
                text: "Buscar atajos de teclado"
                color: Qt.alpha(Theme.fg, 0.35)
                font: search.font
            }
        }

        // All · Apps · dwm: launchers (run=) or dwm's own actions (do=)
        Row {
            id: kindChips
            anchors.right: hint.left
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Repeater {
                model: root.kinds
                Rectangle {
                    id: chip
                    required property string modelData
                    required property int index
                    readonly property bool active: root.kindFilter === index
                    height: 22
                    width: chipText.implicitWidth + 18
                    radius: 11
                    color: active ? Theme.accent : chipMa.containsMouse ? Qt.alpha(Theme.fg, 0.14) : Qt.alpha(Theme.fg, 0.06)
                    Txt { id: chipText; anchors.centerIn: parent; text: chip.modelData; color: chip.active ? Theme.bg : Qt.alpha(Theme.fg, 0.8); font.bold: chip.active }
                    MouseArea {
                        id: chipMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.kindFilter = chip.index; search.forceActiveFocus() }
                    }
                }
            }
        }

        Txt {
            id: hint
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width * 0.4)
            elide: Text.ElideRight
            text: root.status !== "" ? root.status
                : "haz clic en un atajo para editar · un encabezado pliega su sección · + añade uno · ctrl+tab " + root.kinds[(root.kindFilter + 1) % root.kinds.length].toLowerCase()
            color: root.status === "" ? Qt.alpha(Theme.fg, 0.35)
                 : root.statusBad ? Theme.red : Qt.alpha(Theme.fg, 0.7)
        }
    }

    // --- the editor panel, under the list while a bind is open ---
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

            // which bind this is, so a wrong click shows before you type
            Txt {
                text: !root.editing ? ""
                    : root.editing.isNew ? "Nuevo atajo en " + root.editing.section
                    : "Editando: " + root.editing.title + "  ·  línea " + root.editing.line
                color: Theme.accent
                font.bold: true
                font.pixelSize: 12
                elide: Text.ElideRight
                width: parent.width
            }

            Row {
                spacing: 8
                Txt {
                    width: 110
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Teclas"
                    color: Qt.alpha(Theme.fg, 0.7)
                }
                ChordField {
                    id: chordField
                    onAccepted: root.save()
                    onEscaped: root.cancelEdit()
                }
            }

            Row {
                spacing: 8
                Txt {
                    width: 110
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Descripción"
                    color: Qt.alpha(Theme.fg, 0.7)
                }
                EditField {
                    id: descField
                    width: edCol.width - 118
                    placeholder: "lo que dirá la ayuda (opcional; ! al inicio la fija)"
                    onAccepted: root.save()
                    onEscaped: root.cancelEdit()
                }
            }

            Row {
                spacing: 8
                Txt {
                    width: 110
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Hace"
                    color: Qt.alpha(Theme.fg, 0.7)
                }
                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: [["run", "ejecutar un comando"], ["do", "acción de dwm"]]
                        Rectangle {
                            required property var modelData
                            readonly property bool on: root.editKind === modelData[0]
                            height: 24
                            width: kt.implicitWidth + 20
                            radius: 12
                            color: on ? Theme.accent : kindMa.containsMouse ? Qt.alpha(Theme.fg, 0.14) : Qt.alpha(Theme.fg, 0.06)
                            Txt { id: kt; anchors.centerIn: parent; text: parent.modelData[1]; color: parent.on ? Theme.bg : Qt.alpha(Theme.fg, 0.8); font.bold: parent.on }
                            MouseArea {
                                id: kindMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.editKind = parent.modelData[0]; valueField.input.forceActiveFocus() }
                            }
                        }
                    }
                }
                EditField {
                    id: valueField
                    onAccepted: root.save()
                    onEscaped: root.cancelEdit()
                    width: edCol.width - 118 - 8 - 230
                    placeholder: root.editKind === "run" ? "línea de comandos, p.ej. firefox-esr -private-window  (programas de terminal: kitty -e nvim)"
                                                         : "acción y argumento, p.ej. focusstack next"
                }
            }

            Row {
                spacing: 8
                EditButton { label: "Guardar"; primary: true; onClicked: root.save() }
                EditButton { label: "Cancelar"; onClicked: root.cancelEdit() }
                EditButton {
                    visible: root.editing && !root.editing.isNew
                    label: "Eliminar"
                    ink: Theme.red
                    onClicked: root.remove()
                }
                // why a save was refused, right where Save is
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

    Flickable {
        id: body
        anchors.top: searchBox.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: root.editing ? editorPanel.top : parent.bottom
        anchors.bottomMargin: root.editing ? 14 : 0
        contentWidth: width
        contentHeight: cols.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        onContentHeightChanged: {
            if (root.query === "")
                root.fullHeight = contentHeight
            contentY = Math.max(0, Math.min(contentY, contentHeight - height))
            // first measure: fold the default sections (only those — a
            // list that doesn't fit scrolls; folding everything on small
            // screens hid the binds people came to read)
            if (root._autoFolded === 0 && contentHeight > 0 && root.rows.length) {
                root._autoFolded = 1
                const c = Object.assign({}, root.collapsed)
                for (const s of root.foldByDefault) c[s] = true
                root.collapsed = c
                root.collapseGen++
            }
        }

        Txt {
            visible: root.query !== "" && root.columns.every(c => c.length === 0)
            text: "Ningún atajo coincide con \"" + root.query + "\""
            color: Qt.alpha(Theme.fg, 0.5)
            font.pixelSize: 12
        }

        Row {
            id: cols
            spacing: root.colSpacing

            Repeater {
                model: root.columns

                Column {
                    id: column
                    required property var modelData
                    width: root.columnWidth
                    spacing: 14

                    Repeater {
                        model: column.modelData

                        Column {
                            id: section
                            required property var modelData
                            width: parent.width
                            spacing: 1

                            Item {
                                width: parent.width
                                height: 24
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.rightMargin: 28
                                    radius: 4
                                    color: titleMa.containsMouse ? Qt.alpha(Theme.fg, 0.06) : "transparent"
                                }
                                Txt {
                                    id: secTitle
                                    anchors.verticalCenter: parent.verticalCenter
                                    leftPadding: 6
                                    text: (section.modelData.folded ? "▸ " : "▾ ") + section.modelData.title
                                        + (section.modelData.folded ? "   " + section.modelData.hidden : "")
                                    color: Theme.accent
                                    font.bold: true
                                    font.capitalization: Font.AllUppercase
                                    font.letterSpacing: 1
                                }
                                MouseArea {
                                    id: titleMa
                                    anchors.fill: parent
                                    anchors.rightMargin: 28
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleSection(section.modelData.title)
                                }
                                // a new bind in this section
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    width: 18
                                    height: 18
                                    radius: 4
                                    color: addMa.containsMouse ? Qt.alpha(Theme.accent, 0.3) : Qt.alpha(Theme.fg, 0.06)
                                    Txt { anchors.centerIn: parent; text: "+"; color: Theme.accent; font.bold: true }
                                    MouseArea {
                                        id: addMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.addBind(section.modelData.title)
                                    }
                                }
                            }

                            Repeater {
                                model: section.modelData.rows

                                Rectangle {
                                    id: bindRow
                                    required property var modelData
                                    width: parent.width
                                    height: Math.max(keycaps.height, label.implicitHeight) + 8
                                    radius: 6
                                    color: rowMa.containsMouse ? Qt.alpha(Theme.fg, 0.08) : "transparent"

                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Flow {
                                        id: keycaps
                                        x: 6
                                        y: 4
                                        width: root.keysWidth
                                        spacing: 3

                                        Repeater {
                                            model: root.caps(bindRow.modelData.keys)

                                            Rectangle {
                                                id: cap
                                                required property var modelData
                                                height: 20
                                                width: capText.implicitWidth + (modelData.cap ? 12 : 2)
                                                radius: 4
                                                color: modelData.cap ? Qt.alpha(Theme.fg, 0.08) : "transparent"
                                                border.width: modelData.cap ? 1 : 0
                                                border.color: Qt.alpha(Theme.fg, 0.16)

                                                Txt {
                                                    id: capText
                                                    anchors.centerIn: parent
                                                    text: cap.modelData.t
                                                    color: cap.modelData.cap ? Theme.fg : Qt.alpha(Theme.fg, 0.4)
                                                }
                                            }
                                        }
                                    }

                                    Txt {
                                        id: label
                                        x: keycaps.x + root.keysWidth + 10
                                        y: 4 + 2
                                        width: parent.width - x - lineNo.width - 12
                                        text: bindRow.modelData.desc
                                        wrapMode: Text.Wrap
                                        color: Qt.alpha(Theme.fg, 0.9)
                                        font.pixelSize: 12
                                    }

                                    // what it runs and where it lives, shown on hover
                                    Txt {
                                        id: lineNo
                                        anchors.right: parent.right
                                        anchors.rightMargin: 6
                                        y: 4 + 3
                                        width: Math.min(implicitWidth, parent.width * 0.45)
                                        elide: Text.ElideLeft
                                        text: bindRow.modelData.cmd + "  ·  L" + bindRow.modelData.line
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
                                            if (m.button === Qt.RightButton)
                                                root.edit(bindRow.modelData.line)
                                            else
                                                root.openEditor(bindRow.modelData.line, bindRow.modelData.section)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // only on screens too short for the whole list (768p laptops)
    Rectangle {
        visible: body.contentHeight > body.height
        anchors.right: body.right
        anchors.rightMargin: -8
        y: body.y + body.visibleArea.yPosition * body.height
        width: 3
        height: body.visibleArea.heightRatio * body.height
        radius: 2
        color: Qt.alpha(Theme.fg, 0.3)
    }
}

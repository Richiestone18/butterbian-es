import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper tab of the settings panel: a row of themes over a thumbnail
// grid of the config folder's wallpaper/. Picking an image asks butterpal
// (a small C program the setups share) for its palette and hands both to
// scripts/wallpaper-theme, which re-themes the desktop; a theme
// (scripts/themes) then puts its own colors on that image. The panel stays
// open through both. No window is needed, so IPC random / set work with it
// closed.
Item {
    id: root
    required property var popup

    property var wallpapers: []
    property string applyingPath: ""
    // the wallpaper on screen (scripts/themes wallpaper): the grid's cursor
    // starts on it and a pick moves the cursor there
    property string currentWallpaper: ""
    property bool randomPending: false
    // the themes beside "Desde el fondo" (scripts/themes list) and the one
    // in use: "" while the colors come from the wallpaper
    property var themes: []
    property string currentTheme: ""
    readonly property string themesScript: Theme.configDir + "/scripts/themes"
    // the wallpapers the theme in use names as its own, marked in the grid
    readonly property var themeWalls: {
        const t = themes.find(x => x.id === currentTheme)
        return t ? t.walls : []
    }
    // thumbnails decode at the size they show, in device pixels
    readonly property real thumbScale: popup.s * Screen.devicePixelRatio

    // re-scan the wallpaper dir on every show, so new files just show up;
    // the grid takes key focus so arrows/Enter work without the mouse
    function shown() {
        lister.running = true
        themeLister.running = true
        themeCurrent.running = true
        wallCurrent.running = true
        grid.forceActiveFocus()
    }
    function hidden() {}

    // the folder the grid scans — open it in the file manager so new
    // images can be dropped in; they appear on the tab's next open
    function openFolder() {
        Quickshell.execDetached(["xdg-open", Theme.configDir + "/wallpaper"])
        popup.visible = false
    }

    function applyRandom() {
        randomPending = true
        lister.running = true
    }

    // a theme: its colors on the wallpaper already up; "": back to the
    // colors of the wallpaper. The picture never changes here, and the panel
    // stays open, to try another theme or pick an image.
    function applyTheme(id) {
        currentTheme = id
        Quickshell.execDetached(id === "" ? [themesScript, "off"] : [themesScript, "apply", id])
    }
    function stepTheme(d) {
        const ids = [""].concat(themes.map(t => t.id))
        applyTheme(ids[(ids.indexOf(currentTheme) + d + ids.length) % ids.length])
    }

    // a wallpaper always starts from its own colors (butterpal); the panel
    // stays open, so a theme can be tried on it next
    function apply(path) {
        if (palette.running)
            return
        currentTheme = ""
        Quickshell.execDetached([themesScript, "forget"])
        applyingPath = path
        currentWallpaper = path
        placeCursor()
        palette.running = true
    }

    // the cursor on the wallpaper in use, the first one if it isn't in the
    // folder; by file name, as the folder is reached through a link
    function placeCursor() {
        const name = currentWallpaper.split("/").pop()
        const i = wallpapers.findIndex(w => w.split("/").pop() === name)
        grid.currentIndex = i >= 0 ? i : wallpapers.length > 0 ? 0 : -1
    }

    // butterpal prints the 24 colors wallpaper-theme takes, one a line
    property var _colors: []
    Process {
        id: palette
        command: ["butterpal", root.applyingPath]
        stdout: SplitParser {
            onRead: line => { if (/^#[0-9a-f]{6}$/i.test(line.trim())) root._colors.push(line.trim()) }
        }
        onRunningChanged: if (running) root._colors = []
        onExited: (code, status) => {
            if (root._colors.length === 24) {
                Quickshell.execDetached([Theme.configDir + "/scripts/wallpaper-theme", root.applyingPath]
                    .concat(root._colors))
            } else {
                Quickshell.execDetached(["notify-send", "-a", "Wallpaper", "-u", "critical", "Tema del fondo",
                    "Sin paleta de " + root.applyingPath.split("/").pop()
                    + " (¿está instalado butterpal? Ejecuta el instalador)"])
            }
            root.applyingPath = ""
        }
    }

    property var _themes: []
    Process {
        id: themeLister
        command: [root.themesScript, "list"]
        stdout: SplitParser {
            onRead: line => {
                const f = line.split("\t")
                if (f.length === 4)
                    root._themes.push({ id: f[0], name: f[1], walls: f[2].split(" ").filter(w => w !== ""),
                                        colors: f[3].split(" ") })
            }
        }
        onRunningChanged: {
            if (running) root._themes = []
            else root.themes = root._themes
        }
    }
    // scripts/themes remembers the theme in use; nothing = from the wallpaper
    property string _current: ""
    Process {
        id: themeCurrent
        command: [root.themesScript, "current"]
        stdout: SplitParser { onRead: line => root._current = line.trim() }
        onRunningChanged: {
            if (running) root._current = ""
            else root.currentTheme = root._current
        }
    }

    Process {
        id: wallCurrent
        command: [root.themesScript, "wallpaper"]
        stdout: SplitParser { onRead: line => root.currentWallpaper = line.trim() }
        onRunningChanged: if (!running) root.placeCursor()
    }

    property var _found: []
    Process {
        id: lister
        // no SVGs: Qt's loader chokes on ones with external references
        command: ["sh", "-c",
            "find \"" + Theme.configDir + "/wallpaper\" -maxdepth 1 -type f " +
            "\\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \\) | sort"]
        stdout: SplitParser {
            onRead: line => { if (line.trim() !== "") root._found.push(line.trim()) }
        }
        onRunningChanged: {
            if (running) {
                root._found = []
            } else {
                root.wallpapers = root._found
                if (root.randomPending) {
                    root.randomPending = false
                    if (root.wallpapers.length > 0)
                        root.apply(root.wallpapers[
                            Math.floor(Math.random() * root.wallpapers.length)])
                }
            }
        }
    }

    Item {
        anchors.fill: parent

        // "open folder" row above the grid: mouse or `o`
        Rectangle {
            id: folderRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            height: 30
            radius: 6
            color: folderMouse.containsMouse ? Qt.alpha(Theme.accent, 0.2)
                                             : Qt.alpha(Theme.fg, 0.06)

            Row {
                anchors.centerIn: parent
                spacing: 8
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰉋"
                    color: Theme.accent
                    font.pixelSize: 14
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Abrir carpeta de fondos de pantalla"
                    font.pixelSize: 12
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "o"
                    color: Qt.alpha(Theme.fg, 0.5)
                    font.pixelSize: 10
                }
            }

            MouseArea {
                id: folderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openFolder()
            }
        }

        // "Desde el fondo" (the colors butterpal reads from the image), then
        // the themes, each drawn in its own colors: ten chips to a line
        // (fewer in a narrow panel), all of them showing.
        // Mouse, or [ and ] from the grid.
        Flow {
            id: themeRow
            anchors.top: folderRow.bottom
            anchors.topMargin: 4
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            spacing: 6
            // ten columns, or as many as fit at 96 or wider, sharing the width evenly
            readonly property int cols: Math.min(10, Math.max(1, Math.floor((width + spacing) / (96 + spacing))))
            readonly property real chipWidth: Math.floor((width - (cols - 1) * spacing) / cols)

            Repeater {
                model: [{ id: "", name: "Desde el fondo", colors: [] }].concat(root.themes)

                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool own: modelData.id === ""
                    readonly property bool active: root.currentTheme === modelData.id
                    width: themeRow.chipWidth
                    height: 38
                    radius: 6
                    color: own ? Qt.alpha(Theme.fg, 0.06) : modelData.colors[0]
                    border.width: active ? 2 : chipMouse.containsMouse ? 1 : 0
                    border.color: active ? Theme.accent : Qt.alpha(Theme.fg, 0.5)

                    Column {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 5
                        Txt {
                            width: parent.width
                            text: chip.modelData.name
                            color: chip.own ? Theme.fg : chip.modelData.colors[2]
                            elide: Text.ElideRight
                        }
                        Row {
                            spacing: 4
                            Repeater {
                                // primary, secondary, alert
                                model: chip.own ? [Theme.accent, Theme.blue, Theme.red]
                                                : [chip.modelData.colors[4], chip.modelData.colors[5], chip.modelData.colors[6]]
                                Rectangle {
                                    required property var modelData
                                    width: 22
                                    height: 6
                                    radius: 3
                                    color: modelData
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.applyTheme(chip.modelData.id)
                    }
                }
            }
        }

        GridView {
            id: grid
            anchors.top: themeRow.bottom
            anchors.topMargin: 4
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true
            cellWidth: 176
            cellHeight: 103
            cacheBuffer: cellHeight * 2
            model: root.wallpapers

            // keyboard: arrows/hjkl move, Enter/Space applies, [ and ] step
            // through the themes, o opens the folder, Escape closes (the
            // focused grid gets it before the panel)
            focus: true
            keyNavigationWraps: true
            highlightFollowsCurrentItem: true
            highlightMoveDuration: 0
            currentIndex: -1
            onModelChanged: root.placeCursor()
            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_H: moveCurrentIndexLeft(); break
                case Qt.Key_L: moveCurrentIndexRight(); break
                case Qt.Key_K: moveCurrentIndexUp(); break
                case Qt.Key_J: moveCurrentIndexDown(); break
                case Qt.Key_Return:
                case Qt.Key_Enter:
                case Qt.Key_Space:
                    if (currentIndex >= 0)
                        root.apply(root.wallpapers[currentIndex])
                    break
                case Qt.Key_O:
                    root.openFolder()
                    break
                case Qt.Key_BracketLeft: root.stepTheme(-1); break
                case Qt.Key_BracketRight: root.stepTheme(1); break
                case Qt.Key_Escape:
                    popup.visible = false
                    break
                default:
                    event.accepted = false
                    return
                }
                event.accepted = true
            }

            delegate: Item {
                id: cell
                required property string modelData
                readonly property bool busy: root.applyingPath === modelData
                readonly property bool current: grid.activeFocus && GridView.isCurrentItem
                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 6
                    color: Qt.alpha(Theme.fg, 0.06)

                    Image {
                        anchors.fill: parent
                        anchors.margins: 1
                        source: "file://" + cell.modelData
                        sourceSize: Qt.size(grid.cellWidth * root.thumbScale, grid.cellHeight * root.thumbScale)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        clip: true
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: "transparent"
                        border.width: cell.busy ? 3 : (mouse.containsMouse || cell.current) ? 2 : 0
                        border.color: cell.busy ? Theme.accent : Qt.alpha(Theme.accent, 0.8)

                        SequentialAnimation on opacity {
                            running: cell.busy
                            loops: Animation.Infinite
                            alwaysRunToEnd: true
                            NumberAnimation { to: 0.4; duration: 350 }
                            NumberAnimation { to: 1.0; duration: 350 }
                        }
                    }

                    // one of the theme's own wallpapers
                    Rectangle {
                        visible: root.themeWalls.indexOf(cell.modelData.split("/").pop()) >= 0
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6
                        width: 10
                        height: 10
                        radius: 5
                        color: Theme.accent
                        border.width: 1
                        border.color: Theme.bg
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.apply(cell.modelData)
                    }
                }
            }
        }
    }
}

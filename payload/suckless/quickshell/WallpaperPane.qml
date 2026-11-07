import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper tab of the settings panel: a thumbnail grid of the config
// folder's wallpaper/. Picking one asks butterpal (a small C program the
// setups share) for the image's palette and hands both to
// scripts/wallpaper-theme, which re-themes the desktop. No window is
// needed, so IPC random / set work with the panel closed.
Item {
    id: root
    required property var popup

    property var wallpapers: []
    property string applyingPath: ""
    property bool randomPending: false
    // thumbnails decode at the size they show, in device pixels
    readonly property real thumbScale: popup.s * Screen.devicePixelRatio

    // re-scan the wallpaper dir on every show, so new files just show up;
    // the grid takes key focus so arrows/Enter work without the mouse
    function shown() {
        lister.running = true
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

    function apply(path) {
        if (palette.running)
            return
        applyingPath = path
        palette.running = true
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
                popup.visible = false
            } else {
                Quickshell.execDetached(["notify-send", "-a", "Wallpaper", "-u", "critical", "Wallpaper theme",
                    "Sin paleta de " + root.applyingPath.split("/").pop()
                    + " (¿está instalado butterpal? Ejecuta el instalador)"])
            }
            root.applyingPath = ""
        }
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

        GridView {
            id: grid
            anchors.top: folderRow.bottom
            anchors.topMargin: 4
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true
            cellWidth: 176
            cellHeight: 103
            cacheBuffer: cellHeight * 2
            model: root.wallpapers

            // keyboard: arrows/hjkl move, Enter/Space applies, o opens the
            // folder, Escape closes (the focused grid gets it before the panel)
            focus: true
            keyNavigationWraps: true
            highlightFollowsCurrentItem: true
            highlightMoveDuration: 0
            currentIndex: -1
            onModelChanged: currentIndex = count > 0 ? 0 : -1
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

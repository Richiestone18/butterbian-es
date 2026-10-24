//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {}
    }

    // a kept Displays layout comes back first (only what differs, so a
    // plain restart doesn't touch the outputs)
    Process {
        id: displaysApply
        running: true
        command: [Theme.configDir + "/scripts/displays", "apply"]
    }
    // ...and again when a monitor is plugged in or a dock wakes up, which
    // also paints the wallpaper onto the newcomer
    Process {
        id: displaysHotplug
        command: [Theme.configDir + "/scripts/displays", "hotplug"]
    }
    Connections {
        target: Quickshell
        function onScreensChanged() { displaysHotplug.running = true }
    }

    // Displays tab's "identify": each output's name, big, for a moment
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: Wm.identifyOutputs
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            anchors { top: true; bottom: true; left: true; right: true }

            Rectangle {
                anchors.centerIn: parent
                width: ident.implicitWidth + 60
                height: ident.implicitHeight + 40
                radius: Theme.barRadius
                color: Theme.bg
                border.width: 2
                border.color: Theme.accent
                Txt {
                    id: ident
                    anchors.centerIn: parent
                    text: modelData.name + "\n" + modelData.width + " × " + modelData.height
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 40
                    font.bold: true
                }
            }
        }
    }
}

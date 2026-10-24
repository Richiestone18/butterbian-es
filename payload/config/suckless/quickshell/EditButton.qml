import QtQuick

// A button of the settings panel's editors: label on a soft pill, or
// accent-filled when primary.
Rectangle {
    id: btn
            property string label: ""
        property bool primary: false
        property color ink: primary ? Theme.bg : Theme.fg
        signal clicked()
        height: 28
        width: btnText.implicitWidth + 24
        radius: 6
        color: primary ? Theme.accent
             : btnMa.containsMouse ? Qt.alpha(Theme.fg, 0.14) : Qt.alpha(Theme.fg, 0.07)
        Behavior on color { ColorAnimation { duration: 120 } }
        Txt {
            id: btnText
            anchors.centerIn: parent
            text: btn.label
            color: btn.ink
            font.bold: btn.primary
        }
        MouseArea {
            id: btnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
}

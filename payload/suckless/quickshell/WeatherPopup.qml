import QtQuick
import Quickshell
import Quickshell.Io

// Weather popup, from WeatherData: now (glyph, temperature, condition,
// place), feels-like, humidity and wind, the next eight hours and the
// week, each day's low and high on a bar spanning the week's range. The
// row at the foot shows the location and units and unfolds their settings:
// a location field (Enter pins it, "auto" unpins it) and the units, which
// write the weather-location and weather-units files in the config folder,
// which WeatherData watches. Right-click the module to open with the field focused. "radar"
// swaps the forecast for the last hour of rain (RadarView).
Popout {
    id: root
    ipcNames: ["weather"]
    function ipc(fn, arg) {
        if (fn === "toggle") root.visible = !root.visible
        else if (fn === "radar") { root.visible = true; root.radar = true }
    }

    readonly property string condition: WeatherData.condition
    readonly property string feels: WeatherData.feels
    readonly property string wind: WeatherData.wind
    readonly property string place: WeatherData.place
    readonly property var days: WeatherData.days
    readonly property bool failed: WeatherData.failed
    readonly property real lat: WeatherData.lat
    readonly property real lon: WeatherData.lon
    property bool radar: false

    // the saved settings ("" = auto)
    readonly property string location: WeatherData.location
    readonly property string units: WeatherData.unitsOverride

    readonly property string locationFile: Theme.configDir + "/weather-location"
    readonly property string unitsFile: Theme.configDir + "/weather-units"
    readonly property bool localeF: Qt.locale().measurementSystem !== Locale.MetricSystem

    cardWidth: 440
    cardHeight: col.implicitHeight + 2 * cardPadding

    // the location and units, folded away until asked for
    property bool settingsOpen: false

    onVisibleChanged: {
        if (visible)
            field.text = location
        else {
            radar = false
            settingsOpen = false
        }
    }
    onLocationChanged: if (!field.activeFocus) field.text = location

    function openSettings() {
        visible = true
        settingsOpen = true
        // after Popout's own focus grab on open
        Qt.callLater(() => {
            field.forceActiveFocus()
            field.selectAll()
        })
    }

    // write a settings file, or remove it for "" (auto); the value goes
    // in as an argument, never spliced into the shell
    function save(path, value) {
        if (value === "")
            Quickshell.execDetached(["rm", "-f", path])
        else
            Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" > \"$2\"",
                                     "sh", value, path])
    }

    function saveLocation() {
        const v = field.text.trim()
        field.text = v
        if (v !== location)
            save(locationFile, v)
    }

    // the week's coldest low and warmest high: the span the day bars sit in
    readonly property real weekLo: days.reduce((m, d) => Math.min(m, d.loN), 999)
    readonly property real weekHi: days.reduce((m, d) => Math.max(m, d.hiN), -999)

    // one reading under the hero: glyph, value, what it is
    component Stat: Rectangle {
        property string glyph
        property string value
        property string name
        width: (parent.width - 2 * parent.spacing) / 3
        height: 44
        radius: 8
        color: Qt.alpha(Theme.fg, 0.06)

        Txt {
            id: statGlyph
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: parent.glyph
            color: Theme.cyan
            font.pixelSize: 16
        }
        Column {
            anchors.left: statGlyph.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Txt { text: parent.parent.value; font.pixelSize: 13; font.bold: true }
            Txt { text: parent.parent.name; color: Qt.alpha(Theme.fg, 0.5); font.pixelSize: 10 }
        }
    }

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10

        // now: the glyph and temperature large, the condition and place
        // beside them, radar at the right
        Item {
            width: parent.width
            height: 64

            Txt {
                id: heroGlyph
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: root.failed ? "󰅙" : WeatherData.glyphFor(WeatherData.code, WeatherData.night)
                color: root.failed ? Theme.red : Theme.yellow
                font.pixelSize: 48
            }
            Txt {
                id: heroTemp
                anchors.left: heroGlyph.right
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.failed
                text: WeatherData.temp + "°"
                font.pixelSize: 44
                font.bold: true
            }
            Column {
                anchors.left: root.failed ? heroGlyph.right : heroTemp.right
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                // the condition stops short of the radar button; the place
                // under it has the full width
                Txt {
                    width: parent.width - (radarBtn.visible ? radarBtn.width + 10 : 0)
                    text: root.failed ? "Sin clima" : root.condition
                    font.pixelSize: 15
                    font.bold: true
                    elide: Text.ElideRight
                }
                // where it's for (shows when a VPN fools the IP lookup)
                Txt {
                    width: parent.width
                    text: root.failed
                        ? "no se pudo obtener" + (root.location !== "" ? " de \"" + root.location + "\"" : "")
                        : "󰍎 " + root.place
                    color: root.failed ? Theme.red : Qt.alpha(Theme.fg, 0.55)
                    elide: Text.ElideRight
                }
            }

            // forecast ⇄ radar (radar needs a located forecast)
            Btn {
                id: radarBtn
                anchors.right: parent.right
                anchors.top: parent.top
                visible: root.lat !== 0 || root.lon !== 0
                active: root.radar
                glyph: "󰖎"
                text: active ? "forecast" : "radar"
                padding: 36
                restColor: Qt.alpha(Theme.fg, 0.07)
                ink: active ? Theme.bg : Theme.fg
                onClicked: root.radar = !root.radar
            }
        }

        RadarView {
            visible: root.radar
            active: root.radar && root.visible
            lat: root.lat
            lon: root.lon
            width: parent.width
            height: 300
        }

        Row {
            visible: !root.radar && !root.failed
            width: parent.width
            spacing: 6
            Stat { glyph: "󰔏"; value: root.feels + "°"; name: "sensación térmica" }
            Stat { glyph: "󰖌"; value: WeatherData.humidity; name: "humidity" }
            Stat { glyph: "󰖝"; value: root.wind; name: "wind" }
        }

        SectionLabel {
            visible: hoursRow.visible
            text: "Próximas horas"
        }
        Row {
            id: hoursRow
            visible: !root.radar && WeatherData.hours.length > 0
            width: parent.width
            spacing: 5

            Repeater {
                model: WeatherData.hours

                Rectangle {
                    id: hour
                    required property var modelData
                    required property int index
                    width: (parent.width - (WeatherData.hours.length - 1) * parent.spacing) / WeatherData.hours.length
                    height: 84
                    radius: 8
                    color: index === 0 ? Qt.alpha(Theme.accent, 0.18) : Qt.alpha(Theme.fg, 0.06)

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        spacing: 4

                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: hour.modelData.label
                            color: Qt.alpha(Theme.fg, hour.index === 0 ? 0.9 : 0.55)
                            font.pixelSize: 10
                        }
                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: hour.modelData.glyph
                            color: Theme.yellow
                            font.pixelSize: 18
                        }
                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: hour.modelData.temp + "°"
                            font.pixelSize: 12
                            font.bold: true
                        }
                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: hour.modelData.rain >= 30
                            text: hour.modelData.rain + "%"
                            color: Theme.cyan
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }

        SectionLabel {
            visible: daysCol.visible
            text: "Esta semana"
        }
        // each day: its low and high, and a bar placing them in the week's span
        Column {
            id: daysCol
            visible: !root.radar && root.days.length > 0
            width: parent.width
            spacing: 2

            Repeater {
                model: root.days

                Rectangle {
                    id: day
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: 26
                    radius: 6
                    color: index % 2 === 0 ? Qt.alpha(Theme.fg, 0.04) : "transparent"

                    Txt {
                        id: dayName
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 50
                        text: day.modelData.label
                        color: day.index === 0 ? Theme.fg : Qt.alpha(Theme.fg, 0.7)
                        font.pixelSize: 12
                        font.bold: day.index === 0
                    }
                    Txt {
                        id: dayGlyph
                        anchors.left: dayName.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        horizontalAlignment: Text.AlignHCenter
                        text: day.modelData.glyph
                        color: Theme.yellow
                        font.pixelSize: 16
                    }
                    Txt {
                        id: dayRain
                        anchors.left: dayGlyph.right
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        text: day.modelData.rain >= 30 ? "󰖌 " + day.modelData.rain + "%" : ""
                        color: Theme.cyan
                        font.pixelSize: 10
                    }
                    Txt {
                        id: dayLo
                        anchors.left: dayRain.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        horizontalAlignment: Text.AlignRight
                        text: day.modelData.lo + "°"
                        color: Qt.alpha(Theme.fg, 0.6)
                        font.pixelSize: 12
                    }
                    Rectangle {
                        id: span
                        anchors.left: dayLo.right
                        anchors.leftMargin: 10
                        anchors.right: dayHi.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        height: 5
                        radius: 3
                        color: Qt.alpha(Theme.fg, 0.1)

                        readonly property real range: Math.max(root.weekHi - root.weekLo, 1)
                        Rectangle {
                            x: (day.modelData.loN - root.weekLo) / span.range * span.width
                            width: Math.max((day.modelData.hiN - day.modelData.loN) / span.range * span.width, 5)
                            height: parent.height
                            radius: 3
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Theme.cyan }
                                GradientStop { position: 1; color: Theme.yellow }
                            }
                        }
                    }
                    Txt {
                        id: dayHi
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        horizontalAlignment: Text.AlignRight
                        text: day.modelData.hi + "°"
                        font.pixelSize: 12
                        font.bold: true
                    }
                }
            }
        }

        Rectangle {
            visible: !root.radar
            width: parent.width - 8
            anchors.horizontalCenter: parent.horizontalCenter
            height: 1
            color: Qt.alpha(Theme.fg, 0.15)
        }

        // what's set, and the way to the settings below
        ListRow {
            visible: !root.radar
            height: 34
            glyphSize: 15
            fontSize: 13
            glyphWidth: 0
            glyph: "󰍎"
            active: root.settingsOpen
            text: (root.location !== "" ? root.location : "Ubicación automática")
                + "  ·  " + (WeatherData.useF ? "°F" : "°C")
            onClicked: root.settingsOpen = !root.settingsOpen
        }

        Column {
            id: settings
            visible: !root.radar && root.settingsOpen
            width: parent.width
            spacing: 8

            // location: type + Enter pins it; "auto" goes back to by-IP
            Row {
                width: parent.width
                spacing: 6

                Rectangle {
                    width: parent.width - (autoBtn.visible ? autoBtn.width + parent.spacing : 0)
                    height: 30
                    radius: 8
                    color: Qt.alpha(Theme.fg, 0.06)
                    border.width: 1
                    border.color: field.activeFocus ? Qt.alpha(Theme.accent, 0.5) : "transparent"

                    Txt {
                        id: pin
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰍎"
                        color: Theme.accent
                        font.pixelSize: 13
                    }

                    // under the field, so a click on the text still places the cursor
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.IBeamCursor
                        onClicked: field.forceActiveFocus()
                    }

                    TextInput {
                        id: field
                        anchors.left: pin.right
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.fg
                        selectionColor: Qt.alpha(Theme.accent, 0.4)
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        selectByMouse: true
                        clip: true
                        onAccepted: {
                            root.saveLocation()
                            focus = false
                        }
                        // Escape drops an unsaved edit first, then closes (Popout)
                        Keys.onEscapePressed: event => {
                            if (text !== root.location)
                                text = root.location
                            else
                                event.accepted = false
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: field.text === ""
                            text: "Automático (por IP) · escribe una ciudad o código postal"
                            color: Qt.alpha(Theme.fg, 0.35)
                            font: field.font
                        }
                    }
                }

                Btn {
                    id: autoBtn
                    visible: root.location !== ""
                    text: "automático"
                    height: 30
                    padding: 16
                    fadeMs: 0
                    onClicked: {
                        field.text = ""
                        root.save(root.locationFile, "")
                    }
                }
            }

            // units: auto (from the locale) / °F / °C
            Row {
                width: parent.width
                spacing: 6

                Repeater {
                    model: [
                        { value: "", label: "automático · " + (root.localeF ? "°F" : "°C") },
                        { value: "f", label: "°F" },
                        { value: "c", label: "°C" }
                    ]

                    Btn {
                        required property var modelData
                        active: root.units === modelData.value
                        text: modelData.label
                        width: (parent.width - 2 * parent.spacing) / 3
                        height: 26
                        onClicked: root.save(root.unitsFile, modelData.value)
                    }
                }
            }

            // Open-Meteo's data is CC BY 4.0: credit where the source is set
            Txt {
                text: "clima por open-meteo.com"
                color: Qt.alpha(Theme.fg, 0.35)
                font.pixelSize: 10
            }
        }
    }
}

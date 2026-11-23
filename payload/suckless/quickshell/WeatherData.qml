pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The weather, fetched once for every output's bar: Open-Meteo (no API
// key) every 30 minutes, right away when the location changes, and again
// in 3 minutes after a failure. Location: weather-location in the config
// folder, a city, "city, region", a zip or "lat, lon", looked up with
// Open-Meteo's geocoding; absent = by IP through ipinfo.io (the VPN exit
// while a VPN is up). Units: weather-units "f" or "c"; absent = from the
// locale.
Singleton {
    id: root

    property string temp: ""          // "" until the first fetch
    property int code: 0
    property string condition: ""
    property string feels: ""
    property string wind: ""
    property string place: ""
    property real lat: 0
    property real lon: 0
    property string humidity: ""
    property bool night: false
    property var hours: []            // the next 8: {label, glyph, temp, rain}
    property var days: []             // a week: {label, glyph, hi, lo, hiN, loN, rain}
    property bool failed: false

    property string unitsOverride: ""
    property string location: ""
    readonly property bool useF: unitsOverride === "f" ? true
                               : unitsOverride === "c" ? false
                               : Qt.locale().measurementSystem !== Locale.MetricSystem

    FileView {
        path: Theme.configDir + "/weather-units"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.unitsOverride = text().trim().toLowerCase()
        onLoadFailed: root.unitsOverride = "" // removed: back to auto
    }
    // the first answer (file or no file) starts the first fetch; after
    // that only a different location refetches
    property bool started: false
    FileView {
        path: Theme.configDir + "/weather-location"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.setLocation(text().trim())
        onLoadFailed: root.setLocation("")
    }
    function setLocation(v) {
        if (started && v === location)
            return
        location = v
        started = true
        refetch()
    }

    property var lastJson: null
    onUseFChanged: if (lastJson) parse(lastJson)

    // WMO weather codes → a handful of glyph buckets
    function glyphFor(c, dark) {
        if (dark && c <= 1) return "󰖔"
        if (dark && c === 2) return "󰼱"
        if (c >= 95) return "󰖓"                                    // thunder
        if ((c >= 71 && c <= 77) || c === 85 || c === 86
            || c === 56 || c === 57 || c === 66 || c === 67) return "󰖘" // snow, ice
        if (c >= 51) return "󰖗"                                    // drizzle, rain
        if (c === 45 || c === 48) return "󰖑"
        if (c === 3) return "󰖐"
        if (c === 2) return "󰖕"
        return "󰖙"
    }
    readonly property var conditions: ({
        0: "Despejado", 1: "Mayormente despejado", 2: "Parcialmente nublado", 3: "Nublado",
        45: "Niebla", 48: "Niebla helada",
        51: "Llovizna ligera", 53: "Llovizna", 55: "Llovizna fuerte",
        56: "Llovizna helada", 57: "Llovizna helada",
        61: "Lluvia ligera", 63: "Lluvia", 65: "Lluvia fuerte",
        66: "Lluvia helada", 67: "Lluvia helada",
        71: "Nieve ligera", 73: "Nieve", 75: "Nieve fuerte", 77: "Granos de nieve",
        80: "Chubascos ligeros", 81: "Chubascos", 82: "Chubascos fuertes",
        85: "Chubascos de nieve", 86: "Chubascos de nieve fuertes",
        95: "Tormenta eléctrica", 96: "Tormenta eléctrica con granizo", 99: "Tormenta eléctrica con granizo"
    })

    // curl one URL, hand the parsed JSON to done(); fail() on no network,
    // an HTTP error or a body that isn't JSON. A run stopped by a restart
    // reports neither: the next run answers.
    component Fetch: Process {
        id: fetch
        property string url
        property string buf: ""
        signal done(var json)
        signal fail()
        command: ["curl", "-sf", "-m", "10", url]
        stdout: SplitParser { onRead: line => fetch.buf += line }
        onRunningChanged: if (running) buf = ""
        onExited: (code, st) => {
            if (st !== 0)
                return
            let j
            try {
                if (code !== 0)
                    throw new Error("curl " + code)
                j = JSON.parse(buf)
            } catch (e) {
                fail()
                return
            }
            done(j)
        }
    }

    function failNow() {
        failed = true
        retry.start()
    }

    // where the forecast is for, kept until the location changes; auto is
    // looked up on every fetch, since a VPN can move it
    property string resolvedFor: ""

    function refetch() {
        locate.running = false
        geocode.running = false
        forecast.running = false
        const loc = location
        const ll = loc.match(/^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$/)
        if (loc === "") {
            locate.running = true
        } else if (ll) {
            setPlace(parseFloat(ll[1]), parseFloat(ll[2]), loc.trim())
        } else if (resolvedFor === loc) {
            fetchForecast()
        } else {
            geocode.url = "https://geocoding-api.open-meteo.com/v1/search?count=10&format=json&name="
                        + encodeURIComponent(loc.split(",")[0].trim())
            geocode.running = true
        }
    }

    function setPlace(la, lo, name) {
        lat = la
        lon = lo
        place = name
        resolvedFor = location
        fetchForecast()
    }

    function fetchForecast() {
        forecast.url = "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day"
            + "&hourly=temperature_2m,weather_code,precipitation_probability,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
            + "&timezone=auto&forecast_days=7"
        forecast.running = true
    }

    Fetch {
        id: locate
        url: "https://ipinfo.io/json"
        onDone: j => {
            const ll = String(j.loc ?? "").split(",")
            if (ll.length !== 2)
                return root.failNow()
            root.setPlace(parseFloat(ll[0]), parseFloat(ll[1]),
                          [j.city, j.region || j.country].filter(Boolean).join(", "))
        }
        onFail: root.failNow()
    }

    // "city, region": the first match whose state, county or country
    // starts with the region, or has it as initials ("nh"); else the
    // first match
    Fetch {
        id: geocode
        onDone: j => {
            const hits = j.results ?? []
            if (hits.length === 0)
                return root.failNow()
            const region = root.location.split(",").slice(1).join(",").trim().toLowerCase()
            const initials = s => s.split(/\s+/).map(w => w[0]).join("").toLowerCase()
            const r = (region === "" ? null : hits.find(h =>
                [h.admin1, h.admin2, h.country, h.country_code].some(x => x
                    && (x.toLowerCase().startsWith(region) || initials(x) === region))))
                ?? hits[0]
            root.setPlace(r.latitude, r.longitude,
                          [r.name, r.admin1 || r.country].filter(Boolean).join(", "))
        }
        onFail: root.failNow()
    }

    Fetch {
        id: forecast
        onDone: j => {
            try {
                root.parse(j)
                root.failed = false
            } catch (e) {
                root.failNow()
            }
        }
        onFail: root.failNow()
    }

    function parse(j) {
        const f = useF
        const t = c => String(Math.round(f ? c * 9 / 5 + 32 : c))
        const c = j.current
        const d = j.daily
        if (!c || !d)
            throw new Error("sin pronóstico")
        lastJson = j
        temp = t(c.temperature_2m)
        code = c.weather_code ?? 0
        condition = conditions[code] ?? ""
        feels = c.apparent_temperature != null ? t(c.apparent_temperature) : ""
        wind = c.wind_speed_10m == null ? ""
             : f ? Math.round(c.wind_speed_10m / 1.609344) + "mph"
                 : Math.round(c.wind_speed_10m) + "km/h"

        humidity = c.relative_humidity_2m != null ? Math.round(c.relative_humidity_2m) + "%" : ""
        night = c.is_day === 0

        // the next 8 hours, from the one we're in; times are the place's own
        const h = j.hourly ?? {}
        const hrs = []
        const ampm = Qt.locale().timeFormat(Locale.ShortFormat).toLowerCase().indexOf("a") !== -1
        const from = String(c.time ?? "").slice(0, 13)
        let i0 = (h.time ?? []).findIndex(x => x.slice(0, 13) >= from)
        if (i0 < 0) i0 = 0
        for (let i = i0; i < Math.min(i0 + 8, (h.time ?? []).length); i++) {
            const hr = parseInt(h.time[i].slice(11, 13))
            hrs.push({
                label: i === i0 ? "now"
                     : ampm ? ((hr % 12) || 12) + (hr < 12 ? "a" : "p") : String(hr).padStart(2, "0"),
                glyph: glyphFor(h.weather_code?.[i] ?? 0, h.is_day?.[i] === 0),
                temp: h.temperature_2m?.[i] != null ? t(h.temperature_2m[i]) : "?",
                rain: h.precipitation_probability?.[i] ?? 0
            })
        }
        hours = hrs

        const out = []
        const names = ["Hoy"]
        for (let i = 0; i < Math.min(7, (d.time ?? []).length); i++) {
            const hi = d.temperature_2m_max?.[i], lo = d.temperature_2m_min?.[i]
            out.push({
                label: names[i] ?? new Date(d.time[i] + "T12:00").toLocaleDateString(Qt.locale(), "ddd"),
                glyph: glyphFor(d.weather_code?.[i] ?? 0),
                hi: hi != null ? t(hi) : "?",
                lo: lo != null ? t(lo) : "?",
                hiN: hi != null ? Number(t(hi)) : 0,
                loN: lo != null ? Number(t(lo)) : 0,
                rain: d.precipitation_probability_max?.[i] ?? 0
            })
        }
        days = out
    }

    Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.refetch()
    }
    Timer {
        id: retry
        interval: 3 * 60 * 1000
        onTriggered: root.refetch()
    }
}

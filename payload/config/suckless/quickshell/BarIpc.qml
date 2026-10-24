pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// One place for the bar's `qs ipc call` names. Every screen has its own
// bar, and so its own copy of each popup, but an IPC name can be registered
// only once: with the handlers inside the popups, the first bar's copy
// answered whichever monitor you were on. Registered once here and passed
// on, the popup on the focused output answers (Popout.qml's ipcNames).
Singleton {
    id: root

    signal call(string target, string fn, string arg)

    IpcHandler { target: "layouts";    function toggle(): void { root.call("layouts", "toggle", "") }  function open(): void { root.call("layouts", "open", "") }  function close(): void { root.call("layouts", "close", "") } }
    IpcHandler { target: "tweaks";     function toggle(): void { root.call("tweaks", "toggle", "") }  function open(): void { root.call("tweaks", "open", "") }  function close(): void { root.call("tweaks", "close", "") } }
    IpcHandler { target: "volume";     function toggle(): void { root.call("volume", "toggle", "") }  function open(): void { root.call("volume", "open", "") }  function close(): void { root.call("volume", "close", "") } }
    IpcHandler { target: "commands";   function toggle(): void { root.call("commands", "toggle", "") }  function open(): void { root.call("commands", "open", "") }  function close(): void { root.call("commands", "close", "") } }
    IpcHandler { target: "displays";   function toggle(): void { root.call("displays", "toggle", "") }  function open(): void { root.call("displays", "open", "") }  function close(): void { root.call("displays", "close", "") } }
    IpcHandler { target: "metrics";    function toggle(): void { root.call("metrics", "toggle", "") }  function open(): void { root.call("metrics", "open", "") }  function close(): void { root.call("metrics", "close", "") } }
    IpcHandler {
        target: "launcher"   // mode: "" or "windows"
        function toggle(mode: string): void { root.call("launcher", "toggle", mode) }
        function open(mode: string): void { root.call("launcher", "open", mode) }
        function close(): void { root.call("launcher", "close", "") }
    }
    IpcHandler { target: "keybinds";   function toggle(): void { root.call("keybinds", "toggle", "") }  function open(): void { root.call("keybinds", "open", "") }  function close(): void { root.call("keybinds", "close", "") } }
    IpcHandler {
        target: "settings"
        function toggle(): void { root.call("settings", "toggle", "") }
        function open(tab: string): void { root.call("settings", "open", tab) }
        function close(): void { root.call("settings", "close", "") }
    }
    IpcHandler { target: "power";      function toggle(): void { root.call("power", "toggle", "") }  function open(): void { root.call("power", "open", "") }  function close(): void { root.call("power", "close", "") } }
    IpcHandler {
        target: "weather"
        function toggle(): void { root.call("weather", "toggle", "") }
        function radar(): void { root.call("weather", "radar", "") }
    }
    IpcHandler {
        target: "wallpapers"
        function toggle(): void { root.call("wallpapers", "toggle", "") }
        function random(): void { root.call("wallpapers", "random", "") }
        function set(path: string): void { root.call("wallpapers", "set", path) }
    }
    // not a popup: every bar's pill recounts
    IpcHandler { target: "updates";    function check(): void { root.call("updates", "check", "") } }
}

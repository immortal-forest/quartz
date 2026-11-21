pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// quartz — Hyprland commands that work with both config flavours: a Lua config
// (hyprland.lua, dispatch takes `hl.dsp.*` expressions) and a classic
// hyprland.conf (dispatch takes "workspace 3"-style strings).
Singleton {
    id: root
    // Asked once at startup (`hyprctl systeminfo` → "configProvider: lua");
    // Quickshell's own usingLua only fills in later, so it is a backup.
    property bool luaConfig: false
    readonly property bool lua: root.luaConfig || Hyprland.usingLua === true
    Process {
        running: true
        command: ["sh", "-c", "hyprctl systeminfo 2>/dev/null | grep -q 'configProvider: lua' && echo lua"]
        stdout: StdioCollector { onStreamFinished: if (text.trim() === "lua") root.luaConfig = true }
    }

    function q(s) { return JSON.stringify(String(s)); }

    function exec(cmd) {
        Hyprland.dispatch(root.lua ? "hl.dsp.exec_cmd(" + q(cmd) + ")" : "exec " + cmd);
    }
    function workspace(target) {
        Hyprland.dispatch(root.lua ? "hl.dsp.focus({ workspace = " + q(target) + " })" : "workspace " + target);
    }
    function exit() {
        Hyprland.dispatch(root.lua ? "hl.dsp.exit()" : "exit");
    }
}

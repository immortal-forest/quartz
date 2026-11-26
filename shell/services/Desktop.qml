pragma Singleton
import QtQuick
import Quickshell
import "../core"

// quartz — the desktop settings Hyprland and the apps read (Settings › Display & input).
// Screen scale, keyboard, touchpad and cursor size go to
// ~/.local/state/quartz/hyprland.lua, which hypr/quartz.lua loads on every
// config load (so they survive restarts), then Hyprland reloads. Text size in
// apps goes to GTK (gsettings); terminal text size to Ghostty.
Singleton {
    id: root
    readonly property string file: Config.dir + "/hyprland.lua"
    readonly property string ghostty: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ghostty/quartz-settings"
    // the screens, by the names Hyprland uses (eDP-1, HDMI-A-1 …)
    readonly property var screens: Quickshell.screens.map(s => s.name)

    // 0 = automatic (Hyprland picks from the screen's size and resolution)
    function scaleOf(name) {
        const v = (Config.opt.monitorScales || {})[name];
        return v ? Number(v) : 0;
    }
    function setScale(name, v) {
        const m = Object.assign({}, Config.opt.monitorScales || {});
        if (v > 0)
            m[name] = v;
        else
            delete m[name];
        Config.opt.monitorScales = m;
        root.hypr();
    }

    function q(s) { return JSON.stringify(String(s)); }
    function luaText() {
        const o = Config.opt;
        const m = o.monitorScales || {};
        return "-- quartz: your desktop settings, written by quartz. Change them in\n" +
            "-- Settings › Display & input; hypr/quartz.lua reads this on every load.\n" +
            "return {\n" +
            "\tmonitors = { " + Object.keys(m).map(k => "[" + q(k) + "] = " + Number(m[k])).join(", ") + " },\n" +
            "\tkb_layout = " + q(o.kbLayout) + ",\n" +
            "\tnatural_scroll = " + (o.naturalScroll ? "true" : "false") + ",\n" +
            "\ttap_to_click = " + (o.tapToClick ? "true" : "false") + ",\n" +
            "\tsensitivity = " + Number(o.pointerSpeed) + ",\n" +
            "\tcursor_size = " + Math.round(o.cursorSize) + ",\n" +
            "}\n";
    }

    // several changes in a row: one write, one reload
    function hypr() { hyprTimer.restart(); }
    Timer {
        id: hyprTimer
        interval: 400
        onTriggered: Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\" && hyprctl reload >/dev/null 2>&1", "_", root.file, root.luaText()])
    }
    // GTK apps (Files, dialogs, settings windows); they apply it at once or on next start
    function appText() {
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "text-scaling-factor", String(Config.opt.appText)]);
    }
    // quartz's Ghostty config includes this file; open terminals reload on SIGUSR2
    function termFont() {
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf 'font-size = %s\\n' \"$2\" > \"$1\" && { pkill -USR2 -x ghostty || true; }", "_", root.ghostty, String(Config.opt.termFont)]);
    }
    function applyAll() {
        root.hypr();
        root.appText();
        root.termFont();
    }
}

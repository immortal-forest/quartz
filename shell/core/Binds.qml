pragma Singleton
import QtQuick
import Quickshell

import Quickshell.Io

// quartz — the keyboard shortcuts shown in the help overlay (Super + /) and in
// Settings › Shortcuts, plus the settings the help search can jump to. One list,
// so they never disagree. A bind is [label, keys, search words]. Keys: plain
// names are drawn as text keycaps; "arrows", "arrows-h" and "icon:<glyph>" as icons.
// These are quartz's own keys (hypr/quartz.lua: binds + the essentials keymap).
// `visibleGroups` keeps only the ones Hyprland really has bound (read from
// `hyprctl binds` when the cheatsheet opens), plus any of the user's own binds
// that carry a description.
Singleton {
    id: root
    readonly property var groups: [
        { title: "quartz", icon: "space_dashboard", keys: [
            ["App launcher", ["Super", "Space"], "apps run open start program search"],
            ["Control centre", ["Super", "A"], "quick settings volume brightness toggles"],
            ["Notifications", ["Super", "N"], "alerts messages history"],
            ["Do not disturb on / off", ["Super", "Shift", "N"], "dnd quiet silence notifications popups"],
            ["Wi-Fi", ["Super", "Shift", "W"], "network internet wireless connect"],
            ["Bluetooth", ["Super", "B"], "bluetooth headphones devices pair connect"],
            ["Sound devices and apps", ["Super", "Shift", "A"], "sound audio speakers headphones output mixer volume"],
            ["Calendar", ["Super", "D"], "date month day"],
            ["Now playing", ["Super", "M"], "music media player song spotify"],
            ["Clipboard history", ["Super", "V"], "copy paste clip"],
            ["Wallpaper picker", ["Super", "C"], "background image wallpaper theme colours"],
            ["Random wallpaper", ["Super", "Shift", "C"], "background image shuffle surprise wallpaper"],
            ["Settings", ["Super", ","], "preferences options config"],
            ["This cheatsheet", ["Super", "/"], "help keys shortcuts keybinds"],
            ["Power menu", ["Super", "Esc"], "shutdown reboot restart logout log out sleep suspend power off"],
            ["Lock", ["Super", "L"], "lock screen security away"],
            ["Restart quartz", ["Super", "Shift", "R"], "reload shell bar fix"]
        ] },
        { title: "Windows", icon: "select_window", keys: [
            ["Close", ["Super", "Q"], "quit kill window"],
            ["Float / tile", ["Super", "W"], "floating tiling window"],
            ["Fullscreen", ["Alt", "Enter"], "maximise maximize window"],
            ["Group / ungroup", ["Super", "G"], "tabs tabbed window"],
            ["Focus", ["Super", "arrows"], "move focus window direction"],
            ["Resize", ["Super", "Shift", "arrows"], "size window"],
            ["Move with the mouse", ["Super", "Left drag"], "drag window"],
            ["Resize with the mouse", ["Super", "Right drag"], "size drag window"],
            ["Scratchpad", ["Super", "S"], "special hidden workspace"]
        ] },
        { title: "Workspaces", icon: "grid_view", keys: [
            ["Go to 1 – 10", ["Super", "1 – 0"], "switch workspace desktop"],
            ["Move window to 1 – 10", ["Super", "Shift", "1 – 0"], "send workspace desktop"],
            ["Send window, stay here", ["Super", "Alt", "1 – 0"], "move silently workspace"],
            ["Previous / next", ["Super", "Ctrl", "arrows-h"], "switch workspace"],
            ["First empty", ["Super", "Ctrl", "icon:keyboard_arrow_down"], "new empty workspace"],
            ["Move window prev / next", ["Super", "Ctrl", "Alt", "arrows-h"], "send workspace"],
            ["Cycle", ["Super", "icon:mouse"], "scroll workspace"]
        ] },
        { title: "Apps & screenshots", icon: "apps", keys: [
            ["Terminal", ["Super", "T"], "shell console"],
            ["Web browser", ["Super", "F"], "web internet firefox zen chrome"],
            ["Files", ["Super", "E"], "file manager folders home"],
            ["Screenshot a region", ["Super", "P"], "capture screen grab picture print"],
            ["Region, frozen screen", ["Super", "Ctrl", "P"], "capture screenshot freeze"],
            ["This monitor", ["Super", "Alt", "P"], "capture screenshot display"],
            ["All monitors", ["Print"], "capture screenshot print screen"]
        ] }
    ]

    // ── what Hyprland really has bound ────────────────────────────────────────
    property var live: null          // "modmask|key" → true; null until read (then everything shows)
    property var described: []       // the user's own binds with a description: [label, keys, ""]
    function refresh() { reader.running = true; }
    Process {
        id: reader
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const map = {}, own = [];
                    for (const b of JSON.parse(text)) {
                        if (b.submap)
                            continue;
                        map[b.modmask + "|" + String(b.key).toLowerCase()] = true;
                        const d = b.description || "";
                        if (d.length && !d.startsWith("quartz:"))
                            own.push([d, root.labels(b.modmask, b.key), d]);
                    }
                    root.live = map;
                    root.described = own;
                } catch (e) {}
            }
        }
    }
    // a cheatsheet key list → the bind Hyprland would have for it
    function combo(keys) {
        let mask = 0, key = "";
        for (const k of keys) {
            if (k === "Super") mask |= 64;
            else if (k === "Shift") mask |= 1;
            else if (k === "Ctrl") mask |= 4;
            else if (k === "Alt") mask |= 8;
            else key = ({ "Esc": "escape", ",": "comma", "/": "slash", "Enter": "return", "1 – 0": "1",
                          "arrows": "left", "arrows-h": "left", "Left drag": "mouse:272", "Right drag": "mouse:273",
                          "icon:mouse": "mouse_down", "icon:keyboard_arrow_down": "down" })[k] ?? k.toLowerCase();
        }
        return mask + "|" + key;
    }
    function bound(keys) { return !root.live || !!root.live[root.combo(keys)]; }
    // modmask + key → keycap labels (for the user's own described binds)
    function labels(mask, key) {
        const out = [];
        if (mask & 64) out.push("Super");
        if (mask & 4) out.push("Ctrl");
        if (mask & 8) out.push("Alt");
        if (mask & 1) out.push("Shift");
        const k = String(key);
        out.push(({ "comma": ",", "slash": "/", "escape": "Esc", "return": "Enter", "mouse:272": "Left drag", "mouse:273": "Right drag",
                    "mouse_down": "icon:mouse", "mouse_up": "icon:mouse", "left": "icon:keyboard_arrow_left", "right": "icon:keyboard_arrow_right",
                    "up": "icon:keyboard_arrow_up", "down": "icon:keyboard_arrow_down" })[k.toLowerCase()] ?? (k.length === 1 ? k.toUpperCase() : k));
        return out;
    }
    readonly property var visibleGroups: groups.map(g => ({ title: g.title, icon: g.icon, keys: g.keys.filter(k => root.bound(k[1])) }))
        .filter(g => g.keys.length > 0)
        .concat(described.length ? [{ title: "Other shortcuts", icon: "keyboard_command_key", keys: described }] : [])

    // settings the help search can open (section = Settings window page)
    readonly property var settings: [
        { label: "24-hour clock", section: "general", icon: "schedule", words: "time clock 24 hour am pm format" },
        { label: "Stay awake", section: "general", icon: "coffee", words: "caffeine idle sleep screen awake lock timeout" },
        { label: "Lock the screen", section: "general", icon: "lock", words: "lock screen password away" },
        { label: "Terminal for terminal apps", section: "general", icon: "terminal", words: "terminal kitty ghostty shell apps" },
        { label: "Show seconds on the clock", section: "general", icon: "timer", words: "seconds clock time bar" },
        { label: "Week starts on", section: "general", icon: "calendar_month", words: "week monday sunday calendar first day" },
        { label: "What's playing on the lock screen", section: "general", icon: "music_note", words: "lock screen music media controls" },
        { label: "Welcome guide", section: "general", icon: "waving_hand", words: "welcome help guide tour beginner start" },
        { label: "Light mode", section: "appearance", icon: "light_mode", words: "light dark mode theme night day" },
        { label: "Colour style", section: "appearance", icon: "palette", words: "colour color style scheme vibrant soft monochrome accent" },
        { label: "Accent colour", section: "appearance", icon: "colors", words: "accent colour color red blue green purple pink orange theme" },
        { label: "Corners", section: "appearance", icon: "rounded_corner", words: "corners rounded square round radius shape" },
        { label: "Motion and animations", section: "appearance", icon: "animation", words: "animation motion reduce reduced off speed accessibility" },
        { label: "Text size", section: "appearance", icon: "format_size", words: "text font size bigger larger small read accessibility" },
        { label: "Theme apps from the wallpaper", section: "appearance", icon: "format_paint", words: "colours colors theme matugen terminal borders wallpaper" },
        { label: "Workspace numbers or dots", section: "bar", icon: "looks_one", words: "workspace numbers dots bar" },
        { label: "Window title in the bar", section: "bar", icon: "web_asset", words: "window title bar app name" },
        { label: "What's playing in the bar", section: "bar", icon: "music_note", words: "music media song playing bar" },
        { label: "Date in the bar", section: "bar", icon: "calendar_today", words: "date day bar clock" },
        { label: "Battery percentage", section: "bar", icon: "battery_android_frame_5", words: "battery percent charge power bar" },
        { label: "Do not disturb", section: "notifications", icon: "do_not_disturb_on", words: "dnd notifications silence quiet pop-ups popups" },
        { label: "How long pop-ups stay", section: "notifications", icon: "timer", words: "notifications pop-up popup time duration seconds" },
        { label: "Clear all notifications", section: "notifications", icon: "clear_all", words: "notifications clear delete history" },
        { label: "Volume and microphone", section: "sound", icon: "volume_up", words: "volume sound audio speaker mic microphone mute" },
        { label: "Sound output device", section: "sound", icon: "speaker", words: "speakers headphones output device audio bluetooth hdmi" },
        { label: "Switch to headphones when they connect", section: "sound", icon: "headphones", words: "bluetooth headphones earbuds headset speaker connect switch automatic output follow" },
        { label: "Brightness", section: "sound", icon: "brightness_medium", words: "brightness screen display dim light" },
        { label: "Night light", section: "sound", icon: "nightlight", words: "night light warm blue filter eyes evening hyprsunset" },
        { label: "Power mode", section: "sound", icon: "bolt", words: "power battery saver performance balanced profile" },
        { label: "Wi-Fi and Bluetooth", section: "sound", icon: "wifi", words: "wifi wi-fi network internet bluetooth headphones connect" },
        { label: "Change or randomise the wallpaper", section: "wallpaper", icon: "image", words: "wallpaper random change background picture" },
        { label: "Change the wallpaper automatically", section: "wallpaper", icon: "autorenew", words: "wallpaper automatic rotate slideshow timer every" },
        { label: "Wallpaper folder", section: "wallpaper", icon: "folder", words: "wallpaper folder directory images background" },
        { label: "Wallpaper transition", section: "wallpaper", icon: "animation", words: "wallpaper transition animation grow wipe wave fade" },
        { label: "All keyboard shortcuts", section: "shortcuts", icon: "keyboard", words: "keys shortcuts keybinds help" },
        { label: "Reset all settings", section: "about", icon: "settings_backup_restore", words: "reset defaults restore start over" },
        { label: "Restart quartz", section: "about", icon: "restart_alt", words: "restart reload fix broken bar" },
        { label: "Where settings are saved", section: "about", icon: "folder_open", words: "config file settings location json" }
    ]

    // every word of the query must appear somewhere in the text
    function matches(text, q) {
        const t = text.toLowerCase();
        return q.toLowerCase().split(/\s+/).filter(w => w.length).every(w => t.indexOf(w) >= 0);
    }
}

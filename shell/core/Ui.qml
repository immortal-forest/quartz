pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// quartz — which surface is open, and on which screen. One panel (dropdown
// under the bar) or one overlay (launcher / power / clipboard / wallpapers)
// at a time; opening one closes the other.
Singleton {
    id: root

    property string panel: ""      // control | calendar | media | tray
    property string page: "main"   // control-center page: main | wifi | bluetooth | audio
    property string overlay: ""    // launcher | power | clipboard | wallpapers | help | welcome
    property bool settings: false  // the settings window
    property string settingsSection: "general"
    property string screen: ""     // screen name the panel / overlay lives on
    property var trayItem: null    // the tray item whose menu is open
    property real trayX: 0         // its x on the bar, for placing the menu

    // centre x of each bar item that owns a dropdown, per screen ("eDP-2:media" → x)
    property var anchors: ({})
    function setAnchor(scr, name, x) {
        const k = scr + ":" + name;
        if (Math.abs((root.anchors[k] ?? -1) - x) < 0.5)
            return;
        const a = Object.assign({}, root.anchors);
        a[k] = x;
        root.anchors = a;
    }

    function focusedScreen() {
        const m = Hyprland.focusedMonitor;
        if (m && m.name)
            return m.name;
        return Quickshell.screens.length ? Quickshell.screens[0].name : "";
    }

    function togglePanel(name, scr, pg) {
        scr = scr || focusedScreen();
        pg = pg || "main";
        if (panel === name && screen === scr && (name !== "control" || page === pg)) {
            panel = "";
            return;
        }
        overlay = "";
        screen = scr;
        page = pg;
        panel = name;
    }

    function toggleOverlay(name) {
        if (overlay === name) {
            overlay = "";
            return;
        }
        panel = "";
        screen = focusedScreen();
        overlay = name;
    }

    function openSettings(section) {
        if (section)
            settingsSection = section;
        panel = "";
        overlay = "";
        settings = true;
    }

    function showWelcome() {
        panel = "";
        settings = false;
        screen = focusedScreen();
        overlay = "welcome";
    }

    function closeAll() {
        panel = "";
        overlay = "";
        settings = false;
    }
}

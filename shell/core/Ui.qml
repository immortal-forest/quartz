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
    property string page: "main"   // control-center page: main | wifi | bluetooth | settings
    property string overlay: ""    // launcher | power | clipboard | wallpapers
    property string screen: ""     // screen name the panel / overlay lives on
    property var trayItem: null    // the tray item whose menu is open
    property real trayX: 0         // its x on the bar, for placing the menu

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

    function closeAll() {
        panel = "";
        overlay = "";
    }
}

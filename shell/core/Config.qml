pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// quartz — persisted settings (~/.local/state/quartz/config.json).
// Use as `Config.opt.<key>`; writes save automatically. A file we could not
// parse is never written back over (JsonAdapter would serialise defaults).
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.local/state/quartz"
    property bool writable: false
    property bool ready: false        // first load finished (file read, or created)
    property alias opt: adapter

    function sane(txt) {
        const t = (txt === undefined || txt === null) ? "" : String(txt).trim();
        if (t.length === 0)
            return true;
        try {
            const o = JSON.parse(t);
            return o !== null && typeof o === "object" && !Array.isArray(o);
        } catch (e) {
            return false;
        }
    }

    // Settings › About › Reset: everything back to its default (the wallpaper,
    // the welcome flag and app launch counts stay). Each key is written
    // explicitly: JsonAdapter keeps in-memory values for keys a file lacks.
    function reset() {
        const o = adapter;
        o.transition = "grow"; o.themeApps = true; o.dnd = false; o.use24h = true;
        o.workspaceNumbers = true; o.caffeine = false; o.terminal = "";
        o.light = false; o.scheme = "content"; o.textSize = 0;
        o.barTitle = true; o.barMedia = true; o.barDate = true; o.batteryPercent = true;
        o.popupTime = "normal"; o.autoWallpaper = 0; o.accent = ""; o.roundness = 1; o.motion = 2;
        o.clockSeconds = false; o.weekStart = "locale"; o.lockMedia = true;
        o.nightLight = false; o.nightTemp = 4500; o.audioFollow = true;
        o.monitorScales = ({}); o.appText = 1.0; o.termFont = 13; o.cursorSize = 24; o.kbLayout = "";
        o.naturalScroll = true; o.tapToClick = true; o.pointerSpeed = 0;
    }

    function bumpLaunch(id) {
        const l = Object.assign({}, adapter.launches || {});
        l[id] = (l[id] || 0) + 1;
        adapter.launches = l;
    }

    FileView {
        path: root.dir + "/config.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: if (root.writable) writeAdapter()
        onLoaded: {
            root.writable = root.sane(text());
            root.ready = true;
        }
        onLoadFailed: e => {
            if (e === FileViewError.FileNotFound) {
                root.writable = true;
                writeAdapter();
            }
            root.ready = true;
        }

        JsonAdapter {
            id: adapter
            property string wallpaper: ""
            property string wallpaperDir: Quickshell.env("HOME") + "/wallpapers"
            property string transition: "grow"   // awww transition: grow | wipe | fade | wave | outer
            property bool themeApps: true         // run the shared matugen templates too (terminals, borders…)
            property bool dnd: false
            property bool use24h: true
            property bool workspaceNumbers: true    // numbered workspace pills (off = dots)
            property bool caffeine: false
            property string terminal: ""          // for Terminal=true apps; empty = $TERMINAL, else kitty
            property var launches: ({})
            property bool welcomed: false         // the first-run welcome has been shown
            // appearance
            property bool light: false            // light mode (matugen -m light)
            property string scheme: "content"     // matugen scheme: content | tonal-spot | vibrant | expressive | fidelity | monochrome
            property int textSize: 0              // 0 default, 1 large, 2 larger
            // bar
            property bool barTitle: true          // the focused window's title
            property bool barMedia: true          // what's playing
            property bool barDate: true           // the date beside the time
            property bool batteryPercent: true
            // notifications
            property string popupTime: "normal"   // short 4 s | normal 6 s | long 10 s
            // wallpaper
            property int autoWallpaper: 0         // minutes between automatic changes, 0 = off
            // more appearance
            property string accent: ""            // "" = from the wallpaper, else a seed colour "#rrggbb"
            property int roundness: 1             // 0 square, 1 rounded, 2 round
            property int motion: 2                // 0 off, 1 reduced, 2 full
            // clock & calendar
            property bool clockSeconds: false
            property string weekStart: "locale"   // locale | monday | sunday
            // lock screen
            property bool lockMedia: true         // what's playing on the lock screen
            // display
            property bool nightLight: false       // hyprsunset
            property int nightTemp: 4500          // kelvin
            // sound
            property bool audioFollow: true       // Bluetooth outputs take over the sound when they connect
            // display & input (services/Desktop.qml writes them where Hyprland and the apps read them)
            property var monitorScales: ({})      // { "eDP-1": 1.5 }; a screen that isn't here scales automatically
            property real appText: 1.0            // GTK apps' text-scaling-factor
            property int termFont: 13             // Ghostty's font-size (quartz's Ghostty config)
            property int cursorSize: 24
            property string kbLayout: ""          // "" = the config's own (us); "us,ru" = two, Alt + Shift switches
            property bool naturalScroll: true     // touchpad
            property bool tapToClick: true        // touchpad
            property real pointerSpeed: 0         // -1 … 1
        }
    }
}

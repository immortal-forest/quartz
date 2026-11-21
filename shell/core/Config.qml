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
            property bool workspaceNumbers: false
            property bool japanese: false         // optional: kanji weekday in the bar, JP date on the lock screen
            property bool caffeine: false
            property string terminal: ""          // for Terminal=true apps; empty = $TERMINAL, else kitty
            property var launches: ({})
        }
    }
}

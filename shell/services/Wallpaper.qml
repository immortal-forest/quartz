pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

// quartz — wallpaper (awww) + colours (matugen).
// set(): awww draws the new image with a transition growing from where you
// clicked, matugen derives the M3 palette quartz uses (palette.json), and —
// with Config.opt.themeApps — the shared matugen templates retheme the
// terminals, Hyprland borders, cava, … the same way setwall does.
Singleton {
    id: root

    readonly property string current: Config.opt.wallpaper
    readonly property string palettePath: Theme.cacheDir + "/palette.json"
    property bool available: false    // awww installed
    property bool setwall: false      // no awww, but a `setwall` script sets it instead
    readonly property bool canSet: available || setwall
    property var files: []            // absolute paths, sorted
    property var folders: []          // top-level folders under wallpaperDir
    property bool scanned: false

    // Picker thumbnails: ~/.cache/quartz/thumbs/<md5(path|mtime)>.jpg, 480 px
    // JPEGs. After a scan, ONE `ls` of the cache is diffed against the scan
    // here: only missing thumbnails are made (low priority, in parallel) and
    // ones whose wallpaper is gone or changed are deleted. The grid shows the
    // full image until its thumbnail exists.
    readonly property string thumbDir: Theme.cacheDir + "/thumbs"
    property int thumbGen: 0
    property var thumbKeys: ({})      // path → cache key
    function thumb(path) { return "file://" + root.thumbDir + "/" + (root.thumbKeys[path] || Qt.md5(path)) + ".jpg"; }

    readonly property var keys: ["primary", "on_primary", "primary_container", "on_primary_container",
        "secondary", "secondary_container", "on_secondary_container", "tertiary", "tertiary_container",
        "on_tertiary_container", "error", "error_container", "on_error_container", "surface",
        "surface_container_lowest", "surface_container_low", "surface_container", "surface_container_high",
        "surface_container_highest", "on_surface", "on_surface_variant", "outline", "outline_variant"]

    function folderOf(path) {
        const base = Config.opt.wallpaperDir.replace(/\/$/, "") + "/";
        if (!path.startsWith(base))
            return "";
        const rest = path.substring(base.length);
        const i = rest.indexOf("/");
        return i > 0 ? rest.substring(0, i) : "";
    }

    function scan() {
        if (!scanner.running)
            scanner.running = true;
    }

    // px, py: transition origin as 0..1 of the screen, from the top-left.
    function set(path, px, py) {
        if (!path)
            return;
        Config.opt.wallpaper = path;
        const pos = (px === undefined) ? "center" : (Math.max(0, Math.min(1, px)).toFixed(3) + "," + Math.max(0, Math.min(1, 1 - py)).toFixed(3));
        if (root.available) {
            Quickshell.execDetached(["awww", "img", path,
                "--transition-type", Config.opt.transition || "grow",
                "--transition-pos", pos,
                "--transition-duration", "1.3",
                "--transition-fps", "120",
                "--transition-bezier", ".45,0,.2,1"]);
            retheme(path, Config.opt.themeApps);
        } else {
            // no awww: the wallpaper on screen is skwd's — hand it to setwall (which
            // also themes the apps), so the shell's colours always match what you see
            Quickshell.execDetached(["sh", "-c", "command -v setwall >/dev/null && setwall \"$1\" >/dev/null 2>&1", "_", path]);
            retheme(path, false);
        }
    }
    // Settings › Appearance: light / dark and the colour style re-derive the palette
    readonly property bool light: Config.opt.light
    readonly property string mode: light ? "light" : "dark"
    readonly property string scheme: Config.opt.scheme || "content"
    onModeChanged: {
        if (root.booted && root.current.length)
            retheme(root.current, root.available && Config.opt.themeApps);
        root.gtkScheme();
    }
    // GTK / libadwaita apps (and Chrome, portals) follow quartz's light / dark
    function gtkScheme() {
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", root.light ? "prefer-light" : "prefer-dark"]);
    }
    onSchemeChanged: if (root.booted && root.current.length) retheme(root.current, root.available && Config.opt.themeApps)
    readonly property string accent: Config.opt.accent || ""
    onAccentChanged: if (root.booted && root.current.length) retheme(root.current, root.available && Config.opt.themeApps)

    // Settings › Wallpaper: change automatically every N minutes (runs only when on)
    Timer {
        interval: Math.max(1, Config.opt.autoWallpaper) * 60000
        running: Config.opt.autoWallpaper > 0
        repeat: true
        onTriggered: root.random()
    }

    function random() {
        if (!root.scanned) {
            root.pendingRandom = true;
            scan();
            return;
        }
        const pool = root.files.filter(f => f !== root.current);
        if (pool.length)
            set(pool[Math.floor(Math.random() * pool.length)]);
    }
    property bool pendingRandom: false

    function retheme(path, apps) {
        // a chosen accent colour seeds the palette instead of the wallpaper
        const src = root.accent.length ? ["color", "hex", root.accent] : ["image", path];
        const args = ["matugen"].concat(src, ["--dry-run", "-j", "hex", "-m", root.mode, "-t", "scheme-" + root.scheme]).concat(root.accent.length ? [] : ["--prefer", root.light ? "lightness" : "darkness"]);
        // Palette cache (~/.cache/quartz/palettes): keyed by the wallpaper, its
        // mtime, mode, style and accent, so going back to a wallpaper (or
        // flipping light / dark) is instant instead of a fresh image analysis.
        // Newest 200 kept (a few KB each).
        themer.command = ["sh", "-c",
            "d=\"${1:?}\"; mkdir -p \"$d\"; " +
            "k=$(printf '%s|%s|%s' \"$2\" \"$(stat -c %Y \"$2\" 2>/dev/null)\" \"$3\" | md5sum | cut -c1-32); f=\"$d/$k.json\"; " +
            "if [ -s \"$f\" ]; then touch \"$f\"; cat \"$f\"; else shift 3; \"$@\" > \"$f.tmp\" && mv \"$f.tmp\" \"$f\" && cat \"$f\"; " +
            "ls -1t \"$d\" | tail -n +201 | while read -r o; do rm -f -- \"$d/$o\"; done; fi",
            "_", Theme.cacheDir + "/palettes", path, [root.mode, root.scheme, root.accent].join("|")].concat(args);
        themer.running = false;
        themer.running = true;
        if (apps)
            // --prefer like the palette above: with several strong colours and no
            // terminal to ask, matugen otherwise gives up and themes nothing
            Quickshell.execDetached(["sh", "-c", "if [ -n \"$4\" ]; then matugen -m \"$2\" -t \"scheme-$3\" color hex \"$4\"; else matugen -m \"$2\" -t \"scheme-$3\" --prefer \"$5\" image \"$1\"; fi >/dev/null 2>&1 </dev/null", "_", path, root.mode, root.scheme, root.accent, root.light ? "lightness" : "darkness"]);
    }

    Process {
        id: themer
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const c = JSON.parse(text).colors;
                    const out = {};
                    // the scheme for the chosen mode (light / dark)
                    for (const k of root.keys)
                        if (c[k])
                            out[k] = (c[k][root.mode] || c[k]["default"] || c[k].dark).color;
                    Theme.pal = out;
                    paletteFile.setText(JSON.stringify(out, null, 1));
                } catch (e) {
                    console.warn("quartz: matugen output unreadable:", e);
                }
            }
        }
    }
    FileView {
        id: paletteFile
        path: root.palettePath
        printErrors: false
    }

    Process {
        id: scanner
        command: ["sh", "-c", "find -L \"$1\" -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' \\) -printf '%T@\\t%p\\n' 2>/dev/null | sort -t \"$(printf '\\t')\" -k2", "_", Config.opt.wallpaperDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [], keys = {};
                for (const line of text.split("\n")) {
                    const t = line.indexOf("\t");
                    if (t <= 0)
                        continue;
                    const f = line.substring(t + 1);
                    list.push(f);
                    keys[f] = Qt.md5(f + "|" + line.substring(0, t));
                }
                root.thumbKeys = keys;
                const fs = {};
                for (const f of list) {
                    const d = root.folderOf(f);
                    if (d.length)
                        fs[d] = true;
                }
                root.files = list;
                root.folders = Object.keys(fs).sort();
                root.scanned = true;
                if (!cacheList.running)
                    cacheList.running = true;
                if (root.pendingRandom) {
                    root.pendingRandom = false;
                    root.random();
                }
            }
        }
    }

    // what the cache holds now → make the missing, drop the stale
    Process {
        id: cacheList
        command: ["sh", "-c", "mkdir -p \"$1\" && ls -1 \"$1\"", "_", root.thumbDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const have = {};
                for (const f of text.split("\n"))
                    if (f.length)
                        have[f] = true;
                const want = {}, make = [], moves = [];
                for (const path in root.thumbKeys) {
                    const k = root.thumbKeys[path] + ".jpg";
                    want[k] = true;
                    if (have[k])
                        continue;
                    // a thumbnail from before mtimes were in the key: rename, don't redo
                    const old = Qt.md5(path) + ".jpg";
                    if (have[old]) {
                        moves.push(old, k);
                        have[old] = false;
                    } else {
                        make.push(root.thumbKeys[path], path);
                    }
                }
                if (moves.length)
                    Quickshell.execDetached(["sh", "-c", "d=\"${1:?}\"; shift; while [ $# -ge 2 ]; do mv -f -- \"$d/$1\" \"$d/$2\"; shift 2; done", "_", root.thumbDir].concat(moves));
                const stale = Object.keys(have).filter(f => have[f] && !want[f]).map(f => root.thumbDir + "/" + f);
                if (stale.length)
                    Quickshell.execDetached(["rm", "-f", "--"].concat(stale));
                if (make.length) {
                    thumbnailer.command = ["sh", "-c",
                        "d=\"$1\"; shift; export d; printf '%s\\0' \"$@\" | xargs -0 -r -n 2 -P \"$(( $(nproc) / 2 + 1 ))\" sh -c " +
                        "'nice -n 19 ffmpeg -loglevel quiet -nostdin -y -i \"$2\" -vf scale=480:-2 -frames:v 1 -q:v 5 \"$d/$1.jpg\"' _",
                        "_", root.thumbDir].concat(make);
                    thumbnailer.running = true;
                }
            }
        }
    }
    Process {
        id: thumbnailer
        onExited: root.thumbGen++
    }

    // Startup: make sure awww-daemon runs and shows our wallpaper, and that a
    // palette exists. First run adopts whatever awww already shows.
    property bool booted: false
    function bootOnce() {
        if (Config.ready && !root.booted) {
            root.booted = true;
            root.gtkScheme();
            boot.running = true;
        }
    }
    Component.onCompleted: bootOnce()
    Connections {
        target: Config
        function onReadyChanged() { root.bootOnce(); }
    }
    Process {
        id: boot
        command: ["sh", "-c",
            "mkdir -p \"$HOME/.cache/quartz\"; " +
            "w=\"$1\"; [ -z \"$w\" ] && command -v awww >/dev/null && w=$(awww query 2>/dev/null | sed -n 's/.*image: //p' | head -n1); " +
            "[ -n \"$w\" ] && [ -f \"$w\" ] || w=''; " +
            // a fresh setup: nothing saved, nothing on screen. Start on the folder's first picture
            "[ -z \"$w\" ] && w=$(find -L \"$2\" -maxdepth 3 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \\) 2>/dev/null | sort | head -n1); " +
            "if command -v awww >/dev/null; then echo AWWW; " +
            "pgrep -x awww-daemon >/dev/null || { setsid -f awww-daemon >/dev/null 2>>\"$HOME/.cache/quartz/awww.log\"; i=0; until awww query >/dev/null 2>&1 || [ $i -ge 30 ]; do sleep 0.1; i=$((i+1)); done; }; " +
            "[ -n \"$w\" ] && { awww query 2>/dev/null | grep -qF \"$w\" || awww img \"$w\" --transition-type fade --transition-duration 0.8 >/dev/null 2>>\"$HOME/.cache/quartz/awww.log\"; }; " +
            "else echo NOAWWW; command -v setwall >/dev/null && echo SETWALL; fi; " +
            "[ -n \"$w\" ] && echo \"WALL $w\"; " +
            "[ -n \"$w\" ] && { ! [ -s \"$HOME/.cache/quartz/palette.json\" ] || [ \"$w\" != \"$1\" ]; } && echo RETHEME; true",
            "_", Config.opt.wallpaper, Config.opt.wallpaperDir]
        stdout: SplitParser {
            onRead: line => {
                if (line === "AWWW") {
                    root.available = true;
                } else if (line === "NOAWWW") {
                    root.available = false;
                    warnLater.start();
                } else if (line === "SETWALL") {
                    root.setwall = true;
                } else if (line.startsWith("WALL ")) {
                    const w = line.substring(5);
                    if (Config.opt.wallpaper !== w)
                        Config.opt.wallpaper = w;
                } else if (line === "RETHEME") {
                    root.retheme(Config.opt.wallpaper, root.available && Config.opt.themeApps);
                }
            }
        }
    }
    Timer {
        id: warnLater
        interval: 100
        onTriggered: if (!root.canSet) console.warn("quartz: awww is not installed — wallpapers can't be changed (sudo pacman -S awww)")
    }
}

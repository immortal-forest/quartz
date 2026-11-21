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
    property var files: []            // absolute paths, sorted
    property var folders: []          // top-level folders under wallpaperDir
    property bool scanned: false

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
        if (root.available)
            Quickshell.execDetached(["awww", "img", path,
                "--transition-type", Config.opt.transition || "grow",
                "--transition-pos", pos,
                "--transition-duration", "1.3",
                "--transition-fps", "120",
                "--transition-bezier", ".45,0,.2,1"]);
        retheme(path);
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

    function retheme(path) {
        themer.command = ["matugen", "image", path, "--dry-run", "-j", "hex", "-m", "dark", "-t", "scheme-content", "--prefer", "darkness"];
        themer.running = false;
        themer.running = true;
        if (Config.opt.themeApps)
            Quickshell.execDetached(["sh", "-c", "matugen -m dark -t scheme-content image \"$1\" >/dev/null 2>&1", "_", path]);
    }

    Process {
        id: themer
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const c = JSON.parse(text).colors;
                    const out = {};
                    for (const k of root.keys)
                        if (c[k])
                            out[k] = c[k].dark.color;
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
        command: ["sh", "-c", "find -L \"$1\" -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' \\) 2>/dev/null | sort", "_", Config.opt.wallpaperDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = text.split("\n").filter(l => l.length);
                const fs = {};
                for (const f of list) {
                    const d = root.folderOf(f);
                    if (d.length)
                        fs[d] = true;
                }
                root.files = list;
                root.folders = Object.keys(fs).sort();
                root.scanned = true;
                if (root.pendingRandom) {
                    root.pendingRandom = false;
                    root.random();
                }
            }
        }
    }

    // Startup: make sure awww-daemon runs and shows our wallpaper, and that a
    // palette exists. First run adopts whatever awww (or astralis) already shows.
    property bool booted: false
    function bootOnce() {
        if (Config.ready && !root.booted) {
            root.booted = true;
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
            "[ -z \"$w\" ] && w=$(cat \"$HOME/.cache/astralis/current-wallpaper\" 2>/dev/null); " +
            "[ -n \"$w\" ] && [ -f \"$w\" ] || w=''; " +
            "if command -v awww >/dev/null; then echo AWWW; " +
            "pgrep -x awww-daemon >/dev/null || { setsid -f awww-daemon >/dev/null 2>&1; i=0; until awww query >/dev/null 2>&1 || [ $i -ge 30 ]; do sleep 0.1; i=$((i+1)); done; }; " +
            "[ -n \"$w\" ] && { awww query 2>/dev/null | grep -qF \"$w\" || awww img \"$w\" --transition-type fade --transition-duration 0.8 >/dev/null 2>&1; }; " +
            "else echo NOAWWW; fi; " +
            "[ -n \"$w\" ] && echo \"WALL $w\"; " +
            "[ -n \"$w\" ] && ! [ -s \"$HOME/.cache/quartz/palette.json\" ] && echo RETHEME; true",
            "_", Config.opt.wallpaper]
        stdout: SplitParser {
            onRead: line => {
                if (line === "AWWW") {
                    root.available = true;
                } else if (line === "NOAWWW") {
                    root.available = false;
                    console.warn("quartz: awww is not installed — wallpapers can't be changed (sudo pacman -S awww)");
                } else if (line.startsWith("WALL ")) {
                    const w = line.substring(5);
                    if (Config.opt.wallpaper !== w)
                        Config.opt.wallpaper = w;
                } else if (line === "RETHEME") {
                    root.retheme(Config.opt.wallpaper);
                }
            }
        }
    }
}

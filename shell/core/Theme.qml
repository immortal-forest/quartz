pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// quartz — look: palette (matugen M3 roles from the wallpaper), type, shape.
// The palette lives in ~/.cache/quartz/palette.json, written by services/Wallpaper.
// Every role animates, so a new wallpaper sweeps the whole shell to its colours.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string cacheDir: home + "/.cache/quartz"

    // matugen palette (keys = matugen role names). A Behavior on a Singleton's
    // own property crashes this Qt build, so a retheme is one 0→1 sweep `t`
    // blending every role from what was on screen to the new palette.
    property var pal: ({})
    readonly property var fallback: ({
        "primary": "#a8c8ff",
        "on_primary": "#06305f",
        "primary_container": "#244777",
        "on_primary_container": "#d5e3ff",
        "secondary": "#bdc7dc",
        "secondary_container": "#3e4759",
        "on_secondary_container": "#d9e3f8",
        "tertiary": "#dbbce1",
        "tertiary_container": "#563e5c",
        "on_tertiary_container": "#f8d8fd",
        "error": "#ffb4ab",
        "error_container": "#93000a",
        "on_error_container": "#ffdad6",
        "surface": "#111318",
        "surface_container_lowest": "#0c0e13",
        "surface_container_low": "#191c20",
        "surface_container": "#1d2024",
        "surface_container_high": "#282a2f",
        "surface_container_highest": "#33353a",
        "on_surface": "#e2e2e9",
        "on_surface_variant": "#c4c6d0",
        "outline": "#8e9099",
        "outline_variant": "#44474e"
    })
    property var from: ({})
    property var to: ({})
    property real t: 1

    function target(k) {
        const v = root.pal[k];
        return Qt.color((typeof v === "string" && v.length) ? v : root.fallback[k]);
    }
    function c(k) {
        const b = root.to[k] ?? target(k);
        const a = root.from[k];
        return (a === undefined || root.t >= 1) ? b : mix(a, b, root.t);
    }
    onPalChanged: {
        const snap = {}, next = {};
        for (const k in root.fallback) {
            snap[k] = c(k);
            next[k] = target(k);
        }
        root.from = snap;
        root.to = next;
        root.t = 0;
        sweep.restart();
    }
    NumberAnimation {
        id: sweep
        target: root
        property: "t"
        from: 0
        to: 1
        duration: 800
        easing.type: Easing.InOutCubic
    }

    readonly property color primary: c("primary")
    readonly property color primaryText: c("on_primary")
    readonly property color primaryContainer: c("primary_container")
    readonly property color primaryContainerText: c("on_primary_container")
    readonly property color secondary: c("secondary")
    readonly property color secondaryContainer: c("secondary_container")
    readonly property color secondaryContainerText: c("on_secondary_container")
    readonly property color tertiary: c("tertiary")
    readonly property color tertiaryContainer: c("tertiary_container")
    readonly property color tertiaryContainerText: c("on_tertiary_container")
    readonly property color error: c("error")
    readonly property color errorContainer: c("error_container")
    readonly property color errorContainerText: c("on_error_container")
    readonly property color surface: c("surface")
    readonly property color surfaceLowest: c("surface_container_lowest")
    readonly property color surfaceLow: c("surface_container_low")
    readonly property color surfaceMid: c("surface_container")
    readonly property color surfaceHigh: c("surface_container_high")
    readonly property color surfaceHighest: c("surface_container_highest")
    readonly property color text: c("on_surface")
    readonly property color textDim: c("on_surface_variant")
    readonly property color outline: c("outline")
    readonly property color outlineVariant: c("outline_variant")
    readonly property color shadow: "#000000"

    // Surfaces are solid: the bar and the dropdowns hanging from it must be the
    // exact same colour wherever they sit (translucent glass picks up whatever is
    // behind each layer and shows a seam), and nothing needs blurring behind them.
    readonly property color glass: surfaceLow
    readonly property color glassStrong: surfaceLow
    readonly property color card: alpha(surfaceHigh, 0.72)      // content cards + idle tiles
    readonly property color tonal: alpha(text, 0.08)           // idle small controls: buttons, chips, tracks, fields
    readonly property color hairline: alpha(text, 0.08)

    function alpha(c, a) {
        const k = typeof c === "string" ? Qt.color(c) : c;   // accepts "white" as well as a color
        return Qt.rgba(k.r, k.g, k.b, a);
    }
    function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t); }

    // ── type ── one family everywhere (Outfit: geometric, pairs with the rounded
    // icons); hierarchy comes from size + weight, never from a second face
    readonly property string font: "Outfit"
    readonly property string display: "Outfit"
    readonly property string icons: "Material Symbols Rounded"
    // text size (Settings › Appearance) shifts the whole scale
    readonly property int bump: Math.max(0, Math.min(2, Config.opt.textSize))
    readonly property int fsSmall: 13 + bump   // subtitles, captions, section labels
    readonly property int fsBody: 15 + bump    // everything else
    readonly property int fsTitle: 17 + bump   // the clock, search fields, list-row emphasis
    readonly property int fsLarge: 24 + bump   // panel / page headings

    // ── size ── every surface is built from these, nothing in between
    readonly property int barHeight: 44
    readonly property int barItem: 32     // chips inside the bar
    readonly property int gap: 8          // = Hyprland gaps_out: bar ↔ screen edge, bar ↔ panels
    readonly property int pad: 16         // inner padding of panels (control centre, calendar, media, wallpapers)
    readonly property int padCard: 12     // inner padding of cards, and of list overlays (launcher, clipboard)
    readonly property int spacing: 8      // between siblings in a group
    readonly property int ctl: 40         // pill controls: buttons, sliders, fields, segmented chips
    readonly property int ctlSmall: 32    // small pill controls: inline icon buttons, filter chips, card actions
    readonly property int row: 56         // list rows (Wi-Fi, Bluetooth, sound, launcher, settings)
    readonly property int tile: 64        // quick-settings tiles
    readonly property int icon: 20        // icons in rows, tiles and buttons
    readonly property int iconBar: 18     // icons in the bar

    // ── shape ── controls are fully round (height / 2); containers use these
    // Settings › Appearance › Corners scales every container radius
    readonly property real round: [0.35, 1, 1.5][Math.max(0, Math.min(2, Config.opt.roundness))]
    readonly property int rSurface: Math.round(24 * round)   // panels, overlays, toasts, OSD
    readonly property int rCard: Math.round(16 * round)      // cards inside a surface, row highlights
    readonly property int rThumb: Math.round(12 * round)     // cover art, thumbnails, app tiles
    readonly property int rBar: Math.round(16 * round)       // the bar: curved corners, not a pill
    // pill-shaped controls (buttons, chips, sliders, fields): fully round, but
    // with square corners chosen they become rounded rectangles too
    function pill(h) { return Config.opt.roundness === 0 ? Math.min(h / 2, 6) : h / 2; }
    readonly property int rBarItem: rBar - (barHeight - barItem) / 2   // chips in the bar, concentric with it

    FileView {
        path: root.cacheDir + "/palette.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const o = JSON.parse(text());
                if (o && typeof o === "object")
                    root.pal = o;
            } catch (e) {}
        }
    }
}

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

    // Glass: translucent surfaces over Hyprland blur (layer rules in windows.lua).
    readonly property color glass: alpha(surfaceLow, 0.80)
    readonly property color glassStrong: alpha(surfaceLow, 0.90)
    readonly property color card: alpha(surfaceHigh, 0.70)
    readonly property color cardHover: alpha(surfaceHighest, 0.85)
    readonly property color hairline: alpha(text, 0.08)

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t); }

    // ── type ──
    readonly property string font: "Adwaita Sans"
    readonly property string display: "Outfit"
    readonly property string icons: "Material Symbols Rounded"
    readonly property int fsSmall: 11
    readonly property int fsBody: 13
    readonly property int fsTitle: 15
    readonly property int fsLarge: 20

    // ── shape ──
    readonly property int barHeight: 38
    readonly property int gap: 8          // = Hyprland gaps_out: bar ↔ screen edge
    readonly property int rSmall: 10
    readonly property int rMid: 16
    readonly property int rLarge: 22
    readonly property int rXL: 28

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

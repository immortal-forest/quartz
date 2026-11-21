pragma Singleton
import QtQuick
import Quickshell

// quartz — how wide a Material Symbols glyph's INK is at a size (the icons
// sit in a 24-grid box with blank sides that differ per glyph, so spacing
// measured to the box looks uneven). Measured once per glyph at a large
// reference size with a read-only call (no property writes, so it is safe
// inside bindings) and scaled; cached.
Singleton {
    id: root
    readonly property real ref: 240
    property var cache: ({})
    FontMetrics {
        id: fm
        font.family: "Material Symbols Rounded"
        font.pixelSize: root.ref
    }
    function ink(name, size) {
        let w = root.cache[name];
        if (w === undefined) {
            w = fm.tightBoundingRect(name).width / root.ref;
            root.cache[name] = w;
        }
        return Math.ceil(w * size) || size;
    }
}

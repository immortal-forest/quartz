import QtQuick
import QtQuick.Layouts
import "../core"

// Material Symbols Rounded glyph, outline (fill 0) or filled (fill 1).
// Only TWO font variants are ever used: every distinct variable-axis value
// makes Qt load another copy of the 15 MB font (it was mapped 91× and made
// panels stutter on open), so fill snaps instead of animating and the other
// axes stay at the font's defaults.
Text {
    id: root
    property string icon: ""
    property real size: Theme.icon
    property real fill: 0
    // tight: as wide as the glyph's ink, not its 24-grid box, so padding and
    // gaps around it are what the eye sees (bar status icons, button icons…)
    property bool tight: false
    width: tight ? Glyphs.ink(icon, size) : implicitWidth
    Layout.preferredWidth: tight ? Glyphs.ink(icon, size) : -1
    text: icon
    color: Theme.text
    font.family: Theme.icons
    font.pixelSize: size
    font.variableAxes: ({ "FILL": root.fill >= 0.5 ? 1 : 0 })
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    Behavior on color { CAnim {} }
}

import QtQuick
import "../core"

// The concave curve where a panel meets the bar's bottom edge, so the two read
// as one surface. Fills the r×r square beside the panel's top corner except a
// quarter circle: a thick ring centred on the square's far bottom corner,
// clipped to the square (one antialiased edge, no overlapping alpha).
// `flip: true` = the square is to the panel's right.
Item {
    id: root
    property real r: Theme.rBar
    property color color: Theme.glassStrong
    property bool flip: false
    width: r
    height: r
    clip: true

    Rectangle {
        readonly property real b: root.r * 0.5          // ring thick enough to cover the square's corner
        readonly property real outer: root.r + b
        x: (root.flip ? root.r : 0) - outer
        y: root.r - outer
        width: outer * 2
        height: outer * 2
        radius: outer
        color: "transparent"
        border.width: b
        border.color: root.color
        antialiasing: true
    }
}

import QtQuick
import QtQuick.Effects
import "../core"

// Panel material: frosted glass (Hyprland blurs behind), a hairline edge and a
// soft shadow (SDF, cheap). Content goes inside. `radiusTop` lets a panel that
// hangs from the bar keep square top corners.
Item {
    id: root
    property real radius: Theme.rSurface
    property real radiusTop: radius
    property color color: Theme.glassStrong
    property bool shadow: true
    property bool edge: true
    default property alias content: body.data

    RectangularShadow {
        visible: root.shadow
        anchors.fill: bg
        radius: root.radius
        blur: 28
        spread: -2
        offset.y: 8
        color: Theme.alpha(Theme.shadow, 0.40)
    }
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root.radius
        topLeftRadius: root.radiusTop
        topRightRadius: root.radiusTop
        color: root.color
        border.width: root.edge ? 1 : 0
        border.color: Theme.hairline
    }
    Item {
        id: body
        anchors.fill: parent
    }
}

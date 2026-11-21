import QtQuick
import Quickshell
import Quickshell.Wayland

// One lock surface per screen.
WlSessionLockSurface {
    id: surf
    required property var ctx
    color: "black"
    LockScene {
        anchors.fill: parent
        ctx: surf.ctx
    }
}

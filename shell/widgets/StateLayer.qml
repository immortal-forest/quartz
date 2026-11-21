import QtQuick
import "../core"

// Hover / press feedback + input for whatever it fills. Put it as the LAST
// child of a rounded item; it tints over the item and catches its clicks.
MouseArea {
    id: root
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    property real radius: parent.radius ?? 0
    property color tint: Theme.text
    property real hoverOpacity: 0.08

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.tint
        opacity: !root.enabled ? 0 : root.pressed ? 0.14 : root.containsMouse ? root.hoverOpacity : 0
        Behavior on opacity { Ease { duration: Anim.fast } }
    }
}

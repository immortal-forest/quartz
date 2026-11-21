import QtQuick
import "../core"

// M3 switch.
Rectangle {
    id: root
    property bool checked: false
    signal toggled

    implicitWidth: 52
    implicitHeight: 32
    radius: Theme.pill(height)
    color: checked ? Theme.primary : Theme.tonal
    border.width: checked ? 0 : 2
    border.color: Theme.outline
    Behavior on color { CAnim {} }

    Rectangle {
        id: thumb
        property real d: ma.pressed ? 28 : root.checked ? 24 : 16
        width: d
        height: d
        radius: d / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - 4 - d : 8 - (d - 16) / 2
        color: root.checked ? Theme.primaryText : Theme.outline
        Behavior on x { Spring { baseSpring: 4; baseDamping: 0.42 } }
        Behavior on d { Spring { baseSpring: 4; baseDamping: 0.42 } }
        Behavior on color { CAnim {} }
    }
    StateLayer {
        id: ma
        onClicked: root.toggled()
    }
}

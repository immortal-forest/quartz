import QtQuick
import "../core"

// M3 switch.
Rectangle {
    id: root
    property bool checked: false
    signal toggled

    implicitWidth: 46
    implicitHeight: 26
    radius: height / 2
    color: checked ? Theme.primary : Theme.alpha(Theme.text, 0.08)
    border.width: checked ? 0 : 2
    border.color: Theme.outline
    Behavior on color { CAnim {} }

    Rectangle {
        id: thumb
        property real d: ma.pressed ? 22 : root.checked ? 18 : 12
        width: d
        height: d
        radius: d / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - 4 - d : 7 - (d - 12) / 2
        color: root.checked ? Theme.primaryText : Theme.outline
        Behavior on x { Spring { spring: 4; damping: 0.42 } }
        Behavior on d { Spring { spring: 4; damping: 0.42 } }
        Behavior on color { CAnim {} }
    }
    StateLayer {
        id: ma
        onClicked: root.toggled()
    }
}

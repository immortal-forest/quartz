import QtQuick
import "../core"

// Round icon button. `active` gives it a filled primary-container look.
Rectangle {
    id: root
    property string icon: ""
    property real size: 34
    property real iconSize: 18
    property bool active: false
    property color base: "transparent"
    property color fg: active ? Theme.primaryContainerText : Theme.text
    signal clicked(var mouse)

    implicitWidth: size
    implicitHeight: size
    radius: size / 2
    color: active ? Theme.primaryContainer : base
    Behavior on color { CAnim {} }

    scale: ma.pressed ? 0.92 : 1
    Behavior on scale { Spring { epsilon: 0.004; spring: 4.5; damping: 0.4 } }

    Icon {
        anchors.centerIn: parent
        icon: root.icon
        size: root.iconSize
        fill: root.active ? 1 : 0
        color: root.fg
    }
    StateLayer {
        id: ma
        tint: root.fg
        onClicked: m => root.clicked(m)
    }
}

import QtQuick
import "../core"

// Round icon button. Tonal (soft fill) by default so it reads as a button;
// `active` gives it the filled primary-container look, `tonal: false` makes it
// a bare glyph.
Rectangle {
    id: root
    property string icon: ""
    property real size: Theme.ctl
    property real iconSize: size >= Theme.ctl ? Theme.icon : 18
    property bool active: false
    property bool tonal: true
    property color base: tonal ? Theme.tonal : "transparent"
    property color fg: active ? Theme.primaryText : Theme.text
    signal clicked(var mouse)

    implicitWidth: size
    implicitHeight: size
    radius: Theme.pill(size)
    color: active ? Theme.primary : base
    Behavior on color { CAnim {} }

    scale: ma.pressed ? 0.92 : 1
    Behavior on scale { Spring { epsilon: 0.004; baseSpring: 4.5; baseDamping: 0.4 } }

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

import QtQuick
import "../core"

// Selectable pill: filter chips, segmented choices, player switcher.
Rectangle {
    id: root
    property string text: ""
    property bool selected: false
    property bool small: false
    signal clicked

    implicitHeight: small ? Theme.ctlSmall : Theme.ctl
    implicitWidth: lbl.implicitWidth + 32
    radius: Theme.pill(height)
    color: selected ? Theme.alpha(Theme.primary, 0.20) : Theme.tonal
    Behavior on color { CAnim {} }

    T {
        id: lbl
        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.width - 20)
        horizontalAlignment: Text.AlignHCenter
        text: root.text
        font.weight: root.selected ? Font.DemiBold : Font.Medium
        color: root.selected ? Theme.primary : Theme.textDim
    }
    StateLayer {
        tint: root.selected ? Theme.primary : Theme.text
        onClicked: root.clicked()
    }
}

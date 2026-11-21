import QtQuick
import "../core"

// Material Symbols Rounded glyph. `fill` (0..1) animates between outline and filled.
Text {
    id: root
    property string icon: ""
    property real size: 18
    property real fill: 0
    property int weight: 450
    text: icon
    color: Theme.text
    font.family: Theme.icons
    font.pixelSize: size
    font.variableAxes: ({ "FILL": root.fill, "wght": root.weight, "opsz": Math.max(20, Math.min(48, root.size)) })
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    Behavior on fill { Ease { duration: Anim.normal } }
    Behavior on color { CAnim {} }
}

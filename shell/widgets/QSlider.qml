import QtQuick
import "../core"

// Thick pill slider (Pixel quick-settings style): the fill carries the icon,
// the icon toggles mute, the value sits at the right.
Item {
    id: root
    property real value: 0          // 0..to
    property real to: 1
    property string icon: ""
    property bool showValue: true
    signal moved(real v)
    signal iconClicked

    readonly property real ratio: Math.max(0, Math.min(1, (drag.pressed ? drag.local : value) / to))
    implicitHeight: Theme.ctl
    implicitWidth: 200

    Rectangle {
        anchors.fill: parent
        radius: Theme.pill(height)
        color: Theme.tonal
    }
    Rectangle {
        id: fillBar
        height: parent.height
        radius: Theme.pill(height)
        width: Math.max(height, root.ratio * root.width)
        color: Theme.primary
        Behavior on width { enabled: !drag.pressed; Ease { duration: Anim.normal } }
        Behavior on color { CAnim {} }
    }
    Icon {
        x: (root.height - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        width: root.height * 0.6
        icon: root.icon
        size: root.height >= Theme.ctl ? Theme.icon : 16
        fill: 1
        color: Theme.primaryText
    }
    T {
        visible: root.showValue
        anchors.right: parent.right
        // as far from this end as the icon's ink is from the other
        anchors.rightMargin: Math.round((root.height - (root.height >= Theme.ctl ? Theme.icon : 16)) / 2 + 2)
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(root.ratio * 100 * root.to) + "%"
        font.pixelSize: Theme.fsSmall
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
        color: fillBar.width > root.width - 48 ? Theme.primaryText : Theme.textDim
    }
    MouseArea {
        id: drag
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        property real local: 0
        property bool onIcon: false
        function val(x) { return Math.max(0, Math.min(1, x / width)) * root.to; }
        onPressed: m => {
            onIcon = m.x < root.height;
            local = root.value;
            if (!onIcon) {
                local = val(m.x);
                root.moved(local);
            }
        }
        onPositionChanged: m => {
            if (pressed && (!onIcon || Math.abs(m.x - root.height / 2) > 8)) {
                onIcon = false;
                local = val(m.x);
                root.moved(local);
            }
        }
        onReleased: m => { if (onIcon) root.iconClicked(); }
        onWheel: w => root.moved(Math.max(0, Math.min(root.to, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}

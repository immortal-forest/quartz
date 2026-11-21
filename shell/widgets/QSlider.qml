import QtQuick
import "../core"

// Thick pill slider (Pixel quick-settings style): the fill carries the icon.
Item {
    id: root
    property real value: 0          // 0..to
    property real to: 1
    property string icon: ""
    property bool showValue: false
    signal moved(real v)
    signal iconClicked

    readonly property real ratio: Math.max(0, Math.min(1, (drag.pressed ? drag.local : value) / to))
    implicitHeight: 40
    implicitWidth: 200

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Theme.alpha(Theme.text, 0.07)
    }
    Rectangle {
        id: fillBar
        height: parent.height
        radius: height / 2
        width: Math.max(height, root.ratio * root.width)
        color: Theme.primary
        Behavior on width { enabled: !drag.pressed; Ease { duration: Anim.normal } }
        Behavior on color { CAnim {} }
    }
    Icon {
        id: ic
        x: (root.height - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        width: root.height * 0.6
        icon: root.icon
        size: 19
        fill: 1
        color: Theme.primaryText
    }
    T {
        visible: root.showValue
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(root.ratio * 100 * root.to) + "%"
        font.pixelSize: Theme.fsSmall
        font.weight: Font.DemiBold
        color: fillBar.width > root.width - 44 ? Theme.primaryText : Theme.textDim
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

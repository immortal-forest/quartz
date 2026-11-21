import QtQuick
import QtQuick.Layouts
import "../core"

// Pill button with an optional leading icon. `filled` = primary, else tonal.
Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property bool filled: true
    property bool small: false
    property color fg: filled ? Theme.primaryText : Theme.text
    signal clicked

    implicitHeight: small ? Theme.ctlSmall : Theme.ctl
    implicitWidth: row.implicitWidth + (small ? 28 : 36)
    // held: the corners tighten a little and spring back (M3 Expressive, as in astralis)
    radius: ma.pressed ? Math.min(height / 2, 10) : Theme.pill(height)
    Behavior on radius { Ease { duration: Anim.fast } }
    color: filled ? Theme.primary : Theme.tonal
    Behavior on color { CAnim {} }

    RowLayout {
        id: row
        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.width - (root.small ? 20 : 28))
        spacing: 6
        Icon {
            visible: root.icon.length > 0
            tight: true
            icon: root.icon
            size: root.small ? 16 : 18
            color: root.fg
        }
        T {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.text
            font.weight: Font.DemiBold
            font.pixelSize: root.small ? Theme.fsSmall + 1 : Theme.fsBody
            color: root.fg
        }
    }
    StateLayer {
        id: ma
        tint: root.fg
        onClicked: root.clicked()
    }
}

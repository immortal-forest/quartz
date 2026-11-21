import QtQuick
import QtQuick.Layouts
import "../core"

// Notification action chip (after astralis' ActChip): an outlined pill; the
// first action is tinted with the accent, a destructive one with the error
// colour, the rest stay neutral. Holding it squares the corners a little (the
// M3 Expressive press morph) instead of shrinking.
Rectangle {
    id: chip
    property string text: ""
    property string icon: ""
    property bool primary: false
    property bool danger: false
    signal clicked

    readonly property color ink: danger ? Theme.error : primary ? Theme.primary : Theme.text
    implicitHeight: Theme.ctlSmall
    implicitWidth: row.implicitWidth + 28
    radius: ma.pressed ? Math.min(height / 2, 8) : Theme.pill(height)
    color: danger ? Theme.alpha(Theme.error, 0.14) : primary ? Theme.alpha(Theme.primary, 0.14) : Theme.surfaceHigh
    border.width: 1
    border.color: danger ? Theme.alpha(Theme.error, 0.55) : primary ? Theme.alpha(Theme.primary, 0.5) : Theme.alpha(Theme.outlineVariant, 0.8)
    Behavior on radius { Ease { duration: Anim.fast } }
    Behavior on color { CAnim {} }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Icon {
            visible: chip.icon.length > 0
            tight: true
            icon: chip.icon
            size: 16
            color: chip.ink
        }
        T {
            text: chip.text
            font.pixelSize: Theme.fsSmall + 1
            font.weight: Font.DemiBold
            color: chip.ink
        }
    }
    StateLayer {
        id: ma
        tint: chip.ink
        onClicked: chip.clicked()
    }
}

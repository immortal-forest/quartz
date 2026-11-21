import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"
import "../widgets"

// Network · Bluetooth · volume · battery · notifications. Click → control centre,
// scroll → volume.
Rectangle {
    id: root
    property string screenName: ""
    readonly property bool open: Ui.panel === "control" && Ui.screen === screenName

    implicitWidth: row.implicitWidth + 22
    implicitHeight: 28
    radius: 9
    color: open ? Theme.alpha(Theme.primary, 0.16) : "transparent"
    Behavior on color { CAnim {} }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 10
        Icon {
            icon: Net.icon
            size: 17
            fill: 1
        }
        Icon {
            visible: Bt.on
            icon: Bt.icon
            size: 17
        }
        Icon {
            icon: Audio.icon
            size: 18
            fill: 1
            color: Audio.muted ? Theme.textDim : Theme.text
        }
        Battery {}
        Item {
            implicitWidth: 17
            implicitHeight: 17
            Icon {
                anchors.centerIn: parent
                icon: Config.opt.dnd ? "notifications_off" : "notifications"
                size: 17
                fill: Notifs.count > 0 ? 1 : 0
                color: Config.opt.dnd ? Theme.textDim : Theme.text
            }
            Rectangle {
                visible: Notifs.count > 0 && !Config.opt.dnd
                x: 10
                y: 0
                width: 7
                height: 7
                radius: 4
                color: Theme.primary
                border.width: 1.5
                border.color: Theme.surfaceLow
            }
        }
    }
    StateLayer {
        onClicked: Ui.togglePanel("control", root.screenName)
        onWheel: w => Audio.setVolume(Audio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))
    }
}

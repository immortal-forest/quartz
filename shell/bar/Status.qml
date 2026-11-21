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

    readonly property real padX: Theme.pad   // ink to the pill's edge
    implicitWidth: row.implicitWidth + padX * 2
    implicitHeight: Theme.barItem
    radius: Theme.rBarItem
    color: open ? Theme.alpha(Theme.primary, 0.16) : "transparent"
    Behavior on color { CAnim {} }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Theme.padCard
        Icon {
            icon: Net.icon
            size: Theme.iconBar
            fill: 1
            tight: true
        }
        Icon {
            visible: Bt.on
            icon: Bt.icon
            size: Theme.iconBar
            fill: 1
            tight: true
        }
        Icon {
            icon: Audio.icon
            size: Theme.iconBar
            fill: 1
            tight: true
            color: Audio.muted ? Theme.textDim : Theme.text
        }
        Battery { showText: Config.opt.batteryPercent }
        Item {
            implicitWidth: bell.width
            implicitHeight: Theme.iconBar
            Icon {
                id: bell
                anchors.centerIn: parent
                tight: true
                icon: Config.opt.dnd ? "notifications_off" : "notifications"
                size: Theme.iconBar
                fill: Notifs.count > 0 ? 1 : 0
                color: Config.opt.dnd ? Theme.textDim : Theme.text
            }
            Rectangle {
                visible: Notifs.count > 0 && !Config.opt.dnd
                // the unread dot sits on the bell's shoulder, measured to its ink
                x: parent.width - 6
                y: -1
                width: 8
                height: 8
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

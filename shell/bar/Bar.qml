import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../core"
import "../widgets"

// The floating bar: a frosted pill inset by Hyprland's gaps_out, so its edges
// line up with the windows below it.
PanelWindow {
    id: bar
    required property var scr
    readonly property var monitor: Hyprland.monitorFor(scr)

    screen: scr
    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.gap + Theme.barHeight
    exclusiveZone: Theme.gap + Theme.barHeight
    color: "transparent"
    WlrLayershell.namespace: "quartz-bar"
    WlrLayershell.layer: WlrLayer.Top
    mask: Region { item: pill }

    IdleInhibitor {
        window: bar
        enabled: Config.opt.caffeine
    }

    Rectangle {
        id: pill
        x: Theme.gap
        y: Theme.gap
        width: bar.width - Theme.gap * 2
        height: Theme.barHeight
        radius: 14
        color: Theme.glass
        border.width: 1
        border.color: Theme.hairline

        RowLayout {
            anchors.left: parent.left
            anchors.leftMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Workspaces {
                id: ws
                monitor: bar.monitor
            }
            ActiveWindow {
                monitor: bar.monitor
                Layout.maximumWidth: Math.max(0, pill.width / 2 - clock.width / 2 - ws.width - 28)
            }
        }

        Clock {
            id: clock
            anchors.centerIn: parent
            screenName: bar.scr.name
        }

        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            MediaChip {
                screenName: bar.scr.name
                Layout.maximumWidth: Math.max(0, pill.width / 2 - clock.width / 2 - 260)
            }
            Tray {
                screenName: bar.scr.name
            }
            Status {
                screenName: bar.scr.name
            }
        }
    }
}

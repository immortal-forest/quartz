import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../core"
import "../widgets"

// The floating bar: a frosted pill inset by Hyprland's gaps_out, so its edges
// line up with the windows below it.
//
// Layout: every chip is barItem tall and sits `inset` in from the pill's ends,
// the same as from its top and bottom, so chip corners (rBarItem) are concentric
// with the bar's (rBar). Chips pad their content by Theme.padCard; groups are
// Theme.spacing apart; nothing on either side comes closer than `clockGap` to
// the centred clock — the window title and the media title elide there.
PanelWindow {
    id: bar
    required property var scr
    readonly property var monitor: Hyprland.monitorFor(scr)
    // a panel hanging flush from this end of the bar: square that corner off
    property bool joinLeft: false
    property bool joinRight: false

    readonly property real inset: (Theme.barHeight - Theme.barItem) / 2
    readonly property real clockGap: Theme.spacing * 2

    screen: scr
    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.gap + Theme.barHeight
    exclusiveZone: Theme.gap + Theme.barHeight
    color: "transparent"
    WlrLayershell.namespace: "quartz-bar"
    WlrLayershell.layer: WlrLayer.Top
    mask: Region { item: pill }

    // where the dropdowns hang from
    readonly property real clockX: pill.x + clock.x + clock.width / 2
    readonly property real mediaX: pill.x + rightRow.x + media.x + media.width / 2
    readonly property real statusX: pill.x + rightRow.x + status.x + status.width / 2
    function publish() {
        Ui.setAnchor(scr.name, "calendar", clockX);
        Ui.setAnchor(scr.name, "media", media.width > 1 ? mediaX : statusX);
        Ui.setAnchor(scr.name, "control", statusX);
    }
    onClockXChanged: publish()
    onMediaXChanged: publish()
    onStatusXChanged: publish()
    Component.onCompleted: publish()

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
        radius: Theme.rBar
        bottomLeftRadius: bar.joinLeft ? 0 : Theme.rBar
        bottomRightRadius: bar.joinRight ? 0 : Theme.rBar
        Behavior on bottomLeftRadius { Ease { duration: Anim.fast } }
        Behavior on bottomRightRadius { Ease { duration: Anim.fast } }
        color: Theme.glassStrong

        // left: workspaces at a fixed spot, then the window title. The title is
        // capped (420 px, and never past the clock) and can never push or cover
        // the workspaces.
        Workspaces {
            id: ws
            x: bar.inset
            anchors.verticalCenter: parent.verticalCenter
            width: implicitWidth
            monitor: bar.monitor
        }
        ActiveWindow {
            id: title
            x: ws.x + ws.width + Theme.spacing
            anchors.verticalCenter: parent.verticalCenter
            width: implicitWidth
            clip: true
            monitor: bar.monitor
            maxWidth: Math.max(0, Math.min(420, clock.x - bar.clockGap - x))
        }
        Clock {
            id: clock
            anchors.centerIn: parent
            screenName: bar.scr.name
        }
        // The song, the tray and the status icons sit `groupGap` apart, ink to
        // ink: each margin takes off the padding its neighbours already have
        // inside (the chip's, a tray cell's, the status pill's).
        RowLayout {
            id: rightRow
            readonly property real groupGap: Theme.pad + Theme.padCard
            readonly property real trayPad: (Theme.barItem - Theme.iconBar) / 2
            anchors.right: parent.right
            anchors.rightMargin: bar.inset
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            MediaChip {
                id: media
                screenName: bar.scr.name
                maxWidth: pill.width - bar.inset - clock.x - clock.width - bar.clockGap
                          - (tray.visible ? tray.implicitWidth + tray.Layout.leftMargin : 0)
                          - status.implicitWidth - status.Layout.leftMargin
            }
            Tray {
                id: tray
                screenName: bar.scr.name
                Layout.leftMargin: media.shown ? rightRow.groupGap - media.padX - rightRow.trayPad : 0
            }
            Status {
                id: status
                screenName: bar.scr.name
                Layout.leftMargin: tray.visible ? rightRow.groupGap - rightRow.trayPad - status.padX
                                 : media.shown ? rightRow.groupGap - media.padX - status.padX : 0
            }
        }
    }
}

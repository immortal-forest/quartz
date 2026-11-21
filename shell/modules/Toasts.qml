import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../core"
import "../services"
import "../widgets"

// Notification pop-ups, top-right under the bar, newest on top. Each times
// out on its own (hover pauses it); critical ones stay until handled.
PanelWindow {
    id: win
    property bool lingering: true
    readonly property int cardW: 380

    screen: Quickshell.screens.find(s => s.name === Ui.focusedScreen()) ?? Quickshell.screens[0]
    anchors { top: true; right: true }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    implicitWidth: cardW + Theme.gap + 28
    implicitHeight: Math.max(1, list.contentHeight + 46)
    color: "transparent"
    WlrLayershell.namespace: "quartz-toast"
    WlrLayershell.layer: WlrLayer.Top
    mask: Region { item: hit }

    Timer {
        interval: 600
        running: Notifs.toasts.count === 0
        onTriggered: win.lingering = false
    }

    Item {
        id: hit
        x: list.x
        y: list.y
        width: list.width
        height: list.contentHeight
    }

    ListView {
        id: list
        x: 28
        y: 6
        width: win.cardW
        height: contentHeight
        interactive: false
        spacing: 8
        model: Notifs.toasts
        delegate: Item {
            id: d
            required property int nid
            width: list.width
            height: card.implicitHeight
            NotifCard {
                id: card
                width: parent.width
                nid: d.nid
                toast: true
                onHideRequested: Notifs.hideToast(d.nid)
            }
            Timer {
                interval: card.actions.length ? 9000 : 5500
                running: !card.critical && !card.hovered
                onTriggered: {
                    if (card.n?.transient)
                        card.n.expire();
                    Notifs.hideToast(d.nid);
                }
            }
        }
        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "x"; from: win.cardW * 0.6; to: 0; duration: Anim.slower; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Anim.normal }
            }
        }
        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "x"; to: win.cardW * 0.7; duration: Anim.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Anim.accel }
                NumberAnimation { property: "opacity"; to: 0; duration: Anim.normal }
            }
        }
        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: Anim.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Anim.emphasized }
        }
    }
}

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
    readonly property int cardW: 400

    screen: Quickshell.screens.find(s => s.name === Ui.focusedScreen()) ?? Quickshell.screens[0]
    anchors { top: true; right: true }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    implicitWidth: cardW + Theme.gap + 28
    property real maxH: 1
    readonly property real needH: list.implicitHeight + Theme.gap + 40
    onNeedHChanged: maxH = Notifs.toasts.count ? Math.max(maxH, needH) : maxH
    implicitHeight: Math.max(1, maxH)
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
        height: list.implicitHeight
    }

    // A Column, not a ListView: cards change height after they appear (a
    // preview image loads), and a ListView sized to its own content
    // under-measures them — the next card then covered the buttons.
    Column {
        id: list
        x: 28
        y: Theme.gap
        width: win.cardW
        spacing: Theme.spacing
        move: Transition {
            NumberAnimation { properties: "y"; duration: Anim.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Anim.emphasized }
        }
        Repeater {
            model: Notifs.toasts
            delegate: Item {
                id: d
                required property int nid
                width: list.width
                height: card.implicitHeight
                // slides in from the right, slides back out before it's removed
                property bool entered: false
                property bool leaving: false
                Component.onCompleted: entered = true
                opacity: entered && !leaving ? 1 : 0
                transform: Translate {
                    x: d.leaving ? win.cardW * 0.6 : d.entered ? 0 : win.cardW * 0.5
                    Behavior on x { Ease { duration: d.leaving ? Anim.normal : Anim.slower; easing.bezierCurve: d.leaving ? Anim.accel : Anim.decel } }
                }
                Behavior on opacity { Ease { duration: Anim.normal } }
                function leave() {
                    if (leaving)
                        return;
                    leaving = true;
                    gone.start();
                }
                Timer {
                    id: gone
                    interval: Anim.normal + 20
                    onTriggered: Notifs.hideToast(d.nid)
                }
                NotifCard {
                    id: card
                    width: parent.width
                    nid: d.nid
                    toast: true
                    onHideRequested: d.leave()
                }
                Timer {
                    // Settings › Notifications › Pop-up time (+3 s when there are buttons to press)
                    interval: (Config.opt.popupTime === "short" ? 4000 : Config.opt.popupTime === "long" ? 10000 : 6000) + (card.actions.length || card.shot ? 3000 : 0)
                    running: !card.critical && !card.hovered && !d.leaving
                    onTriggered: {
                        if (card.n?.transient)
                            card.n.expire();
                        d.leave();
                    }
                }
            }
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../core"

// A dropdown under the bar (control centre, calendar, media, tray menu).
// Lives in a LazyLoader: `active: <want> || (item?.lingering ?? false)` keeps
// it alive through the exit animation, then it is destroyed (no idle cost).
PanelWindow {
    id: win
    required property var scr
    property var barWin: null
    property string name: ""
    property string side: "right"      // right | center | left
    property real leftOffset: 0        // side "left": x of the card on the screen
    property real cardWidth: 380
    property real contentHeight: 200   // the panel's content height (card grows/shrinks to it)
    readonly property real topPad: 6
    readonly property real sidePad: side === "center" ? 28 : side === "left" ? 28 : Theme.gap
    readonly property real bottomPad: 40
    readonly property bool want: Ui.panel === name && Ui.screen === (scr?.name ?? "")
    property bool shown: false
    property bool lingering: true
    default property alias body: inner.data
    property alias card: card

    // The window only ever grows while open, so shrinking content is not clipped mid-animation.
    property real maxH: 0
    readonly property real targetH: Math.ceil(contentHeight)
    onTargetHChanged: maxH = Math.max(maxH, targetH)
    Component.onCompleted: {
        maxH = targetH;
        shown = Qt.binding(() => win.want);
    }

    screen: scr
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    anchors.top: true
    anchors.right: side === "right"
    anchors.left: side === "left"
    margins.left: side === "left" ? Math.max(0, leftOffset - sidePad) : 0
    implicitWidth: cardWidth + sidePad * (side === "center" ? 2 : side === "left" ? 2 : 1) + (side === "right" ? 28 : 0)
    implicitHeight: maxH + topPad + bottomPad
    WlrLayershell.namespace: "quartz-panel"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    mask: Region { item: card }

    HyprlandFocusGrab {
        id: grab
        active: win.shown
        windows: win.barWin ? [win, win.barWin] : [win]
        // Only a click outside (compositor clears the grab) closes the panel —
        // not our own deactivate/reactivate when the panel is re-targeted.
        onCleared: if (win.want && !grab.active) Ui.panel = ""
    }

    Card {
        id: card
        x: win.side === "right" ? win.width - win.sidePad - win.cardWidth : win.sidePad
        y: win.topPad + (win.shown ? 0 : -10)
        width: win.cardWidth
        height: win.targetH
        transformOrigin: win.side === "right" ? Item.TopRight : win.side === "left" ? Item.TopLeft : Item.Top
        scale: win.shown ? 1 : 0.94
        opacity: win.shown ? 1 : 0
        Behavior on y { Spring { spring: 3.6; damping: 0.38 } }
        Behavior on scale { Spring { spring: 3.6; damping: 0.38; epsilon: 0.003 } }
        Behavior on opacity { Ease { duration: win.shown ? Anim.normal : Anim.fast } }
        Behavior on height { Ease { duration: Anim.slow; easing.bezierCurve: Anim.emphasized } }
        onOpacityChanged: if (!win.shown && opacity < 0.02) win.lingering = false

        Item {
            id: inner
            anchors.fill: parent
            clip: true
            focus: true
            Keys.onEscapePressed: Ui.panel = ""
        }
    }
}

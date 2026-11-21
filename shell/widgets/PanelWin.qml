import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../core"

// A dropdown that hangs from the bar (control centre, calendar, media, tray
// menu): it touches the bar's bottom edge, shares its glass, joins it with
// concave fillets and slides out from under it. Where the panel is flush with
// the bar's end, the bar squares that corner off (joinLeft / joinRight).
//
// Lifecycle (shell.qml's Slot): created when wanted, `lingering` drops to false
// a fixed time after it is hidden, then the loader destroys it. While hidden it
// takes no input, so an exiting panel never blocks clicks.
PanelWindow {
    id: win
    required property var scr
    property var barWin: null
    property string name: ""
    property string side: "right"      // fallback when the bar hasn't published an anchor: right | center
    property real anchorX: Ui.anchors[(scr?.name ?? "") + ":" + name] ?? -1   // centre x of the owning bar item
    property real cardWidth: 380
    property real contentHeight: 200   // the panel's content height (card grows/shrinks to it)
    readonly property real sidePad: 28     // room for the fillets + shadow beside the card
    readonly property real bottomPad: 40
    readonly property bool want: Ui.panel === name && Ui.screen === (scr?.name ?? "")
    property bool shown: false
    property bool lingering: true
    property bool settled: false       // entrance finished: size changes animate from here on
    // persistent: built once and kept (the control centre) — opening is then just
    // the animation. While hidden the window is unmapped: no buffers, no input.
    property bool persistent: false
    visible: !persistent || shown || lingering
    property real reveal: 0            // 0 = folded into the bar, 1 = fully out (springs a touch past 1)
    default property alias body: content.data
    property alias card: card

    // where the card sits on the screen, and whether it is flush with the bar's ends
    readonly property real screenW: scr?.width ?? 1600
    readonly property real cardScreenX: {
        const lo = Theme.gap, hi = screenW - Theme.gap - cardWidth;
        const want = anchorX >= 0 ? anchorX - cardWidth / 2 : side === "right" ? hi : (screenW - cardWidth) / 2;
        return Math.round(Math.max(lo, Math.min(hi, want)));
    }
    readonly property real winX: Math.max(0, cardScreenX - sidePad)
    readonly property bool flushLeft: cardScreenX <= Theme.gap + 0.5
    readonly property bool flushRight: cardScreenX + cardWidth >= screenW - Theme.gap - 0.5
    // keep the bar's corner square until this panel is gone, so no sliver shows on the way out
    Binding {
        when: !!win.barWin
        target: win.barWin
        property: "joinRight"
        value: win.lingering && win.flushRight
    }
    Binding {
        when: !!win.barWin
        target: win.barWin
        property: "joinLeft"
        value: win.lingering && win.flushLeft
    }

    // The window only ever grows while open, so shrinking content is not clipped mid-animation.
    property real maxH: 0
    readonly property real targetH: Math.ceil(contentHeight)
    onTargetHChanged: maxH = Math.max(maxH, targetH)
    Component.onCompleted: {
        maxH = targetH;
        shown = Qt.binding(() => win.want);
        if (!shown)
            done.restart();
    }
    onShownChanged: {
        if (shown) {
            lingering = true;
            done.stop();
            fold.stop();
            unfold.restart();
            settle.restart();
        } else {
            settled = false;
            settle.stop();
            unfold.stop();
            fold.restart();
            done.restart();
        }
    }
    // open: unfold out of the bar with a small spring overshoot
    SpringAnimation {
        id: unfold
        target: win
        property: "reveal"
        to: 1
        spring: Anim.full ? 3.2 : Anim.k > 0 ? 12 : 60
        damping: Anim.full ? 0.34 : 1
        epsilon: 0.001
    }
    // close: fold back up into the bar, quick and clean
    NumberAnimation {
        id: fold
        target: win
        property: "reveal"
        to: 0
        duration: Anim.normal - 30
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Anim.accel
    }
    Timer {
        id: settle
        interval: Anim.slower
        onTriggered: win.settled = true
    }
    Timer {
        id: done
        interval: Anim.normal + 80
        onTriggered: win.lingering = false
    }

    screen: scr
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    anchors.top: true
    anchors.left: true
    margins.left: winX
    implicitWidth: Math.min(screenW - winX, cardScreenX - winX + cardWidth + sidePad)
    implicitHeight: maxH * 1.08 + bottomPad   // room for the open overshoot
    WlrLayershell.namespace: "quartz-panel"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region { item: win.shown ? card : null }

    HyprlandFocusGrab {
        id: grab
        active: win.shown
        windows: win.barWin ? [win, win.barWin] : [win]
        // Only a click outside (compositor clears the grab) closes the panel —
        // not our own deactivate/reactivate when the panel is re-targeted.
        onCleared: if (win.want && !grab.active) Ui.panel = ""
    }

    // The card's top is pinned to the bar; it grows down to its full height.
    Card {
        id: card
        property real fullH: win.targetH
        x: win.cardScreenX - win.winX
        y: 0
        width: win.cardWidth
        height: Math.max(0, fullH * win.reveal)
        visible: height > 0.5
        radiusTop: 0
        edge: false
        shadow: height > 24
        Behavior on fullH { enabled: win.settled; Ease { duration: Anim.slow; easing.bezierCurve: Anim.emphasized } }

        // concave joins to the bar; they grow in with the panel
        Fillet {
            visible: !win.flushLeft
            r: Math.min(Theme.rBar, card.height)
            x: -width
            color: card.color
        }
        Fillet {
            visible: !win.flushRight
            flip: true
            r: Math.min(Theme.rBar, card.height)
            x: card.width
            color: card.color
        }
        Item {
            id: inner
            anchors.fill: parent
            clip: true
            focus: true
            Keys.onEscapePressed: Ui.panel = ""
            // content is pulled out with the card (rides 24 px behind it) and fades in early
            Item {
                id: content
                width: win.cardWidth
                height: card.fullH
                y: -(1 - Math.min(1, win.reveal)) * 24
                opacity: Math.min(1, win.reveal * 1.6)
            }
        }
    }
}

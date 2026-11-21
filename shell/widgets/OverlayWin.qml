import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

// Full-screen overlay (launcher, power menu, clipboard, wallpapers): a scrim,
// exclusive keyboard while shown, and a stage that scales/fades in. Click the
// scrim or press Escape to close. Same lifecycle as PanelWin: no input while
// hidden, destroyed a fixed time after it hides.
PanelWindow {
    id: win
    required property var scr
    property string name: ""
    property real dim: 0.35
    property string ns: "quartz-overlay"
    readonly property bool want: Ui.overlay === name && Ui.screen === (scr?.name ?? "")
    property bool shown: false
    property bool lingering: true
    property bool settled: false
    default property alias body: stage.data
    property alias stage: stage
    Component.onCompleted: {
        shown = Qt.binding(() => win.want);
        if (!shown)
            done.restart();
    }
    onShownChanged: {
        if (shown) {
            lingering = true;
            done.stop();
            settle.restart();
        } else {
            settled = false;
            settle.stop();
            done.restart();
        }
    }
    Timer {
        id: settle
        interval: Anim.slow
        onTriggered: win.settled = true
    }
    Timer {
        id: done
        interval: Anim.normal + 120
        onTriggered: win.lingering = false
    }

    screen: scr
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: ns
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: win.shown ? scrim : null }

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: "black"
        opacity: win.shown ? win.dim : 0
        Behavior on opacity { Ease { duration: win.shown ? Anim.slow : Anim.normal } }
        MouseArea {
            anchors.fill: parent
            onClicked: Ui.overlay = ""
        }
    }

    Item {
        id: stage
        anchors.fill: parent
        focus: true
        opacity: win.shown ? 1 : 0
        scale: win.shown ? 1 : 0.96
        Behavior on opacity { Ease { duration: win.shown ? Anim.normal : Anim.fast } }
        Behavior on scale { Ease { duration: win.shown ? Anim.slow : Anim.normal; easing.bezierCurve: win.shown ? Anim.decel : Anim.accel } }
        Keys.onEscapePressed: Ui.overlay = ""
    }
}

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

// Full-screen overlay (launcher, power menu, clipboard, wallpapers): a scrim,
// exclusive keyboard, and a stage that scales/fades in. Click the scrim or
// press Escape to close. Lives in a LazyLoader like PanelWin.
PanelWindow {
    id: win
    required property var scr
    property string name: ""
    property real dim: 0.35
    property string ns: "quartz-overlay"
    readonly property bool want: Ui.overlay === name && Ui.screen === (scr?.name ?? "")
    property bool shown: false
    property bool lingering: true
    default property alias body: stage.data
    property alias stage: stage
    Component.onCompleted: shown = Qt.binding(() => win.want)

    screen: scr
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: ns
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: win.shown ? win.dim : 0
        Behavior on opacity { Ease { duration: win.shown ? Anim.slow : Anim.normal } }
        onOpacityChanged: if (!win.shown && opacity < 0.01) win.lingering = false
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
        scale: win.shown ? 1 : 0.95
        Behavior on opacity { Ease { duration: win.shown ? Anim.normal : Anim.fast } }
        Behavior on scale { Spring { spring: 3.4; damping: 0.4; epsilon: 0.003 } }
        Keys.onEscapePressed: Ui.overlay = ""
    }
}

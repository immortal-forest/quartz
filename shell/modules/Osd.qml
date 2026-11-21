import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../core"
import "../services"
import "../widgets"

// Volume / mic / brightness indicator, bottom-centre, click-through.
Scope {
    id: root
    property string kind: "volume"
    property string device: ""
    property bool show: false
    property bool lingering: false

    function trigger(k) {
        root.kind = k;
        root.show = true;
        root.lingering = true;
        gone.stop();
        hideTimer.restart();
    }
    Connections {
        target: Audio
        function onChanged(k) { if (Ui.panel !== "control") root.trigger(k); }
    }
    Connections {
        target: Audio
        function onSwitched(name) { root.device = name; root.trigger("device"); }
    }
    Connections {
        target: Brightness
        function onStepped() { if (Ui.panel !== "control") root.trigger("brightness"); }
    }
    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: {
            root.show = false;
            gone.restart();
        }
    }
    // destroyed only after the exit animation has played
    Timer {
        id: gone
        interval: Anim.normal + 120
        onTriggered: root.lingering = false
    }

    LazyLoader {
        active: root.show || root.lingering
        PanelWindow {
            id: win
            screen: Quickshell.screens.find(s => s.name === Ui.focusedScreen()) ?? Quickshell.screens[0]
            anchors.bottom: true
            margins.bottom: 56
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: 320
            implicitHeight: 100
            color: "transparent"
            WlrLayershell.namespace: "quartz-osd"
            WlrLayershell.layer: WlrLayer.Overlay
            mask: Region {}

            readonly property real value: root.kind === "brightness" ? Brightness.value : root.kind === "mic" ? (Audio.micMuted ? 0 : Audio.micVolume) : (Audio.muted ? 0 : Audio.volume)
            readonly property string icon: root.kind === "brightness" ? Brightness.icon : root.kind === "mic" ? Audio.micIcon : root.kind === "device" ? "headphones" : Audio.icon
            property bool shown: false
            Component.onCompleted: shown = Qt.binding(() => root.show)

            Card {
                id: pill
                anchors.horizontalCenter: parent.horizontalCenter
                y: 20 + (win.shown ? 0 : 24)
                width: 300
                height: Theme.tile - 8
                radius: Theme.pill(height)
                opacity: win.shown ? 1 : 0
                scale: win.shown ? 1 : 0.94
                Behavior on y { Ease { duration: win.shown ? Anim.slow : Anim.normal; easing.bezierCurve: win.shown ? Anim.decel : Anim.accel } }
                Behavior on scale { Ease { duration: win.shown ? Anim.slow : Anim.normal; easing.bezierCurve: win.shown ? Anim.decel : Anim.accel } }
                Behavior on opacity { Ease { duration: win.shown ? Anim.fast : Anim.normal } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 22
                    spacing: 14
                    Icon {
                        icon: win.icon
                        size: 22
                        fill: 1
                        color: Theme.primary
                    }
                    T {
                        visible: root.kind === "device"
                        Layout.fillWidth: true
                        text: root.device
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        visible: root.kind !== "device"
                        Layout.fillWidth: true
                        implicitHeight: 8
                        radius: Theme.pill(height)
                        color: Theme.alpha(Theme.text, 0.12)
                        Rectangle {
                            height: parent.height
                            radius: Theme.pill(height)
                            width: Math.max(height, parent.width * Math.min(1, win.value))
                            color: win.value > 1 ? Theme.error : Theme.primary
                            Behavior on width { Ease { duration: Anim.fast } }
                        }
                    }
                    T {
                        Layout.preferredWidth: 34
                        horizontalAlignment: Text.AlignRight
                        text: Math.round(win.value * 100)
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }
    }
}

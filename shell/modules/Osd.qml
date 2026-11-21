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
    property bool show: false
    property bool lingering: false

    function trigger(k) {
        root.kind = k;
        root.show = true;
        root.lingering = true;
        hideTimer.restart();
    }
    Connections {
        target: Audio
        function onChanged(k) { if (Ui.panel !== "control") root.trigger(k); }
    }
    Connections {
        target: Brightness
        function onStepped() { if (Ui.panel !== "control") root.trigger("brightness"); }
    }
    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.show = false
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
            readonly property string icon: root.kind === "brightness" ? Brightness.icon : root.kind === "mic" ? Audio.micIcon : Audio.icon
            property bool shown: false
            Component.onCompleted: shown = Qt.binding(() => root.show)

            Card {
                id: pill
                anchors.horizontalCenter: parent.horizontalCenter
                y: 20 + (win.shown ? 0 : 24)
                width: 280
                height: 56
                radius: 28
                opacity: win.shown ? 1 : 0
                scale: win.shown ? 1 : 0.9
                Behavior on y { Spring { spring: 3.8; damping: 0.4 } }
                Behavior on scale { Spring { spring: 3.8; damping: 0.4; epsilon: 0.003 } }
                Behavior on opacity { Ease { duration: win.shown ? Anim.fast : Anim.normal } }
                onOpacityChanged: if (!win.shown && opacity < 0.02) root.lingering = false

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 20
                    spacing: 14
                    Icon {
                        icon: win.icon
                        size: 22
                        fill: 1
                        color: Theme.primary
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 8
                        radius: 4
                        color: Theme.alpha(Theme.text, 0.12)
                        Rectangle {
                            height: parent.height
                            radius: 4
                            width: parent.width * Math.min(1, win.value)
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

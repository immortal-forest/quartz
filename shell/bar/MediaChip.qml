import QtQuick
import Quickshell
import Quickshell.Widgets
import "../core"
import "../services"
import "../widgets"

// Now playing: cover + title + state. Click → media panel, middle-click →
// play/pause, scroll → next / previous. Width = padding + cover + title + icon,
// the title capped at `titleCap` and at whatever `maxWidth` (from the bar)
// leaves it; content sits at fixed x and the chip's clip reveals it as it grows.
Rectangle {
    id: root
    property string screenName: ""
    property real maxWidth: Infinity
    readonly property bool open: Ui.panel === "media" && Ui.screen === screenName
    readonly property bool shown: Media.hasTrack && Config.opt.barMedia

    readonly property real padX: Theme.padCard
    readonly property real art: Theme.icon
    readonly property real titleCap: 200
    readonly property real fixedW: padX * 2 + art + trail.width + Theme.spacing * 2
    readonly property real titleW: Math.max(0, Math.min(measure.implicitWidth, titleCap, maxWidth - fixedW))

    implicitHeight: Theme.barItem
    implicitWidth: shown ? fixedW + titleW : 0
    opacity: shown ? 1 : 0
    visible: opacity > 0.01 || implicitWidth > 0.5
    clip: true
    radius: Theme.rBarItem
    color: open ? Theme.alpha(Theme.primary, 0.16) : "transparent"
    Behavior on implicitWidth { Spring { baseSpring: 3.6; baseDamping: 0.45 } }
    Behavior on opacity { Ease {} }
    Behavior on color { CAnim {} }

    ClippingRectangle {
        id: cover
        x: root.padX
        anchors.verticalCenter: parent.verticalCenter
        width: root.art
        height: root.art
        radius: root.art / 2
        color: Theme.surfaceHighest
        Image {
            anchors.fill: parent
            source: Media.art
            sourceSize: Qt.size(root.art * 2, root.art * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }
        Icon {
            anchors.centerIn: parent
            visible: !Media.art.length
            icon: "music_note"
            fill: 1
            size: root.art * 0.65
            color: Theme.textDim
        }
    }
    T {
        id: label
        x: cover.x + root.art + Theme.spacing
        anchors.verticalCenter: parent.verticalCenter
        width: root.titleW
        text: Media.title
        font.weight: Font.Medium
        color: Media.playing ? Theme.text : Theme.textDim
    }
    T {
        id: measure     // the title's natural width, independent of the width it gets
        visible: false
        elide: Text.ElideNone
        text: label.text
        font: label.font
    }
    Icon {
        id: trail
        x: label.x + root.titleW + Theme.spacing
        anchors.verticalCenter: parent.verticalCenter
        tight: true
        icon: Media.playing ? "graphic_eq" : "pause"
        fill: 1
        size: Theme.iconBar
        color: Media.playing ? Theme.primary : Theme.textDim
    }
    StateLayer {
        onClicked: m => {
            if (m.button === Qt.MiddleButton)
                Media.toggle();
            else
                Ui.togglePanel("media", root.screenName);
        }
        onWheel: w => (w.angleDelta.y > 0 ? Media.previous() : Media.next())
    }
}

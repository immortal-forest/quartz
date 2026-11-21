import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../core"
import "../services"
import "../widgets"

// Now playing: cover + title. Click → media panel, middle-click → play/pause,
// scroll → next / previous.
Rectangle {
    id: root
    property string screenName: ""
    readonly property bool open: Ui.panel === "media" && Ui.screen === screenName
    readonly property bool shown: Media.hasTrack

    implicitHeight: 28
    implicitWidth: shown ? row.implicitWidth + 18 : 0
    opacity: shown ? 1 : 0
    visible: opacity > 0.01 || implicitWidth > 0.5
    clip: true
    radius: 9
    color: open ? Theme.alpha(Theme.primary, 0.16) : "transparent"
    Behavior on implicitWidth { Spring { spring: 3.6; damping: 0.45 } }
    Behavior on opacity { Ease {} }
    Behavior on color { CAnim {} }

    RowLayout {
        id: row
        x: 9
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        ClippingWrapperRectangle {
            radius: 5
            color: Theme.surfaceHighest
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            Item {
                implicitWidth: 18
                implicitHeight: 18
                Image {
                    anchors.fill: parent
                    source: Media.art
                    sourceSize: Qt.size(36, 36)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }
                Icon {
                    anchors.centerIn: parent
                    visible: !Media.art.length
                    icon: "music_note"
                    size: 13
                    color: Theme.textDim
                }
            }
        }
        T {
            Layout.maximumWidth: 170
            text: Media.title
            font.weight: Font.Medium
            color: Media.playing ? Theme.text : Theme.textDim
        }
        Icon {
            icon: Media.playing ? "graphic_eq" : "pause"
            size: 15
            color: Media.playing ? Theme.primary : Theme.textDim
        }
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

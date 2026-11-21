import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import "../core"
import "../services"
import "../widgets"

// Now playing: big cover, seekable progress, transport, player switcher.
PanelWin {
    id: win
    name: "media"
    side: "right"
    cardWidth: 360
    contentHeight: col.implicitHeight + 36

    readonly property var p: Media.active
    property real pos: 0
    Timer {
        interval: 500
        repeat: true
        triggeredOnStart: true
        running: win.shown && Media.playing
        onTriggered: win.pos = win.p?.position ?? 0
    }
    Connections {
        target: win.p
        function onPositionChanged() { win.pos = win.p.position; }
    }

    ColumnLayout {
        id: col
        x: 18
        y: 18
        width: parent.width - 36
        spacing: 14

        ClippingRectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: width
            radius: 18
            color: Theme.surfaceHighest
            Image {
                anchors.fill: parent
                source: Media.art
                sourceSize: Qt.size(640, 640)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Icon {
                anchors.centerIn: parent
                visible: !Media.art.length
                icon: "album"
                size: 64
                color: Theme.textDim
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            T {
                Layout.fillWidth: true
                text: Media.title || "Nothing playing"
                font.family: Theme.display
                font.pixelSize: Theme.fsLarge
                font.weight: Font.Medium
            }
            T {
                Layout.fillWidth: true
                text: [Media.artist, win.p?.trackAlbum ?? ""].filter(s => s.length).join(" — ")
                color: Theme.textDim
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: (win.p?.length ?? 0) > 0
            Item {
                Layout.fillWidth: true
                implicitHeight: 16
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Theme.alpha(Theme.text, 0.12)
                    Rectangle {
                        height: parent.height
                        radius: 3
                        width: parent.width * Math.max(0, Math.min(1, (seek.pressed ? seek.v : win.pos) / (win.p?.length || 1)))
                        color: Theme.primary
                        Behavior on width { enabled: !seek.pressed; Ease { duration: 500 } }
                    }
                }
                MouseArea {
                    id: seek
                    anchors.fill: parent
                    enabled: win.p?.canSeek ?? false
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    property real v: 0
                    onPressed: m => v = Math.max(0, Math.min(1, m.x / width)) * win.p.length
                    onPositionChanged: m => v = Math.max(0, Math.min(1, m.x / width)) * win.p.length
                    onReleased: { win.p.position = v; win.pos = v; }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                T { text: Media.fmt(seek.pressed ? seek.v : win.pos); font.pixelSize: Theme.fsSmall; color: Theme.textDim; font.features: { "tnum": 1 } }
                Item { Layout.fillWidth: true }
                T { text: Media.fmt(win.p?.length ?? 0); font.pixelSize: Theme.fsSmall; color: Theme.textDim; font.features: { "tnum": 1 } }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            IconBtn {
                visible: win.p?.shuffleSupported ?? false
                icon: "shuffle"
                active: win.p?.shuffle ?? false
                onClicked: win.p.shuffle = !win.p.shuffle
            }
            IconBtn {
                icon: "skip_previous"
                size: 44
                iconSize: 24
                onClicked: Media.previous()
            }
            Rectangle {
                implicitWidth: 72
                implicitHeight: 56
                radius: Media.playing ? 18 : 28
                color: Theme.primary
                Behavior on radius { Spring { spring: 4; damping: 0.45 } }
                Icon {
                    anchors.centerIn: parent
                    icon: Media.playing ? "pause" : "play_arrow"
                    size: 30
                    fill: 1
                    color: Theme.primaryText
                }
                StateLayer {
                    tint: Theme.primaryText
                    onClicked: Media.toggle()
                }
            }
            IconBtn {
                icon: "skip_next"
                size: 44
                iconSize: 24
                onClicked: Media.next()
            }
            IconBtn {
                visible: win.p?.loopSupported ?? false
                icon: win.p?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                active: (win.p?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
                onClicked: win.p.loopState = win.p.loopState === MprisLoopState.None ? MprisLoopState.Playlist : win.p.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: Media.players.length > 1
            spacing: 6
            Repeater {
                model: Media.players
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: modelData === Media.active
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: 15
                    color: on ? Theme.secondaryContainer : Theme.alpha(Theme.text, 0.06)
                    T {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        horizontalAlignment: Text.AlignHCenter
                        text: parent.modelData.identity
                        font.pixelSize: Theme.fsSmall
                        color: parent.on ? Theme.secondaryContainerText : Theme.textDim
                    }
                    StateLayer { onClicked: Media.last = parent.modelData }
                }
            }
        }
    }
}

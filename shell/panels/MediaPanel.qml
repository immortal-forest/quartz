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
    cardWidth: 380
    contentHeight: col.implicitHeight + Theme.pad * 2

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
        x: Theme.pad
        y: Theme.pad
        width: parent.width - Theme.pad * 2
        spacing: 14

        // nothing playing: a short empty state instead of a blank cover
        ColumnLayout {
            visible: !Media.hasTrack
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.bottomMargin: 12
            spacing: 6
            Icon {
                Layout.alignment: Qt.AlignHCenter
                icon: "music_off"
                size: 32
                color: Theme.textDim
            }
            T {
                Layout.alignment: Qt.AlignHCenter
                text: "Nothing playing"
                font.family: Theme.display
                font.pixelSize: Theme.fsTitle
                font.weight: Font.Medium
            }
            T {
                Layout.alignment: Qt.AlignHCenter
                text: "Play something in a music app or browser"
                font.pixelSize: Theme.fsSmall
                color: Theme.textDim
            }
        }

        ClippingRectangle {
            visible: Media.hasTrack
            Layout.fillWidth: true
            Layout.preferredHeight: width
            radius: Theme.rCard
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
            visible: Media.hasTrack
            Layout.fillWidth: true
            spacing: 2
            T {
                Layout.fillWidth: true
                text: Media.title
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
            visible: Media.hasTrack && (win.p?.length ?? 0) > 0
            Item {
                Layout.fillWidth: true
                implicitHeight: 16
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: Theme.pill(height)
                    color: Theme.tonal
                    Rectangle {
                        height: parent.height
                        radius: Theme.pill(height)
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
            visible: Media.hasTrack
            Layout.alignment: Qt.AlignHCenter
            spacing: 12
            IconBtn {
                visible: win.p?.shuffleSupported ?? false
                icon: "shuffle"
                tonal: false
                active: win.p?.shuffle ?? false
                onClicked: win.p.shuffle = !win.p.shuffle
            }
            IconBtn {
                icon: "skip_previous"
                size: 48
                iconSize: 24
                onClicked: Media.previous()
            }
            Rectangle {
                implicitWidth: 72
                implicitHeight: 56
                radius: Media.playing ? Theme.rCard : height / 2
                color: Theme.primary
                Behavior on radius { Spring { baseSpring: 4; baseDamping: 0.45 } }
                Icon {
                    anchors.centerIn: parent
                    icon: Media.playing ? "pause" : "play_arrow"
                    size: 28
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
                size: 48
                iconSize: 24
                onClicked: Media.next()
            }
            IconBtn {
                visible: win.p?.loopSupported ?? false
                icon: win.p?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                tonal: false
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
                delegate: Chip {
                    required property var modelData
                    Layout.fillWidth: true
                    small: true
                    text: modelData.identity
                    selected: modelData === Media.active
                    onClicked: Media.last = modelData
                }
            }
        }
    }
}

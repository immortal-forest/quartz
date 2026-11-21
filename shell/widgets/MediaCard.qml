import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../core"
import "../services"

// Compact now-playing card (control centre): the cover tints the card.
ClippingRectangle {
    id: root
    implicitHeight: 88
    radius: 20
    color: Theme.card

    property real pos: 0
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.visible && Media.playing
        onTriggered: root.pos = Media.active?.position ?? 0
    }
    Connections {
        target: Media.active
        function onPositionChanged() { root.pos = Media.active.position; }
    }

    Image {
        anchors.fill: parent
        source: Media.art
        sourceSize: Qt.size(64, 64)
        fillMode: Image.PreserveAspectCrop
        opacity: 0.28
        asynchronous: true
        smooth: true
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.alpha(Theme.surfaceHigh, 0.35) }
            GradientStop { position: 1; color: Theme.alpha(Theme.surfaceHigh, 0.85) }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12
        ClippingRectangle {
            Layout.preferredWidth: 60
            Layout.preferredHeight: 60
            radius: 14
            color: Theme.surfaceHighest
            Image {
                anchors.fill: parent
                source: Media.art
                sourceSize: Qt.size(120, 120)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Icon {
                anchors.centerIn: parent
                visible: !Media.art.length
                icon: "music_note"
                size: 26
                color: Theme.textDim
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            T {
                Layout.fillWidth: true
                text: Media.title
                font.weight: Font.DemiBold
            }
            T {
                Layout.fillWidth: true
                text: Media.artist || (Media.active?.identity ?? "")
                font.pixelSize: Theme.fsSmall
                color: Theme.textDim
            }
            Item { implicitHeight: 6 }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 4
                radius: 2
                color: Theme.alpha(Theme.text, 0.12)
                visible: (Media.active?.length ?? 0) > 0
                Rectangle {
                    height: parent.height
                    radius: 2
                    width: parent.width * Math.max(0, Math.min(1, root.pos / (Media.active?.length || 1)))
                    color: Theme.primary
                    Behavior on width { Ease { duration: 900; easing.bezierCurve: Anim.standard } }
                }
            }
        }
        IconBtn {
            icon: "skip_previous"
            size: 32
            onClicked: Media.previous()
        }
        IconBtn {
            icon: Media.playing ? "pause" : "play_arrow"
            size: 40
            iconSize: 22
            active: true
            onClicked: Media.toggle()
        }
        IconBtn {
            icon: "skip_next"
            size: 32
            onClicked: Media.next()
        }
    }
}

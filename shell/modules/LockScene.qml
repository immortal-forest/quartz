import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import "../core"
import "../services"
import "../widgets"
import "../bar"

// The lock screen's look (used by LockSurface; separate so it can be previewed
// without locking the session).
Item {
    id: surf
    required property var ctx

    readonly property bool live: !ctx.unlocking
    property bool entered: false
    Component.onCompleted: enterTimer.start()
    Timer {
        id: enterTimer
        interval: 30
        onTriggered: surf.entered = true
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Item {
        id: scene
        anchors.fill: parent
        opacity: surf.entered && surf.live ? 1 : 0
        Behavior on opacity { Ease { duration: surf.live ? Anim.slower : 340 } }

        Image {
            id: wall
            anchors.fill: parent
            source: Config.opt.wallpaper.length ? "file://" + Config.opt.wallpaper : ""
            sourceSize: Qt.size(Math.round(parent.width / 2), Math.round(parent.height / 2))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: wall
            blurEnabled: true
            blurMax: 64
            blur: 1
            saturation: 0.1
            brightness: -0.08
            scale: surf.entered ? 1 : 1.08
            Behavior on scale { Ease { duration: 900; easing.bezierCurve: Anim.decel } }
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.alpha(Theme.surface, 0.25) }
                GradientStop { position: 0.6; color: Theme.alpha(Theme.surface, 0.35) }
                GradientStop { position: 1; color: Theme.alpha(Theme.surface, 0.75) }
            }
        }

        // clock
        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.22 + (surf.entered ? 0 : 40)
            spacing: 0
            Behavior on y { Ease { duration: 900; easing.bezierCurve: Anim.decel } }
            T {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(clock.date, Config.opt.use24h ? "HH:mm" : "h:mm")
                font.family: Theme.display
                font.pixelSize: 150
                font.weight: Font.Light
                font.features: { "tnum": 1 }
                color: Theme.text
            }
            T {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: -12
                text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                font.pixelSize: 22
                font.weight: Font.Medium
                color: Theme.alpha(Theme.text, 0.85)
            }
        }

        // now playing
        Rectangle {
            visible: Media.hasTrack && Config.opt.lockMedia
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.56
            width: 360
            height: 64
            radius: 32
            color: Theme.alpha(Theme.surfaceHigh, 0.55)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 10
                spacing: 10
                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    radius: 24
                    color: Theme.surfaceHighest
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: Media.art
                        sourceSize: Qt.size(96, 96)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: artMask
                        }
                    }
                    Rectangle {
                        id: artMask
                        anchors.fill: parent
                        radius: 24
                        visible: false
                        layer.enabled: true
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    T { Layout.fillWidth: true; text: Media.title; font.weight: Font.DemiBold }
                    T { Layout.fillWidth: true; text: Media.artist; font.pixelSize: Theme.fsSmall; color: Theme.textDim }
                }
                IconBtn { icon: "skip_previous"; size: 32; onClicked: Media.previous() }
                IconBtn { icon: Media.playing ? "pause" : "play_arrow"; size: 38; active: true; onClicked: Media.toggle() }
                IconBtn { icon: "skip_next"; size: 32; onClicked: Media.next() }
            }
        }

        // password
        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.10 - (surf.entered ? 0 : 30)
            spacing: 12
            Behavior on anchors.bottomMargin { Ease { duration: 900; easing.bezierCurve: Anim.decel } }

            Rectangle {
                id: field
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 320
                implicitHeight: 54
                radius: 27
                color: Theme.alpha(Theme.surfaceHigh, 0.70)
                border.width: input.activeFocus ? 2 : 1
                border.color: surf.ctx.error.length ? Theme.error : input.activeFocus ? Theme.primary : Theme.hairline
                Behavior on border.color { CAnim {} }

                property real shake: 0
                transform: Translate { x: field.shake }
                SequentialAnimation {
                    id: shakeAnim
                    NumberAnimation { target: field; property: "shake"; to: -14; duration: 50 }
                    NumberAnimation { target: field; property: "shake"; to: 12; duration: 70 }
                    NumberAnimation { target: field; property: "shake"; to: -8; duration: 70 }
                    NumberAnimation { target: field; property: "shake"; to: 5; duration: 70 }
                    NumberAnimation { target: field; property: "shake"; to: 0; duration: 80 }
                }
                Connections {
                    target: surf.ctx
                    function onFailed() {
                        shakeAnim.restart();
                        input.text = "";
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 8
                    spacing: 10
                    Icon {
                        icon: surf.ctx.busy ? "hourglass_top" : "lock"
                        size: 19
                        fill: 1
                        color: Theme.textDim
                    }
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 24
                        TextInput {
                            id: input
                            anchors.fill: parent
                            focus: true
                            opacity: 0
                            echoMode: TextInput.Password
                            enabled: !surf.ctx.busy
                            text: surf.ctx.password
                            onTextChanged: { if (surf.ctx.password !== text) surf.ctx.password = text; if (text.length) surf.ctx.error = ""; }
                            onAccepted: surf.ctx.submit()
                            Component.onCompleted: forceActiveFocus()
                        }
                        // dots that pop in as you type
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Repeater {
                                // constant model: an int model that changed per keystroke
                                // would rebuild every dot (and re-pop them all)
                                model: 22
                                delegate: Rectangle {
                                    required property int index
                                    visible: index < surf.ctx.password.length
                                    width: 9
                                    height: 9
                                    radius: 5
                                    color: Theme.text
                                    scale: visible ? 1 : 0
                                    Behavior on scale { Spring { baseSpring: 5; baseDamping: 0.4; epsilon: 0.01 } }
                                }
                            }
                        }
                        T {
                            visible: !surf.ctx.password.length
                            anchors.verticalCenter: parent.verticalCenter
                            text: surf.ctx.busy ? "Checking…" : "Enter password"
                            color: Theme.textDim
                        }
                    }
                    Rectangle {
                        implicitWidth: 40
                        implicitHeight: 40
                        radius: 20
                        color: surf.ctx.password.length ? Theme.primary : Theme.alpha(Theme.text, 0.08)
                        Behavior on color { CAnim {} }
                        Icon {
                            anchors.centerIn: parent
                            icon: "arrow_forward"
                            size: 20
                            color: surf.ctx.password.length ? Theme.primaryText : Theme.textDim
                        }
                        StateLayer { onClicked: surf.ctx.submit() }
                    }
                }
            }
            T {
                Layout.alignment: Qt.AlignHCenter
                text: surf.ctx.error.length ? surf.ctx.error : (Quickshell.env("USER") ?? "")
                color: surf.ctx.error.length ? Theme.error : Theme.textDim
                font.weight: Font.Medium
            }
        }

        // corner status
        RowLayout {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 24
            spacing: 14
            Icon { icon: Net.icon; size: 18; fill: 1; color: Theme.text }
            Battery {}
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: input.forceActiveFocus()
    }
}

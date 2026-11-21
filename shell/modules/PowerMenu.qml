import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../core"
import "../widgets"

// Session menu over a frosted desktop. Arrows / Tab + Enter, or click.
OverlayWin {
    id: win
    name: "power"
    dim: 0.40
    ns: "quartz-frost"

    property int sel: 0
    readonly property var items: [
        { icon: "lock", label: "Lock", run: () => Quickshell.execDetached(["loginctl", "lock-session"]) },
        { icon: "bedtime", label: "Sleep", run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
        { icon: "logout", label: "Log out", run: () => Hypr.exit() },
        { icon: "restart_alt", label: "Restart", run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
        { icon: "power_settings_new", label: "Shut down", run: () => Quickshell.execDetached(["systemctl", "poweroff"]) }
    ]
    function go(i) {
        const it = items[i];
        Ui.overlay = "";
        it.run();
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.pad * 2
        focus: true
        Keys.onLeftPressed: win.sel = (win.sel + win.items.length - 1) % win.items.length
        Keys.onRightPressed: win.sel = (win.sel + 1) % win.items.length
        Keys.onTabPressed: win.sel = (win.sel + 1) % win.items.length
        Keys.onReturnPressed: win.go(win.sel)
        Keys.onEnterPressed: win.go(win.sel)
        Component.onCompleted: forceActiveFocus()

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 2
            T {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(clock.date, Config.opt.use24h ? "HH:mm" : "h:mm")
                font.family: Theme.display
                font.pixelSize: 72
                font.weight: Font.Light
                color: "white"
            }
            T {
                Layout.alignment: Qt.AlignHCenter
                text: "Goodbye for now, " + (Quickshell.env("USER") ?? "")
                font.pixelSize: Theme.fsTitle
                color: Theme.alpha("white", 0.85)
            }
        }

        // five equal tiles, one gap; the icon + label block sits on the
        // tile's centre with a fixed gap between them
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.pad
            Repeater {
                model: win.items
                delegate: Rectangle {
                    id: b
                    required property var modelData
                    required property int index
                    readonly property bool on: win.sel === index
                    readonly property color ink: on ? Theme.primaryText : Theme.text
                    implicitWidth: 112
                    implicitHeight: 120
                    radius: on ? 40 : Theme.rSurface
                    color: on ? (index === 4 ? Theme.error : Theme.primary) : Theme.glassStrong
                    border.width: 1
                    border.color: Theme.hairline
                    scale: ma.pressed ? 0.94 : on ? 1.04 : 1
                    Behavior on radius { Spring { baseSpring: 4; baseDamping: 0.45 } }
                    Behavior on scale { Spring { baseSpring: 4; baseDamping: 0.42; epsilon: 0.003 } }
                    Behavior on color { CAnim {} }

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacing
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 32
                            height: 32
                            icon: b.modelData.icon
                            size: 32
                            fill: b.on ? 1 : 0
                            color: b.ink
                        }
                        T {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: b.modelData.label
                            font.weight: Font.DemiBold
                            color: b.ink
                        }
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: win.sel = b.index
                        onClicked: win.go(b.index)
                    }
                }
            }
        }
        KeyHint {
            Layout.alignment: Qt.AlignHCenter
            light: true
            hints: [
                { keys: ["keyboard_arrow_left", "keyboard_arrow_right"], label: "Choose" },
                { keys: ["keyboard_return"], label: "Confirm" },
                { keys: ["Esc"], label: "Cancel" }
            ]
        }
    }
}

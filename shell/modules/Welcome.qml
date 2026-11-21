import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../widgets"

// First-run guide: the handful of keys that get you around, shown once (and
// again from Settings › General). Esc / Get started closes it.
OverlayWin {
    id: win
    name: "welcome"
    dim: 0.5
    Component.onCompleted: Config.opt.welcomed = true

    readonly property var tips: [
        { icon: "apps", title: "Open an app", keys: ["Super", "Space"], text: "Type its name. A sum works too: the answer is copied." },
        { icon: "tune", title: "Control centre", keys: ["Super", "A"], text: "Volume, brightness, Wi-Fi, Bluetooth and your notifications." },
        { icon: "keyboard", title: "Every shortcut", keys: ["Super", "/"], text: "Search what you want to do, like “wallpaper” or “screenshot”." },
        { icon: "settings", title: "Settings", keys: ["Super", ","], text: "Light or dark, text size, the bar, sounds, wallpapers." },
        { icon: "wallpaper", title: "Wallpapers", keys: ["Super", "C"], text: "Pick one and the whole desktop takes its colours." },
        { icon: "power_settings_new", title: "Lock or shut down", keys: ["Super", "Esc"], text: "Lock, sleep, log out, restart or power off." }
    ]

    Card {
        anchors.centerIn: parent
        width: Math.min(parent.width - 96, 760)
        height: col.implicitHeight + Theme.pad * 2 + 8
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: col
            x: Theme.pad + 8
            y: Theme.pad + 8
            width: parent.width - (Theme.pad + 8) * 2
            spacing: Theme.pad

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                T {
                    text: "Welcome to quartz"
                    font.pixelSize: Theme.fsLarge + 4
                    font.weight: Font.Medium
                }
                T {
                    Layout.fillWidth: true
                    text: "Six keys get you everywhere. Everything in the bar is clickable too: the clock opens the calendar, the icons on the right open the control centre."
                    color: Theme.textDim
                    wrapMode: Text.Wrap
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Theme.spacing
                rowSpacing: Theme.spacing
                uniformCellWidths: true
                Repeater {
                    model: win.tips
                    delegate: Rectangle {
                        id: tip
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: tipCol.implicitHeight + Theme.padCard * 2
                        radius: Theme.rCard
                        color: Theme.card
                        RowLayout {
                            id: tipCol
                            x: Theme.padCard
                            y: Theme.padCard
                            width: parent.width - Theme.padCard * 2
                            spacing: 12
                            Rectangle {
                                Layout.alignment: Qt.AlignTop
                                implicitWidth: Theme.ctl
                                implicitHeight: Theme.ctl
                                radius: Theme.pill(height)
                                color: Theme.alpha(Theme.primary, 0.16)
                                Icon { anchors.centerIn: parent; icon: tip.modelData.icon; color: Theme.primary }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    T {
                                        Layout.fillWidth: true
                                        text: tip.modelData.title
                                        font.weight: Font.DemiBold
                                    }
                                    Repeater {
                                        model: tip.modelData.keys
                                        delegate: Keycap {
                                            required property string modelData
                                            key: modelData
                                        }
                                    }
                                }
                                T {
                                    Layout.fillWidth: true
                                    text: tip.modelData.text
                                    font.pixelSize: Theme.fsSmall
                                    color: Theme.textDim
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing
                T {
                    Layout.fillWidth: true
                    text: "You can open this again from Settings › General."
                    font.pixelSize: Theme.fsSmall
                    color: Theme.textDim
                }
                Button {
                    filled: false
                    icon: "settings"
                    text: "Open settings"
                    onClicked: Ui.openSettings("general")
                }
                Button {
                    icon: "check"
                    text: "Get started"
                    onClicked: Ui.overlay = ""
                }
            }
        }
    }
}

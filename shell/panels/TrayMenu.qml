import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../core"
import "../widgets"

// A tray app's menu, drawn in quartz's style. Submenus open in place with a back row.
PanelWin {
    id: win
    name: "tray"
    side: "left"
    cardWidth: 260
    leftOffset: Math.max(Theme.gap, Math.min((scr?.width ?? 1600) - cardWidth - Theme.gap, Ui.trayX - cardWidth / 2))
    contentHeight: col.implicitHeight + 12

    property var stack: []
    readonly property var menu: stack.length ? stack[stack.length - 1] : (Ui.trayItem?.menu ?? null)

    QsMenuOpener {
        id: opener
        menu: win.menu
    }

    ColumnLayout {
        id: col
        x: 6
        y: 6
        width: parent.width - 12
        spacing: 0

        Rectangle {
            visible: win.stack.length > 0
            Layout.fillWidth: true
            implicitHeight: 34
            radius: 10
            color: "transparent"
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                spacing: 8
                Icon { icon: "arrow_back"; size: 16 }
                T { text: "Back"; font.weight: Font.Medium }
            }
            StateLayer { onClicked: win.stack = win.stack.slice(0, -1) }
        }

        Repeater {
            model: opener.children
            delegate: Item {
                id: row
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: modelData.isSeparator ? 9 : 34

                Rectangle {
                    visible: row.modelData.isSeparator
                    anchors.centerIn: parent
                    width: parent.width - 16
                    height: 1
                    color: Theme.hairline
                }
                Rectangle {
                    visible: !row.modelData.isSeparator
                    anchors.fill: parent
                    radius: 10
                    color: "transparent"
                    opacity: row.modelData.enabled ? 1 : 0.4
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 10
                        Icon {
                            visible: row.modelData.buttonType !== QsMenuButtonType.None
                            icon: row.modelData.buttonType === QsMenuButtonType.RadioButton
                                ? (row.modelData.checkState === Qt.Checked ? "radio_button_checked" : "radio_button_unchecked")
                                : (row.modelData.checkState === Qt.Checked ? "check_box" : "check_box_outline_blank")
                            fill: row.modelData.checkState === Qt.Checked ? 1 : 0
                            size: 17
                            color: row.modelData.checkState === Qt.Checked ? Theme.primary : Theme.textDim
                        }
                        IconImage {
                            visible: row.modelData.icon.length > 0 && row.modelData.buttonType === QsMenuButtonType.None
                            implicitSize: 16
                            source: row.modelData.icon
                            asynchronous: true
                        }
                        T {
                            Layout.fillWidth: true
                            text: row.modelData.text.replace(/_(?!_)/g, "")
                        }
                        Icon {
                            visible: row.modelData.hasChildren
                            icon: "chevron_right"
                            size: 16
                            color: Theme.textDim
                        }
                    }
                    StateLayer {
                        enabled: row.modelData.enabled
                        onClicked: {
                            if (row.modelData.hasChildren) {
                                win.stack = win.stack.concat([row.modelData]);
                            } else {
                                row.modelData.triggered();
                                Ui.panel = "";
                            }
                        }
                    }
                }
            }
        }
    }
}

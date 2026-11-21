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
    cardWidth: 280
    anchorX: Ui.trayX
    contentHeight: col.implicitHeight + Theme.spacing * 2

    property var stack: []
    readonly property var menu: stack.length ? stack[stack.length - 1] : (Ui.trayItem?.menu ?? null)

    QsMenuOpener {
        id: opener
        menu: win.menu
    }

    ColumnLayout {
        id: col
        x: Theme.spacing
        y: Theme.spacing
        width: parent.width - Theme.spacing * 2
        spacing: 0

        Rectangle {
            visible: win.stack.length > 0
            Layout.fillWidth: true
            implicitHeight: Theme.ctl
            radius: Theme.rThumb
            color: "transparent"
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                spacing: 12
                Icon { icon: "arrow_back"; size: 18 }
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
                implicitHeight: modelData.isSeparator ? 9 : Theme.ctl

                Rectangle {
                    visible: row.modelData.isSeparator
                    anchors.centerIn: parent
                    width: parent.width - 24
                    height: 1
                    color: Theme.hairline
                }
                Rectangle {
                    visible: !row.modelData.isSeparator
                    anchors.fill: parent
                    radius: Theme.rThumb
                    color: "transparent"
                    opacity: row.modelData.enabled ? 1 : 0.4
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 12
                        Icon {
                            visible: row.modelData.buttonType !== QsMenuButtonType.None
                            icon: row.modelData.buttonType === QsMenuButtonType.RadioButton
                                ? (row.modelData.checkState === Qt.Checked ? "radio_button_checked" : "radio_button_unchecked")
                                : (row.modelData.checkState === Qt.Checked ? "check_box" : "check_box_outline_blank")
                            fill: row.modelData.checkState === Qt.Checked ? 1 : 0
                            size: 18
                            color: row.modelData.checkState === Qt.Checked ? Theme.primary : Theme.textDim
                        }
                        IconImage {
                            visible: row.modelData.icon.length > 0 && row.modelData.buttonType === QsMenuButtonType.None
                            implicitSize: 18
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
                            size: 18
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

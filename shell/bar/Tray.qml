import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "../core"
import "../widgets"

// System tray. Left = activate (or menu), right = menu, middle = secondary.
RowLayout {
    id: root
    property string screenName: ""
    spacing: 0
    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items
        delegate: Rectangle {
            id: cell
            required property SystemTrayItem modelData
            readonly property bool menuOpen: Ui.panel === "tray" && Ui.trayItem === modelData && Ui.screen === root.screenName
            implicitWidth: 28
            implicitHeight: 28
            radius: 9
            color: menuOpen ? Theme.alpha(Theme.primary, 0.16) : "transparent"

            function openMenu() {
                if (!modelData.hasMenu)
                    return;
                Ui.trayItem = modelData;
                Ui.trayX = cell.mapToItem(null, cell.width / 2, 0).x;
                Ui.togglePanel("tray", root.screenName);
            }

            IconImage {
                anchors.centerIn: parent
                implicitSize: 16
                source: cell.modelData.icon
                asynchronous: true
            }
            StateLayer {
                onClicked: m => {
                    if (m.button === Qt.RightButton || (m.button === Qt.LeftButton && cell.modelData.onlyMenu))
                        cell.openMenu();
                    else if (m.button === Qt.MiddleButton)
                        cell.modelData.secondaryActivate();
                    else
                        cell.modelData.activate();
                }
                onWheel: w => cell.modelData.scroll(w.angleDelta.y, false)
            }
        }
    }
}

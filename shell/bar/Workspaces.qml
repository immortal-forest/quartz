import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../core"
import "../widgets"

// Dots for workspaces; the active one stretches into a pill. On a single
// monitor slots 1..max(5, highest) are always shown; with several monitors,
// each bar shows the workspaces living on its monitor.
Item {
    id: root
    property var monitor: null
    readonly property var mine: Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor === root.monitor)
    readonly property bool single: Hyprland.monitors.values.length <= 1
    readonly property var ids: {
        const have = mine.map(w => w.id).sort((a, b) => a - b);
        if (!single)
            return have;
        const n = Math.max(5, have.length ? have[have.length - 1] : 0);
        const out = [];
        for (let i = 1; i <= n; i++)
            out.push(i);
        return out;
    }
    readonly property int activeId: monitor?.activeWorkspace?.id ?? -1
    readonly property bool numbers: Config.opt.workspaceNumbers

    function wsFor(id) { return mine.find(w => w.id === id) ?? null; }
    function go(target) { Hypr.workspace(target); }

    implicitWidth: row.implicitWidth + 20
    implicitHeight: 28

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: root.numbers ? 4 : 6
        Repeater {
            // An int model: delegates are only rebuilt when the slot COUNT changes,
            // so switching workspaces animates instead of rebuilding the row.
            model: root.ids.length
            delegate: Rectangle {
                id: dot
                required property int index
                readonly property int wsId: root.ids[index] ?? 0
                readonly property var ws: root.wsFor(wsId)
                readonly property bool active: wsId === root.activeId
                readonly property bool occupied: (ws?.toplevels?.values?.length ?? 0) > 0
                readonly property bool urgent: ws?.urgent ?? false

                implicitWidth: root.numbers ? (active ? 30 : 20) : (active ? 24 : 8)
                implicitHeight: root.numbers ? 20 : 8
                radius: height / 2
                color: active ? Theme.primary : urgent ? Theme.error : occupied ? Theme.alpha(Theme.text, 0.55) : Theme.alpha(Theme.text, 0.20)
                Behavior on implicitWidth { Spring { spring: 4.2; damping: 0.5 } }
                Behavior on color { CAnim {} }

                T {
                    anchors.centerIn: parent
                    visible: root.numbers
                    text: dot.wsId
                    font.pixelSize: Theme.fsSmall
                    font.weight: dot.active ? Font.Bold : Font.Medium
                    color: dot.active ? Theme.primaryText : dot.occupied ? Theme.text : Theme.textDim
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -5
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.go(dot.wsId)
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        property double last: 0
        onWheel: w => {
            if (Date.now() - last < 120)
                return;
            last = Date.now();
            root.go(w.angleDelta.y > 0 ? "r-1" : "r+1");
        }
    }
}

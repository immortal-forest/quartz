import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import "../core"
import "../widgets"

// App icon + title of the focused window, when it's on this bar's monitor.
Item {
    id: root
    property var monitor: null
    readonly property var tl: Hyprland.activeToplevel
    readonly property bool here: !!tl && tl.activated !== false && (!tl.workspace || tl.workspace.id === root.monitor?.activeWorkspace?.id)
    readonly property string appId: tl?.wayland?.appId ?? ""
    readonly property var entry: appId.length ? DesktopEntries.heuristicLookup(appId) : null
    readonly property string title: tl?.title ?? ""

    implicitHeight: 28
    implicitWidth: here ? row.implicitWidth + 8 : 0
    opacity: here ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { Ease {} }

    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, root.width)
        spacing: 8
        AppIcon {
            size: 16
            name: (root.entry?.icon ?? "") || root.appId
            glyph: "web_asset"
        }
        T {
            Layout.fillWidth: true
            Layout.maximumWidth: root.width - 30
            text: root.title.length ? root.title : (root.entry?.name ?? root.appId)
            color: Theme.textDim
            font.weight: Font.Medium
        }
    }
}

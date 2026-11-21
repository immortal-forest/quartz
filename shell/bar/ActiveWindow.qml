import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../core"
import "../widgets"

// App icon + title of the focused window, when it's on this bar's monitor.
// Width = what the content needs, capped at `maxWidth` (set by the bar: up to
// the clock's gap); the title elides only past that. Plain positioning, no
// layout, and the natural width comes from an unconstrained twin of the label,
// so it never depends on the width the label is given.
Item {
    id: root
    property var monitor: null
    property real maxWidth: Infinity
    readonly property var tl: Hyprland.activeToplevel
    readonly property bool here: !!tl && tl.activated !== false && (!tl.workspace || tl.workspace.id === root.monitor?.activeWorkspace?.id)
    readonly property string appId: tl?.wayland?.appId ?? ""
    readonly property var entry: appId.length ? DesktopEntries.heuristicLookup(appId) : null
    // terminals lead the title with a spinner / status glyph (◐ ✳ ⠋ …); beside
    // the app's icon it would read as a second, broken icon
    readonly property string title: (tl?.title ?? "").replace(/^[\s←-⯿⠀-⣿]+/, "")

    // the icon sits in a barItem-square cell, like a tray icon
    readonly property real padL: (Theme.barItem - Theme.iconBar) / 2
    readonly property real lead: padL + Theme.iconBar + Theme.spacing
    readonly property bool fits: maxWidth >= lead + Theme.barItem

    implicitHeight: Theme.barItem
    implicitWidth: fits && Config.opt.barTitle ? Math.min(lead + measure.implicitWidth, maxWidth) : 0
    opacity: here && fits && Config.opt.barTitle ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { Ease {} }

    AppIcon {
        x: root.padL
        anchors.verticalCenter: parent.verticalCenter
        size: Theme.iconBar
        name: (root.entry?.icon ?? "") || root.appId
        glyph: "web_asset"
    }
    T {
        id: label
        x: root.lead
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, root.implicitWidth - root.lead)
        text: root.title.length ? root.title : (root.entry?.name ?? root.appId)
        color: Theme.textDim
        font.weight: Font.Medium
    }
    T {
        id: measure
        visible: false
        elide: Text.ElideNone
        text: label.text
        font: label.font
    }
}

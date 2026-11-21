import QtQuick
import Quickshell
import Quickshell.Widgets
import "../core"

// An app / theme icon that never shows Qt's magenta "missing" square: names the
// icon theme doesn't have fall back to a Material glyph on a soft tile.
Item {
    id: root
    property string name: ""        // theme icon name, absolute path or URL
    property real size: 24
    property string glyph: "apps"
    readonly property string src: {
        const n = root.name || "";
        if (!n.length)
            return "";
        if (n.startsWith("/"))
            return "file://" + n;
        if (n.startsWith("image://icon/"))
            return Quickshell.iconPath(n.substring(13).split("?")[0], true);
        if (n.indexOf("://") > 0)
            return n;
        return Quickshell.iconPath(n, true) || Quickshell.iconPath(n.toLowerCase(), true);
    }
    implicitWidth: size
    implicitHeight: size

    IconImage {
        anchors.fill: parent
        visible: root.src.length > 0
        source: root.src
        asynchronous: true
    }
    Rectangle {
        anchors.fill: parent
        visible: !root.src.length
        radius: root.size * 0.28
        color: Theme.alpha(Theme.primary, 0.16)
        Icon {
            anchors.centerIn: parent
            icon: root.glyph
            size: root.size * 0.62
            fill: 1
            color: Theme.primary
        }
    }
}

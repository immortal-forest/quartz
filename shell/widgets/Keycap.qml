import QtQuick
import "../core"

// One key: a small raised cap holding a key name ("Super", "C") or icons
// ("arrows", "arrows-h", "icon:<glyph>") — never text characters as icons.
Rectangle {
    id: root
    property string key: ""
    readonly property var glyphs: key === "arrows" ? ["keyboard_arrow_left", "keyboard_arrow_up", "keyboard_arrow_down", "keyboard_arrow_right"]
        : key === "arrows-h" ? ["keyboard_arrow_left", "keyboard_arrow_right"]
        : key.startsWith("icon:") ? [key.substring(5)] : []

    implicitHeight: 26
    implicitWidth: Math.max(height + 4, (glyphs.length ? icons.implicitWidth : label.implicitWidth) + 16)
    radius: 7
    color: Theme.tonal
    border.width: 1
    border.color: Theme.hairline

    Row {
        id: icons
        visible: root.glyphs.length > 0
        anchors.centerIn: parent
        spacing: 0
        Repeater {
            model: root.glyphs
            delegate: Icon {
                required property string modelData
                icon: modelData
                size: 16
                color: Theme.text
            }
        }
    }
    T {
        id: label
        visible: !root.glyphs.length
        anchors.centerIn: parent
        text: root.key
        font.pixelSize: Theme.fsSmall
        font.weight: Font.DemiBold
        color: Theme.text
    }
}

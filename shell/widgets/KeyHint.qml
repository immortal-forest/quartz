import QtQuick
import "../core"

// Keyboard hints for overlay footers: each hint is one or more keycaps and
// what they do. A key is a Material Symbols glyph when it has a "_" or is in
// `glyphs` ("keyboard_return", "keyboard_arrow_up", "mouse"…), otherwise its
// name is printed on the cap ("Esc", "Del", "Shift").
//   KeyHint { hints: [{ keys: ["keyboard_return"], label: "Open" }, { keys: ["Esc"], label: "Close" }] }
// `light` = white ink for a dark backdrop that isn't a themed surface (power menu).
Row {
    id: root
    property var hints: []
    property bool light: false
    readonly property var glyphs: ["backspace", "mouse", "space_bar"]
    readonly property int cap: 22
    readonly property color capFill: light ? Theme.alpha("white", 0.16) : Theme.tonal
    readonly property color capEdge: light ? Theme.alpha("white", 0.14) : Theme.hairline
    readonly property color capInk: light ? "white" : Theme.text
    readonly property color labelInk: light ? Theme.alpha("white", 0.82) : Theme.textDim

    spacing: Theme.pad

    Repeater {
        model: root.hints
        delegate: Row {
            id: hint
            required property var modelData
            spacing: 6

            Row {
                spacing: 4
                Repeater {
                    model: hint.modelData.keys
                    delegate: Rectangle {
                        id: key
                        required property string modelData
                        readonly property bool glyph: modelData.indexOf("_") >= 0 || root.glyphs.indexOf(modelData) >= 0
                        width: glyph ? root.cap : Math.max(root.cap, name.implicitWidth + 12)
                        height: root.cap
                        radius: Math.round(root.cap / 4)
                        color: root.capFill
                        border.width: 1
                        border.color: root.capEdge
                        Icon {
                            visible: key.glyph
                            anchors.fill: parent
                            icon: key.glyph ? key.modelData : ""
                            size: 16
                            color: root.capInk
                        }
                        T {
                            id: name
                            visible: !key.glyph
                            anchors.centerIn: parent
                            text: key.glyph ? "" : key.modelData
                            font.pixelSize: Theme.fsSmall - 1
                            font.weight: Font.DemiBold
                            color: root.capInk
                        }
                    }
                }
            }
            T {
                height: root.cap
                text: hint.modelData.label
                font.pixelSize: Theme.fsSmall
                font.weight: Font.Medium
                color: root.labelInk
            }
        }
    }
}

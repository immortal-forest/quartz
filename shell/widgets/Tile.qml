import QtQuick
import QtQuick.Layouts
import "../core"

// Quick-settings tile (a pill): tap toggles, the chevron (when `more`) opens its page.
Rectangle {
    id: root
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool more: false
    signal toggled
    signal opened

    readonly property color fg: active ? Theme.primaryText : Theme.text
    readonly property real inset: (Theme.tile - Theme.ctlSmall) / 2
    implicitHeight: Theme.tile
    radius: Theme.pill(height)
    color: active ? Theme.primary : Theme.card
    Behavior on color { CAnim {} }

    scale: main.pressed || chev.pressed ? 0.97 : 1
    Behavior on scale { Spring { epsilon: 0.004; baseSpring: 4.5; baseDamping: 0.4 } }

    RowLayout {
        anchors.fill: parent
        // the icon's centre = the rounded end's centre (height / 2 in), mirroring the
        // chevron disc on the other end
        anchors.leftMargin: Math.round((Theme.tile - (Theme.icon + 2)) / 2)
        anchors.rightMargin: root.more ? root.inset : 16
        spacing: 10
        Icon {
            icon: root.icon
            size: Theme.icon + 2
            fill: root.active ? 1 : 0
            color: root.fg
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            T {
                Layout.fillWidth: true
                text: root.title
                font.weight: Font.DemiBold
                color: root.fg
            }
            T {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.subtitle
                font.pixelSize: Theme.fsSmall
                color: Theme.alpha(root.fg, 0.75)
            }
        }
        Item {
            visible: root.more
            Layout.preferredWidth: Theme.ctlSmall
            Layout.preferredHeight: Theme.ctlSmall
        }
    }
    StateLayer {
        id: main
        anchors.rightMargin: root.more ? Theme.ctlSmall + root.inset : 0
        radius: root.radius
        tint: root.fg
        onClicked: root.toggled()
    }
    Rectangle {
        visible: root.more
        anchors.right: parent.right
        anchors.rightMargin: root.inset
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.ctlSmall
        height: Theme.ctlSmall
        radius: Theme.pill(height)
        color: Theme.alpha(root.fg, 0.10)
        Icon {
            anchors.centerIn: parent
            icon: "chevron_right"
            size: 18
            color: root.fg
        }
        StateLayer {
            id: chev
            tint: root.fg
            onClicked: root.opened()
        }
    }
}

import QtQuick
import QtQuick.Layouts
import "../core"

// Quick-settings tile: tap toggles, the chevron (when `more`) opens its page.
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
    implicitHeight: 58
    radius: 20
    color: active ? Theme.primary : Theme.card
    Behavior on color { CAnim {} }

    scale: main.pressed || chev.pressed ? 0.97 : 1
    Behavior on scale { Spring { epsilon: 0.004; spring: 4.5; damping: 0.4 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: root.more ? 6 : 14
        spacing: 12
        Icon {
            icon: root.icon
            size: 21
            fill: root.active ? 1 : 0
            color: root.fg
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
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
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
        }
    }
    StateLayer {
        id: main
        anchors.rightMargin: root.more ? 44 : 0
        radius: root.radius
        tint: root.fg
        onClicked: root.toggled()
    }
    Rectangle {
        visible: root.more
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: 36
        radius: 18
        color: Theme.alpha(root.fg, 0.10)
        Icon {
            anchors.centerIn: parent
            icon: "chevron_right"
            size: 20
            color: root.fg
        }
        StateLayer {
            id: chev
            tint: root.fg
            onClicked: root.opened()
        }
    }
}

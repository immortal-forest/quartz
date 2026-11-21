import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import "../core"
import "../widgets"

// Drawn battery: body fills with charge, a bolt while charging, red when low.
RowLayout {
    id: root
    readonly property var dev: UPower.displayDevice
    readonly property bool present: (dev?.isLaptopBattery ?? false) && (dev?.isPresent ?? true)
    readonly property real pct: { const p = dev?.percentage ?? 0; return p > 1 ? p / 100 : p; }
    readonly property bool charging: dev?.state === UPowerDeviceState.Charging || (dev?.state === UPowerDeviceState.FullyCharged) || (!UPower.onBattery && dev?.state === UPowerDeviceState.PendingCharge)
    readonly property bool low: pct < 0.15 && !charging
    property bool showText: true
    visible: present
    spacing: 5

    Item {
        implicitWidth: 24
        implicitHeight: 12
        Rectangle {
            id: body
            width: 21
            height: 12
            radius: 3.5
            color: "transparent"
            border.width: 1.5
            border.color: Theme.alpha(Theme.text, 0.55)
            Rectangle {
                x: 2.5
                y: 2.5
                height: parent.height - 5
                width: Math.max(1.5, (parent.width - 5) * root.pct)
                radius: 1.5
                color: root.low ? Theme.error : root.charging ? Theme.primary : Theme.text
                Behavior on width { Ease { duration: Anim.slow } }
                Behavior on color { CAnim {} }
            }
        }
        Rectangle {
            x: 22
            anchors.verticalCenter: body.verticalCenter
            width: 2
            height: 5
            radius: 1
            color: Theme.alpha(Theme.text, 0.55)
        }
        Icon {
            anchors.centerIn: body
            visible: root.charging
            icon: "bolt"
            size: 13
            fill: 1
            color: root.pct > 0.55 ? Theme.primaryText : Theme.text
            style: Text.Outline
            styleColor: Theme.alpha(Theme.surface, 0.6)
        }
    }
    T {
        visible: root.showText
        text: Math.round(root.pct * 100) + "%"
        font.weight: Font.Medium
        font.features: { "tnum": 1 }
        color: root.low ? Theme.error : Theme.text
    }
}

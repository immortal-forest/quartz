import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import "../core"
import "../widgets"

// Battery: the Material battery glyph (same family as every other icon), with
// the bolt while charging and the alert frame when low.
RowLayout {
    id: root
    readonly property var dev: UPower.displayDevice
    readonly property bool present: (dev?.isLaptopBattery ?? false) && (dev?.isPresent ?? true)
    readonly property real pct: { const p = dev?.percentage ?? 0; return p > 1 ? p / 100 : p; }
    readonly property bool charging: dev?.state === UPowerDeviceState.Charging || (dev?.state === UPowerDeviceState.FullyCharged) || (!UPower.onBattery && dev?.state === UPowerDeviceState.PendingCharge)
    readonly property bool low: pct < 0.15 && !charging
    property bool showText: true
    property real size: Theme.iconBar + 2
    visible: present
    spacing: 5

    Icon {
        icon: root.charging ? "battery_android_frame_bolt"
            : root.low ? "battery_android_frame_alert"
            : root.pct >= 0.95 ? "battery_android_frame_full"
            : "battery_android_frame_" + Math.max(1, Math.min(6, Math.round(root.pct * 6)))
        size: root.size
        tight: true
        color: root.low ? Theme.error : Theme.text
    }
    T {
        visible: root.showText
        text: Math.round(root.pct * 100) + "%"
        font.weight: Font.Medium
        font.features: { "tnum": 1 }
        color: root.low ? Theme.error : Theme.text
    }
}

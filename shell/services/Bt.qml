pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

// quartz — Bluetooth (Quickshell.Bluetooth → BlueZ).
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool present: !!adapter
    readonly property bool on: adapter?.enabled ?? false
    readonly property var all: adapter ? adapter.devices.values : []
    readonly property var connected: all.filter(d => d.connected)
    readonly property var devices: all.filter(d => d.connected || d.paired || (d.name && d.name.length && d.name !== d.address.replace(/:/g, "-")))
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))

    readonly property string icon: !on ? "bluetooth_disabled" : connected.length ? "bluetooth_connected" : "bluetooth"
    readonly property string label: !on ? "Off" : connected.length === 1 ? connected[0].name : connected.length > 1 ? connected.length + " devices" : "On"

    function setOn(v) { if (adapter) adapter.enabled = v; }
    function scan(v) { if (adapter && adapter.enabled) adapter.discovering = v; }
    function deviceIcon(d) {
        const i = d?.icon ?? "";
        if (i.indexOf("headset") >= 0 || i.indexOf("headphone") >= 0) return "headphones";
        if (i.indexOf("audio") >= 0) return "speaker";
        if (i.indexOf("mouse") >= 0) return "mouse";
        if (i.indexOf("keyboard") >= 0) return "keyboard";
        if (i.indexOf("phone") >= 0) return "smartphone";
        if (i.indexOf("joystick") >= 0 || i.indexOf("gaming") >= 0) return "sports_esports";
        if (i.indexOf("watch") >= 0) return "watch";
        return "bluetooth";
    }
}

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking

// quartz — Wi-Fi / Ethernet state (Quickshell.Networking → NetworkManager).
Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired) ?? null
    readonly property bool wiredUp: (wired?.connected ?? false)
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property var rawNetworks: wifi ? wifi.networks.values : []
    readonly property var active: rawNetworks.find(n => n.connected) ?? null
    readonly property real strength: active ? norm(active.signalStrength) : 0

    // One row per SSID: connected first, then saved, then by signal.
    readonly property var networks: {
        const best = {};
        for (const n of rawNetworks) {
            if (!n.name || !n.name.length)
                continue;
            const cur = best[n.name];
            if (!cur || n.connected || (!cur.connected && norm(n.signalStrength) > norm(cur.signalStrength)))
                best[n.name] = n;
        }
        return Object.values(best).sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (norm(b.signalStrength) - norm(a.signalStrength)));
    }

    function norm(s) { return s > 1 ? s / 100 : s; }
    function secured(n) { return n && n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Unknown; }
    function bars(s) { return s > 0.75 ? "network_wifi" : s > 0.5 ? "network_wifi_3_bar" : s > 0.25 ? "network_wifi_2_bar" : "network_wifi_1_bar"; }

    readonly property string icon: wiredUp ? "lan" : !wifiOn ? "wifi_off" : active ? bars(strength) : "signal_wifi_statusbar_not_connected"
    readonly property string label: wiredUp ? "Ethernet" : !wifiOn ? "Off" : active ? active.name : "Not connected"

    function setWifi(on) { Networking.wifiEnabled = on; }
    function scan(on) { if (wifi) wifi.scannerEnabled = on; }
}

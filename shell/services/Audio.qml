pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../core"

// quartz — default output/input, devices and app streams (Pipewire).
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.audio && n.isStream && n.type === PwNodeType.AudioOutStream)

    // Fires on a real volume/mute change of the default sink or source (drives the OSD).
    signal changed(string kind)
    property bool armed: false

    readonly property string icon: (muted || volume <= 0.001) ? "volume_off" : volume < 0.34 ? "volume_mute" : volume < 0.67 ? "volume_down" : "volume_up"
    readonly property string micIcon: micMuted ? "mic_off" : "mic"

    function name(n) {
        if (!n)
            return "";
        return n.description || n.nickname || n.name || "";
    }
    // a short label for tight spots (tiles): what the device IS, not its chip
    function shortName(n) {
        if (!n)
            return "";
        const id = (n.name || "").toLowerCase(), d = name(n);
        if (id.indexOf("bluez") >= 0)
            return d;
        if (id.indexOf("hdmi") >= 0 || id.indexOf("displayport") >= 0)
            return "HDMI";
        if (id.indexOf("usb") >= 0)
            return d.replace(/ (Analog|Digital) (Stereo|Surround.*)$/i, "");
        if (id.indexOf("source") >= 0 || id.indexOf("input") >= 0)
            return "Built-in mic";
        return "Speakers";
    }
    function setVolume(v) {
        if (sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(1.5, v));
        }
    }
    function toggleMute() {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }
    function setMic(v) {
        if (source?.audio) {
            source.audio.muted = false;
            source.audio.volume = Math.max(0, Math.min(1.5, v));
        }
    }
    function toggleMic() {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }
    function useSink(n) { Pipewire.preferredDefaultAudioSink = n; }

    // Bluetooth headphones and speakers become the output when they connect
    // (Settings › Sound). WirePlumber only remembers the output you last picked
    // by hand, so without this a new headset, or one you used after choosing
    // the speakers, connects but stays silent. Only outputs that appear after
    // startup count: restarting the shell never moves the sound.
    signal switched(string device)
    property var seen: null   // sink ids already here; null until Pipewire settles
    onSinksChanged: {
        const now = {};
        for (const n of sinks) {
            now[n.id] = true;
            if (seen && !seen[n.id] && Config.opt.audioFollow && (n.name || "").startsWith("bluez_output"))
                followTimer.pending = n;
        }
        if (seen)
            seen = now;
        if (followTimer.pending)
            followTimer.restart();
    }
    Timer {
        id: settle
        interval: 2500
        running: Pipewire.ready
        onTriggered: {
            const now = {};
            for (const n of root.sinks)
                now[n.id] = true;
            root.seen = now;
        }
    }
    // a moment for the node to finish binding before WirePlumber is asked
    Timer {
        id: followTimer
        property var pending: null
        interval: 400
        onTriggered: {
            const n = pending;
            pending = null;
            if (n && root.sinks.indexOf(n) >= 0 && n !== root.sink) {
                root.useSink(n);
                root.switched(root.name(n));
            }
        }
    }
    function useSource(n) { Pipewire.preferredDefaultAudioSource = n; }

    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => !!n).concat(root.streams)
    }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { if (root.armed) root.changed("volume"); }
        function onMutedChanged() { if (root.armed) root.changed("volume"); }
    }
    Connections {
        target: root.source?.audio ?? null
        function onMutedChanged() { if (root.armed) root.changed("mic"); }
    }
    // Swallow the burst of change signals while nodes bind at startup / on device switch.
    onSinkChanged: { armed = false; armTimer.restart(); }
    onSourceChanged: { armed = false; armTimer.restart(); }
    Timer {
        id: armTimer
        interval: 1200
        running: true
        onTriggered: root.armed = true
    }
}

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

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

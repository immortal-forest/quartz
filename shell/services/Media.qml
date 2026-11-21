pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// quartz — the player the shell shows: the playing one, else the last one that played.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property MprisPlayer last: null
    readonly property MprisPlayer active: players.find(p => p.isPlaying) ?? (last && players.indexOf(last) >= 0 ? last : null) ?? players[0] ?? null
    onActiveChanged: if (active && active.isPlaying) last = active

    readonly property bool hasTrack: !!active && (active.trackTitle ?? "").length > 0
    readonly property bool playing: active?.isPlaying ?? false
    readonly property string title: active?.trackTitle ?? ""
    readonly property string artist: active?.trackArtist ?? ""
    readonly property string art: active?.trackArtUrl ?? ""

    function toggle() { if (active?.canTogglePlaying) active.togglePlaying(); }
    function next() { if (active?.canGoNext) active.next(); }
    function previous() { if (active?.canGoPrevious) active.previous(); }

    function fmt(s) {
        if (!isFinite(s) || s < 0)
            return "–:––";
        s = Math.floor(s);
        const m = Math.floor(s / 60), r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }
}

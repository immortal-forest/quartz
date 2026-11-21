pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../core"

// quartz — optional system features: night light (hyprsunset) and power mode
// (power-profiles-daemon). Each is detected once (and again when the settings
// window opens); nothing runs unless the feature is on.
Singleton {
    id: root

    property bool hasNightLight: false
    property bool hasPowerProfiles: false

    function check() { probe.running = true; }
    Component.onCompleted: check()

    Process {
        id: probe
        command: ["sh", "-c",
            "command -v hyprsunset >/dev/null && echo NIGHT; " +
            "for n in org.freedesktop.UPower.PowerProfiles net.hadess.PowerProfiles; do " +
            "busctl --system --no-pager status \"$n\" >/dev/null 2>&1 && { echo POWER; break; }; done; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.hasNightLight = text.indexOf("NIGHT") >= 0;
                root.hasPowerProfiles = text.indexOf("POWER") >= 0;
            }
        }
    }

    // ── night light: hyprsunset runs only while it's on; a new warmth restarts it
    readonly property bool nightOn: hasNightLight && Config.opt.nightLight
    Process {
        id: sunset
        command: ["hyprsunset", "-t", String(Math.max(1000, Math.min(6500, Config.opt.nightTemp)))]
        running: root.nightOn
    }
    Connections {
        target: Config.opt
        function onNightTempChanged() {
            if (root.nightOn)
                warmth.restart();
        }
    }
    Timer {
        id: warmth
        interval: 350
        onTriggered: {
            sunset.running = false;
            sunset.running = Qt.binding(() => root.nightOn);
        }
    }

    // ── power mode
    // PowerProfiles is only touched once the daemon is known to exist (touching
    // it otherwise makes Quickshell try to start a missing service)
    readonly property int profile: hasPowerProfiles ? PowerProfiles.profile : PowerProfile.Balanced
    readonly property bool hasPerformance: hasPowerProfiles && PowerProfiles.hasPerformanceProfile
    function setProfile(p) {
        if (hasPowerProfiles)
            PowerProfiles.profile = p;
    }
}

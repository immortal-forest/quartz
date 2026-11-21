pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// quartz — screen brightness via brightnessctl, as the REAL level (current /
// max, the number brightnessctl itself reports). It never goes below `floor`:
// some backlights (this laptop's nvidia_wmi_ec_backlight) switch the panel off
// near zero, and a perceptual curve (-e4) put that cliff at "27 %".
// External changes (hypridle dimming, other tools) arrive as backlight uevents.
Singleton {
    id: root

    property real value: 0.5
    property bool available: false
    readonly property real floor: 0.02
    property double lastSet: 0
    signal stepped

    readonly property string icon: value < 0.34 ? "brightness_low" : value < 0.67 ? "brightness_medium" : "brightness_high"

    function set(v) {
        v = Math.max(root.floor, Math.min(1, v));
        root.value = v;
        root.lastSet = Date.now();
        Quickshell.execDetached(["brightnessctl", "-q", "set", Math.round(v * 100) + "%"]);
    }
    function step(delta) {
        set(root.value + delta);
        root.stepped();
    }
    function refresh() { reader.running = true; }

    Process {
        id: reader
        command: ["brightnessctl", "-m"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",");
                if (f.length >= 5) {
                    root.available = true;
                    // Ignore echoes of our own writes while keys are held.
                    const cur = parseInt(f[2]), max = parseInt(f[4]);
                    if (Date.now() - root.lastSet > 600 && max > 0)
                        root.value = cur / max;
                }
            }
        }
    }

    Process {
        running: true
        command: ["setpriv", "--pdeathsig", "TERM", "--", "udevadm", "monitor", "--kernel", "--subsystem-match=backlight"]
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("change") >= 0)
                    debounce.restart();
            }
        }
    }
    Timer {
        id: debounce
        interval: 120
        onTriggered: reader.running = true
    }
}

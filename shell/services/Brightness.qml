pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// quartz — screen brightness via brightnessctl (perceptual -e4 scale, 0..1).
// External changes (hypridle dimming, other tools) arrive as backlight uevents.
Singleton {
    id: root

    property real value: 0.5
    property bool available: false
    property double lastSet: 0
    signal stepped

    readonly property string icon: value < 0.34 ? "brightness_low" : value < 0.67 ? "brightness_medium" : "brightness_high"

    function set(v) {
        v = Math.max(0.01, Math.min(1, v));
        root.value = v;
        root.lastSet = Date.now();
        Quickshell.execDetached(["brightnessctl", "-e4", "-n2", "-q", "set", Math.round(v * 100) + "%"]);
    }
    function step(delta) {
        set(root.value + delta);
        root.stepped();
    }
    function refresh() { reader.running = true; }

    Process {
        id: reader
        command: ["brightnessctl", "-e4", "-m"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",");
                if (f.length >= 4) {
                    root.available = true;
                    // Ignore echoes of our own writes while keys are held.
                    if (Date.now() - root.lastSet > 600)
                        root.value = parseInt(f[3]) / 100;
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

pragma Singleton
import QtQuick
import Quickshell

// quartz — motion tokens (M3). Springs for things that move, curves for fades.
Singleton {
    // Settings › Appearance › Motion: full 1, reduced 0.5, off 0 (near-instant)
    readonly property real k: Config.opt.motion >= 2 ? 1 : Config.opt.motion === 1 ? 0.5 : 0
    readonly property bool full: k >= 1
    readonly property int fast: Math.round(150 * k)
    readonly property int normal: Math.round(250 * k)
    readonly property int slow: Math.round(400 * k)
    readonly property int slower: Math.round(550 * k)

    readonly property var standard: [0.2, 0, 0, 1, 1, 1]
    readonly property var decel: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var accel: [0.3, 0, 0.8, 0.15, 1, 1]
    readonly property var emphasized: [0.05, 0, 0.133333, 0.06, 0.166666, 0.4, 0.208333, 0.82, 0.25, 1, 1, 1]
}

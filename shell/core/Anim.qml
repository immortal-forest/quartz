pragma Singleton
import QtQuick
import Quickshell

// quartz — motion tokens (M3). Springs for things that move, curves for fades.
Singleton {
    readonly property int fast: 150
    readonly property int normal: 250
    readonly property int slow: 400
    readonly property int slower: 550

    readonly property var standard: [0.2, 0, 0, 1, 1, 1]
    readonly property var decel: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var accel: [0.3, 0, 0.8, 0.15, 1, 1]
    readonly property var emphasized: [0.05, 0, 0.133333, 0.06, 0.166666, 0.4, 0.208333, 0.82, 0.25, 1, 1, 1]
}

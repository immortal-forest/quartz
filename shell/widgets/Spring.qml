import QtQuick

// Spatial spring (slight overshoot). Use epsilon ~0.005 for scale/opacity-scale values.
SpringAnimation {
    spring: 3.4
    damping: 0.34
    epsilon: 0.25
}

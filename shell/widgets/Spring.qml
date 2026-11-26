import QtQuick
import "../core"

// Spatial spring (slight overshoot). Set baseSpring / baseDamping; with reduced
// or no motion (Settings › Appearance) it turns into a quick, flat settle.
// Damping never goes below 0.5: a touch of overshoot, then it settles without
// the long wobble a looser spring trails.
// Use epsilon ~0.005 for scale/opacity-scale values.
SpringAnimation {
    property real baseSpring: 3.4
    property real baseDamping: 0.34
    spring: Anim.full ? baseSpring : Anim.k > 0 ? 12 : 60
    damping: Anim.full ? Math.max(baseDamping, 0.5) : 1
    epsilon: 0.25
}

import QtQuick
import "../core"

// Standard M3 curve; override `duration` / `easing.bezierCurve` per use.
NumberAnimation {
    duration: Anim.normal
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Anim.standard
}

// ~/nikkita-shell/dotfiles/quickshell/common/HexShape.qml
// A rounded hexagon, flat on top and bottom, filling its box (a regular one is
// 1.155 times as wide as tall). The picture frame and mask, and the lock screen's
// card, which is stretched: its sides have a shallower `point`.
import QtQuick
import QtQuick.Shapes
import qs.common

Shape {
    id: hex

    property color fill: Theme.overlay
    property color stroke: "transparent"
    property real strokeWidth: 0
    // Overrides `fill` (a LinearGradient from QtQuick.Shapes, in the shape's box).
    property ShapeGradient gradient: null
    property real round: 0.24           // how much of each side the corners take
    property real point: width * 0.25   // how deep the side points are

    preferredRendererType: Shape.CurveRenderer

    readonly property string outline: {
        const w = width, h = height, k = round, p = point;
        const c = [[p, 0], [w - p, 0], [w, h / 2], [w - p, h], [p, h], [0, h / 2]];
        const lerp = (a, b, f) => [a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f];
        const f = p => p[0].toFixed(2) + " " + p[1].toFixed(2);
        let d = "";
        for (let i = 0; i < 6; i++) {
            const prev = c[(i + 5) % 6], here = c[i], next = c[(i + 1) % 6];
            d += (i === 0 ? "M " : " L ") + f(lerp(here, prev, k)) + " Q " + f(here) + " " + f(lerp(here, next, k));
        }
        return d + " Z";
    }

    ShapePath {
        fillColor: hex.fill
        fillGradient: hex.gradient
        strokeColor: hex.stroke
        strokeWidth: hex.strokeWidth
        PathSvg { path: hex.outline }
    }
}

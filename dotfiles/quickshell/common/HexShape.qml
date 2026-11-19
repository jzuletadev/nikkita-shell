// ~/nikita-shell/dotfiles/quickshell/common/HexShape.qml
// The desktop's hexagon, rounded and standing on a point like the one in the logo. It
// fills its box: `width: height * Theme.hexRatio` gives the logo's proportion. The
// lock screen's card is wider, with its own `point`. `label` writes inside it.
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
    property real point: height * 0.24  // how tall the top and bottom points are
    property string label: ""
    property color labelColor: Theme.fg
    property int labelSize: Theme.textCaption
    readonly property real labelWidth: labelText.implicitWidth

    preferredRendererType: Shape.CurveRenderer

    readonly property string outline: {
        const w = width, h = height, k = round, p = point;
        const c = [[w / 2, 0], [w, p], [w, h - p], [w / 2, h], [0, h - p], [0, p]];
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

    StyledText {
        id: labelText
        anchors.centerIn: parent
        visible: hex.label !== ""
        text: hex.label
        color: hex.labelColor
        font.pixelSize: hex.labelSize
        font.weight: Font.DemiBold
    }
}

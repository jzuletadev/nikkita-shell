// ~/nikita-shell/dotfiles/quickshell/common/Spinner.qml
// An open hexagon that turns while visible (connecting...).
import QtQuick
import QtQuick.Shapes
import qs.common

Item {
    id: spinner

    property int size: 14
    property color color: Theme.fg

    implicitWidth: size
    implicitHeight: size

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: spinner.color
            strokeWidth: Math.max(1.5, spinner.size / 8)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            // Five of the six sides.
            PathSvg {
                path: {
                    const c = spinner.size / 2, r = c - 1.5, p = [];
                    for (let i = 0; i < 6; i++) {
                        const a = (i * 60 - 90) * Math.PI / 180;
                        p.push((i === 0 ? "M " : "L ") + (c + r * Math.cos(a)).toFixed(2) + " " + (c + r * Math.sin(a)).toFixed(2));
                    }
                    return p.join(" ");
                }
            }
        }

        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            running: spinner.visible
        }
    }
}

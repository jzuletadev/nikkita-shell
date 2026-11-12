// ~/nikkita-shell/dotfiles/quickshell/common/Spinner.qml
// An arc that turns while visible (connecting...).
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
            PathAngleArc {
                centerX: spinner.size / 2
                centerY: spinner.size / 2
                radiusX: spinner.size / 2 - 1.5
                radiusY: spinner.size / 2 - 1.5
                startAngle: 0
                sweepAngle: 270
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

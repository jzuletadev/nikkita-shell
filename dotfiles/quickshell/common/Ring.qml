// ~/nikita-shell/dotfiles/quickshell/common/Ring.qml
// A progress ring (0-100) with the value in the middle.
import QtQuick
import QtQuick.Shapes
import qs.common

Item {
    id: ring

    property real value: 0
    property string label: Math.round(value) + "%"
    property color color: value >= 90 ? Theme.bad : value >= 75 ? Theme.warn : Theme.accent
    property int thickness: 5
    property int size: 56

    implicitWidth: size
    implicitHeight: size

    property real drawn: value
    Behavior on drawn { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Theme.cardHover
            strokeWidth: ring.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.width / 2 - ring.thickness / 2
                radiusY: ring.height / 2 - ring.thickness / 2
                startAngle: 0
                sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: ring.color
            strokeWidth: ring.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.width / 2 - ring.thickness / 2
                radiusY: ring.height / 2 - ring.thickness / 2
                startAngle: -90
                sweepAngle: 3.6 * Math.max(0.5, Math.min(100, ring.drawn))
            }
        }
    }

    StyledText {
        anchors.centerIn: parent
        text: ring.label
        font.family: Theme.monoFamily
        font.pixelSize: Theme.textSmall
        font.weight: Font.DemiBold
    }
}

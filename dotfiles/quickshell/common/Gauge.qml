// ~/nikita-shell/dotfiles/quickshell/common/Gauge.qml
// A 0-100 gauge: a 270° arc open at the bottom, with the value and a caption in
// the middle. Amber from 75, red from 90, like Ring.
import QtQuick
import QtQuick.Shapes
import qs.common

Item {
    id: gauge

    property real value: 0
    property string label: Math.round(value) + "%"
    property string caption: ""
    property color color: value >= 90 ? Theme.bad : value >= 75 ? Theme.warn : Theme.accent
    property int thickness: 7
    property int size: 92

    implicitWidth: size
    implicitHeight: size

    property real drawn: value
    Behavior on drawn { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

    readonly property real r: size / 2 - thickness / 2

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.alpha(Theme.fg, 0.1)
            strokeWidth: gauge.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: gauge.size / 2
                centerY: gauge.size / 2
                radiusX: gauge.r
                radiusY: gauge.r
                startAngle: 135
                sweepAngle: 270
            }
        }
        ShapePath {
            strokeColor: gauge.color
            strokeWidth: gauge.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: gauge.size / 2
                centerY: gauge.size / 2
                radiusX: gauge.r
                radiusY: gauge.r
                startAngle: 135
                sweepAngle: 2.7 * Math.max(0.5, Math.min(100, gauge.drawn))
            }
        }
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 2
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: gauge.label
            font.pixelSize: Math.round(gauge.size * 0.21)
            font.weight: Font.DemiBold
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: gauge.caption !== ""
            text: gauge.caption
            color: Theme.muted
            font.pixelSize: Theme.textCaption
        }
    }
}

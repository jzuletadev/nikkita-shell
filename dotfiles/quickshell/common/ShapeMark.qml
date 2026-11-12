// ~/nikkita-shell/dotfiles/quickshell/common/ShapeMark.qml
// The desktop's four marks: circle, square, cross, triangle (`index` 0-3, then
// again). Used by the workspace rail and the lock screen's password.
import QtQuick
import QtQuick.Shapes
import qs.common

Item {
    id: mark

    property int index: 0
    property int size: 14
    property color color: Theme.accent
    property real stroke: 1.8

    // In a 14 px box.
    readonly property var paths: [
        "M 1.5 7 A 5.5 5.5 0 1 0 12.5 7 A 5.5 5.5 0 1 0 1.5 7 Z",
        "M 2.5 2.5 L 11.5 2.5 L 11.5 11.5 L 2.5 11.5 Z",
        "M 2.6 2.6 L 11.4 11.4 M 11.4 2.6 L 2.6 11.4",
        "M 7 1.4 L 12.8 11.4 L 1.2 11.4 Z"
    ]

    implicitWidth: size
    implicitHeight: size

    Shape {
        anchors.centerIn: parent
        width: 14
        height: 14
        scale: mark.size / 14
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: mark.color
            strokeWidth: mark.stroke
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: mark.paths[((mark.index % 4) + 4) % 4] }
        }
    }
}

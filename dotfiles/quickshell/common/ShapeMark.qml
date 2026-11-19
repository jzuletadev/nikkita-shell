// ~/nikita-shell/dotfiles/quickshell/common/ShapeMark.qml
// The mark of each typed character on the lock screen: the desktop's hexagon, standing
// on a point like the logo's, drawn as an outline.
import QtQuick
import QtQuick.Shapes
import qs.common

Item {
    id: mark

    property int size: 14
    property color color: Theme.accent
    property real stroke: 1.8

    // In a 14 px box.
    readonly property string path: "M 7 1 L 12.2 4 L 12.2 10 L 7 13 L 1.8 10 L 1.8 4 Z"

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
            PathSvg { path: mark.path }
        }
    }
}

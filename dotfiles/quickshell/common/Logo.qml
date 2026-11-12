// ~/nikkita-shell/dotfiles/quickshell/common/Logo.qml
//
// The logo in the theme's color: Arch's, or assets/logo.svg (or .png) drawn as a
// silhouette so any logo reads on both themes. Read at start: restart qs after
// changing it.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.common

Item {
    id: logo

    property int size: 22
    property color color: Theme.accent

    implicitWidth: size
    implicitHeight: size

    readonly property string assets: Paths.repo + "/assets"
    property string customPath: ""

    FileView {
        path: logo.assets + "/logo.svg"
        printErrors: false
        onLoaded: logo.customPath = path
    }
    FileView {
        path: logo.assets + "/logo.png"
        printErrors: false
        onLoaded: if (logo.customPath === "") logo.customPath = path
    }

    // Arch's official outline, from /usr/share/pixmaps/archlinux-logo.svg
    // (filesystem package), drawn in its 256 px box and scaled down.
    Shape {
        width: 256
        height: 256
        scale: logo.size / 256
        transformOrigin: Item.TopLeft
        visible: logo.customPath === ""
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: logo.color
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            PathSvg { path: "m127.98 12.07c-10.316 25.309-16.543 41.855-28.031 66.41 7.043 7.4609 15.691 16.156 29.734 25.977-15.098-6.207-25.395-12.445-33.094-18.918-14.703 30.68-37.742 74.391-84.492 158.39 36.746-21.219 65.23-34.293 91.773-39.289-1.1406-4.8945-1.7852-10.195-1.7422-15.734l0.042969-1.1719c0.58203-23.551 12.828-41.645 27.336-40.418 14.508 1.2266 25.781 21.316 25.199 44.867-0.10938 4.4219-0.60938 8.6914-1.4805 12.641 26.258 5.1328 54.438 18.18 90.684 39.105-7.1484-13.156-13.527-25.016-19.621-36.316-9.5938-7.4336-19.605-17.117-40.023-27.594 14.035 3.6406 24.082 7.8516 31.914 12.555-61.941-115.32-66.957-130.66-88.199-180.5z" }
        }
    }

    Image {
        id: custom
        anchors.fill: parent
        visible: false
        source: logo.customPath === "" ? "" : "file://" + logo.customPath
        sourceSize: Qt.size(logo.size * 3, logo.size * 3)
        fillMode: Image.PreserveAspectFit
        smooth: true
        layer.enabled: true
    }
    Rectangle {
        id: ink
        anchors.fill: parent
        visible: false
        color: logo.color
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: parent
        visible: logo.customPath !== "" && custom.status === Image.Ready
        source: ink
        maskEnabled: true
        maskSource: custom
        // The ramp goes from (min - spread) to min, both scaled by (1 + spread):
        // 0.5 and 1 make it 0..1, so the logo's alpha (its antialiased edge
        // included) passes through as it is.
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }
}

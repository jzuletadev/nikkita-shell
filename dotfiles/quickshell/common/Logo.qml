// ~/nikita-shell/dotfiles/quickshell/common/Logo.qml
//
// The logo in the theme's color: the hexagon with the rocket cut out of it, or the
// rocket alone (`mark`). Under 32 px it uses the simpler drawings, whose details would
// be mud. They live in assets/brand (scripts/brand-assets.py).
import QtQuick
import QtQuick.Effects
import qs.common

Item {
    id: logo

    property int size: 22
    property color color: Theme.accent
    property string mark: "hexagon"     // hexagon | rocket

    implicitWidth: size
    implicitHeight: size

    Image {
        id: art
        anchors.fill: parent
        visible: false
        source: "file://" + Paths.repo + "/assets/brand/" + logo.mark + (logo.size < 32 ? "-small" : "") + ".svg"
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
        visible: art.status === Image.Ready
        source: ink
        maskEnabled: true
        maskSource: art
        // The ramp goes from (min - spread) to min, both scaled by (1 + spread):
        // 0.5 and 1 make it 0..1, so the logo's alpha (its antialiased edge
        // included) passes through as it is.
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }
}

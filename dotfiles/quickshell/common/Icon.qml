// ~/nikkita-shell/dotfiles/quickshell/common/Icon.qml
//
// A symbolic theme icon, tinted. Qt paints the gray baked into the SVG, so it goes
// through MultiEffect: white, then the color. App icons: AppIcon.qml.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.common

Item {
    id: ic

    property string name: ""
    property color color: Theme.fg
    property int size: 16

    implicitWidth: size
    implicitHeight: size

    IconImage {
        anchors.fill: parent
        implicitSize: ic.size
        source: ic.name === "" ? "" : Quickshell.iconPath(ic.name, "image-missing")
        asynchronous: true
        layer.enabled: true
        layer.effect: MultiEffect {
            brightness: 1.0
            colorization: 1.0
            colorizationColor: ic.color
        }
    }
}

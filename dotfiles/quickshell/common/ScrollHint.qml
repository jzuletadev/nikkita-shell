// ~/nikita-shell/dotfiles/quickshell/common/ScrollHint.qml
// Thin scroll indicator for a Flickable/ListView, placed as its sibling. Only
// visible when there is more content than fits.
import QtQuick
import qs.common

Rectangle {
    id: bar

    required property Flickable view

    x: view.x + view.width + 3
    width: 3
    radius: width / 2
    color: Theme.faint
    visible: view.visibleArea.heightRatio < 0.999
    opacity: view.moving ? 0.9 : 0.4
    y: view.y + view.visibleArea.yPosition * view.height
    height: Math.max(16, view.visibleArea.heightRatio * view.height)

    Behavior on opacity { NumberAnimation { duration: Theme.msNormal } }
}

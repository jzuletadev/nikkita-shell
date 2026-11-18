// ~/nikita-shell/dotfiles/quickshell/common/EdgeFade.qml
//
// A fade over the bottom of a list while more is below it, so the row that doesn't
// fit looks cut on purpose. The list's sibling, like ScrollHint. `tone` is what is
// around the list.
import QtQuick
import qs.common

Rectangle {
    id: fade

    required property Flickable view
    property color tone: Theme.panel

    x: view.x
    y: view.y + view.height - height
    width: view.width
    height: 32
    opacity: view.atYEnd ? 0 : 1
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.msFast } }

    gradient: Gradient {
        GradientStop { position: 0; color: Theme.alpha(fade.tone, 0) }
        GradientStop { position: 1; color: fade.tone }
    }
}

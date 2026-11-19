// ~/nikita-shell/dotfiles/quickshell/common/EdgeFade.qml
//
// Fades the bottom of a list while more is below it, so the row that doesn't fit looks
// cut on purpose. The list's sibling, like ScrollHint. It fades the list itself: a
// color laid over it would show on a translucent panel.
import QtQuick
import QtQuick.Effects
import qs.common

Item {
    id: fade

    required property Flickable view

    Rectangle {
        id: mask
        width: fade.view.width
        height: fade.view.height
        visible: false
        layer.enabled: true
        gradient: Gradient {
            GradientStop { position: 0; color: "white" }
            GradientStop { position: Math.max(0, 1 - 32 / Math.max(1, mask.height)); color: "white" }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    Component {
        id: effect
        MultiEffect {
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }
    Binding {
        target: fade.view.layer
        property: "enabled"
        value: !fade.view.atYEnd
    }
    Component.onCompleted: view.layer.effect = effect
}

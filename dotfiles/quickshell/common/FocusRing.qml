// ~/nikita-shell/dotfiles/quickshell/common/FocusRing.qml
//
// The keyboard's mark on a control: a ring just outside it, only while the control
// holds the focus. A click never gives it (the controls take the focus by Tab and
// arrows only), so the ring means "the keys act here" and nothing else.
// Put it inside the control: `FocusRing { inner: <its radius> }`; `target` is the item that has the focus.
import QtQuick
import qs.common

Rectangle {
    id: ring

    property Item target: parent
    property real gap: 2
    property real inner: Theme.radiusM      // the control's own radius

    anchors.fill: parent
    anchors.margins: -gap - 1
    radius: inner + gap + 1
    color: "transparent"
    border.width: 2
    border.color: Theme.fg
    visible: target.activeFocus
    opacity: visible ? 1 : 0
}

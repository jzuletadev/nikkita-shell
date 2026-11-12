// ~/nikkita-shell/dotfiles/quickshell/surfaces/RecordingMark.qml

import QtQuick
import qs.common
import qs.services

EdgePanel {
    property bool trayOpen: false

    name: "mark"
    edge: "bottom"
    placement: "center"
    touchable: false
    span: 44
    depth: 7
    inset: 0
    panelColor: Theme.bad
    pinned: Recorder.active && !trayOpen
}

// ~/nikkita-shell/dotfiles/quickshell/surfaces/PrivacyMark.qml
//
// An amber notch at the bottom while an app uses the microphone, the camera or
// your screen (services/Privacy.qml); the tray, right above it, says who. Beside
// the red recording mark when both show.

import QtQuick
import qs.common
import qs.services

EdgePanel {
    property bool trayOpen: false

    name: "privacy"
    edge: "bottom"
    placement: "center"
    offset: Recorder.active ? span + Theme.spaceM : 0
    touchable: false
    span: 44
    depth: 7
    inset: 0
    panelColor: Theme.warn
    pinned: Privacy.inUse && !trayOpen
}

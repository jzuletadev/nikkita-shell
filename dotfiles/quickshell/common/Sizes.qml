// ~/nikita-shell/dotfiles/quickshell/common/Sizes.qml
//
// Every size of the desktop, derived from the monitor.
import QtQuick
import qs.common

QtObject {
    property real screenWidth: 1920
    property real screenHeight: 1080
    // A fullscreen window on this monitor: the edges stop opening panels, or a game
    // would open them by accident. Keys still do.
    property bool edgesOff: false

    // The text doesn't scale, so a share of the screen needs limits: below them the
    // content stops fitting, above them a panel is mostly air (an ultrawide, 4K at
    // scale 1).
    function share(size, part, least, most) {
        return Math.round(Math.max(least, Math.min(most, size * part)));
    }

    // How far a rail reaches into the screen.
    readonly property int rail: share(screenWidth, 0.030, 40, 60)
    readonly property int corner: share(screenWidth, 0.195, 340, 460)
    // The corners that hold a list. Power and Quick actions are as tall as their content.
    readonly property int cornerHeight: share(screenHeight, 0.215, 220, 340)
    readonly property int centerWidth: share(screenWidth, 0.46, 600, 1000)
    // The tray's minimum: it grows with its icons.
    readonly property int trayWidth: share(screenWidth, 0.07, 90, 180)
    readonly property int dock: share(screenHeight, 0.27, 200, 340)
    // The launcher's field: its width and where it is born.
    readonly property int searchWidth: Math.round(Math.min(corner * 1.12, screenHeight * 0.62)) + 40
    // A little below the middle, but never so low that seven rows below the 52 px
    // field (7 x 48 + gaps + padding = 360) leave the screen.
    readonly property int searchTop: Math.round(Math.min(screenHeight * 0.56, screenHeight - 52 - 8 - 360 - 40))

    // Radius and notch don't scale: the eye measures them against the text.
    readonly property int radius: Theme.radiusL
    readonly property int notch: 18
    // The strip that takes the pointer while a panel is closed.
    readonly property int strip: 6
    readonly property int inset: Theme.spaceL
}

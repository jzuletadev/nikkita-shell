// ~/nikita-shell/dotfiles/quickshell/common/Sizes.qml
//
// Every size of the desktop, derived from the monitor.
import QtQuick
import qs.common

QtObject {
    property real screenWidth: 1920
    property real screenHeight: 1080

    // How far a rail reaches into the screen.
    readonly property int rail: Math.round(screenWidth * 0.030)
    readonly property int corner: Math.round(screenWidth * 0.195)
    readonly property int cornerHeight: Math.round(screenHeight * 0.215)
    readonly property int centerWidth: Math.round(screenWidth * 0.46)
    // The tray's minimum: it grows with its icons.
    readonly property int trayWidth: Math.round(screenWidth * 0.07)
    readonly property int dock: Math.round(screenHeight * 0.27)
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

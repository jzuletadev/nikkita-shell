// ~/nikita-shell/dotfiles/quickshell/common/Glyphs.qml
//
// Nerd Font icons used for the same thing in more than one place, by name, so one
// idea keeps one icon everywhere. For what Adwaita has no icon for; Glyph.qml and
// PillButton's `glyph` draw them.
pragma Singleton

import Quickshell

Singleton {
    // Keep the screen awake: a cup, full while on.
    readonly property int keepAwake: 0xF0176
    readonly property int keepAwakeOff: 0xF06CA
    // The two styles: a circle half filled (Font Awesome's "adjust") and a sun. Not
    // a moon: the moon means sleep.
    readonly property int darkStyle: 0xF042
    readonly property int lightStyle: 0xF05A8
    // Settings: a gear (Adwaita's is a wrench and a screwdriver).
    readonly property int settings: 0xF0493
}

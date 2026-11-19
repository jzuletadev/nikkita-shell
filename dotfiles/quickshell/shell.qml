//@ pragma UseQApplication
//@ pragma IconTheme Adwaita

// ~/nikita-shell/dotfiles/quickshell/shell.qml

import QtQuick
import Quickshell
import qs.lock
import qs.music
import qs.services
import qs.settings
import qs.surfaces

ShellRoot {
    // Singletons are created on first use. These must be alive from startup: the
    // notification server has to claim its bus name, the clipboard history has to
    // start listening, and the battery and the system notices have to speak while
    // nothing shows them.
    readonly property var preload: [Notifs.history, ClipHistory.entries, Battery.pct, SystemNotices.categories]

    Variants {
        model: Quickshell.screens

        ScreenSurface {}
    }

    // Its surfaces exist only while locked.
    LockScreen {}

    // The polkit agent.
    AuthDialog {}

    // Windows: built when they open, destroyed when they close.
    LazyLoader {
        active: ShellState.musicOpen

        MusicWindow {}
    }

    LazyLoader {
        active: ShellState.settingsOpen

        SettingsWindow {}
    }
}

// ~/nikita-shell/dotfiles/quickshell/common/Paths.qml
//
// Where the desktop's files are. The login screen (NIKITA_GREETER=1) runs as the
// `greeter` user, who can't read your home: it reads the copies that
// install-greeter.sh and greeter-sync.sh keep outside it.
pragma Singleton

import QtQuick
import Quickshell
import qs.services

Singleton {
    readonly property bool greeter: Quickshell.env("NIKITA_GREETER") === "1"
    readonly property string home: Quickshell.env("HOME")
    readonly property string repo: greeter ? "/usr/share/nikita-shell" : home + "/nikita-shell"
    readonly property string state: greeter ? "/var/lib/nikita-shell" : home + "/.local/state/nikita-shell"
    // Yours is a link wallpaper.sh keeps; the login screen's, a copy it keeps.
    readonly property string wallpaper: state + "/wallpaper"
    readonly property string config: Quickshell.env("XDG_CONFIG_HOME") || home + "/.config"
    // The same folders the scripts write to (screenshot.sh, install.sh).
    readonly property string screenshots: home + "/Pictures/screenshots"
    readonly property string recordings: home + "/Videos/recordings"
    readonly property string wallpapers: home + "/Pictures/wallpapers"
    readonly property string music: home + "/Music"

    function script(name) {
        return repo + "/scripts/" + name;
    }

    function face(user) {
        return greeter ? state + "/faces/" + user : home + "/.face";
    }

    // Refreshes the login screen's copies; Theme and Prefs call it on every load,
    // often together: one run covers both.
    function syncGreeter() {
        if (!greeter)
            syncTimer.restart();
    }
    Timer {
        id: syncTimer
        interval: 300
        onTriggered: Commands.run([script("greeter-sync.sh")], "Updating the login screen")
    }
}

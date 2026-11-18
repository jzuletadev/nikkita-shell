// ~/nikita-shell/dotfiles/quickshell/services/NightLight.qml
//
// Warmer colors at night, through hyprsunset (Hyprland's color matrix). It runs
// only while the screen is warm: stopping it gives the colors back. The setting is
// Prefs' (Settings → Display, Quick actions, the launcher).
//
// The schedule is a single timer to the next change, not a clock that ticks. Timers
// stand still while the computer sleeps, but sleeping always locks first, so the
// unlock checks again.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: night

    readonly property bool enabled: Prefs.nightLight
    readonly property bool scheduled: Prefs.nightScheduled
    readonly property int temperature: Prefs.nightTemperature
    // Whether the screen is warm right now.
    property bool active: false

    // "20:00", or "8:00 PM" with the 12-hour clock.
    function clock(minutes) {
        const h = Math.floor(minutes / 60) % 24, m = minutes % 60;
        const mm = (m < 10 ? "0" : "") + m;
        if (!Prefs.clock24h)
            return ((h + 11) % 12 + 1) + ":" + mm + (h < 12 ? " AM" : " PM");
        return (h < 10 ? "0" : "") + h + ":" + mm;
    }
    // For tooltips and Settings.
    readonly property string status: !enabled ? "Off"
        : !scheduled ? "On"
        : active ? "On until " + clock(Prefs.nightTo) : "Starts at " + clock(Prefs.nightFrom)

    function inWindow(m) {
        const a = Prefs.nightFrom, b = Prefs.nightTo;
        if (a === b)
            return true;
        return a < b ? m >= a && m < b : m >= a || m < b;
    }

    function update() {
        const now = new Date();
        const m = now.getHours() * 60 + now.getMinutes();
        active = enabled && (!scheduled || inWindow(m));
        if (!enabled || !scheduled) {
            boundary.stop();
            return;
        }
        const target = active ? Prefs.nightTo : Prefs.nightFrom;
        let ms = (target - m) * 60000 - now.getSeconds() * 1000 - now.getMilliseconds();
        if (ms <= 0)
            ms += 24 * 3600000;
        boundary.interval = ms + 1000;
        boundary.restart();
    }

    readonly property var watched: [enabled, scheduled, Prefs.nightFrom, Prefs.nightTo]
    onWatchedChanged: update()
    Component.onCompleted: update()

    Timer {
        id: boundary
        onTriggered: night.update()
    }
    Connections {
        target: ShellState
        function onLockSecureChanged() {
            if (!ShellState.lockSecure)
                night.update();
        }
    }

    // A new warmth while it runs: told to hyprsunset, once the slider rests.
    onTemperatureChanged: if (sunset.running) retint.restart()
    Timer {
        id: retint
        interval: 150
        onTriggered: Commands.run(["hyprctl", "hyprsunset", "temperature", String(night.temperature)], "Night light")
    }

    Process {
        id: sunset
        running: night.active
        command: ["hyprsunset", "-t", String(night.temperature)]
        property bool started: false
        property bool stopAsked: false
        onRunningChanged: {
            if (running) {
                started = true;
                stopAsked = false;
            } else if (!started) {
                // A program that isn't there never starts and never exits.
                Commands.report("Night light", "hyprsunset isn't installed: sudo pacman -S hyprsunset");
            }
            started = running;
        }
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        // Stopping it is how the colors come back; ending by itself isn't normal
        // (another program holding the color matrix, for one).
        onExited: code => {
            if (!stopAsked) {
                const why = Commands.lastLine(stderr.text) || Commands.lastLine(stdout.text).replace(/^[┣┃╹\s]+/, "");
                Commands.report("Night light", why || `hyprsunset ended with code ${code}.`);
            }
            stopAsked = false;
        }
    }
    onActiveChanged: if (!active && sunset.running) sunset.stopAsked = true
}

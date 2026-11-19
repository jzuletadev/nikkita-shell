// ~/nikita-shell/dotfiles/quickshell/services/ShellState.qml
//
// The state shared by every screen, and the commands hyprland.lua calls
// (`qs ipc call nikita <command>`).
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: shellState

    // Monitor where the app launcher is open ("" = closed).
    property string launcherScreen: ""
    // Monitor where the window switcher (ALT+TAB, services/WindowSwitch.qml) is
    // open ("" = closed), and where the rail showing it is, in that screen's
    // coordinates: the switcher's keyboard surface leaves it out of its input.
    property string switcherScreen: ""
    property rect switcherRail: Qt.rect(0, 0, 0, 0)
    property bool doNotDisturb: false
    property bool keepAwake: false
    property bool settingsOpen: false
    // Settings closes when it loses the focus (SettingsWindow), except while it
    // waits for something it opened elsewhere: the portal's file chooser
    // (settingsWaiting, from Appearance) or the password dialog (authAsking, from
    // AuthDialog).
    property bool settingsWaiting: false
    property bool authAsking: false
    // Settings → Shortcuts is waiting for the keys of a shortcut: meanwhile Hyprland
    // is in the "nikita-capture" set of shortcuts (hyprland.lua), which has none of the
    // usual ones, so every key reaches the Settings window (SUPER + Q is then a press
    // to read, not "close this window"). Not the shortcuts-inhibit protocol: Hyprland
    // ignores it for a window that holds a focus grab, as Settings does (measured).
    property bool capturingKeys: false
    onCapturingKeysChanged: Hyprland.dispatch(capturingKeys ? 'hl.dsp.submap("nikita-capture")' : 'hl.dsp.submap("reset")')
    // A shell that went away while capturing left Hyprland without its shortcuts.
    Component.onCompleted: Hyprland.dispatch('hl.dsp.submap("reset")')
    property string settingsPage: "network"
    property bool musicOpen: false

    // Peek a panel for a while: `who` is its name or "*" for all, `where` the
    // monitor ("" = the focused one).
    signal peek(string who, int ms, string where)
    signal query(string text)
    signal lockRequested
    // "You are here": the workspace keys ask for it after going somewhere, so the
    // rail of that monitor peeks and its mark bounces (Workspaces.qml).
    signal locateRequested(string where)

    function lock() {
        lockRequested();
    }

    // Set by LockScreen: the compositor confirmed every monitor is covered.
    property bool lockSecure: false
    // Runs `argv` once the screen is really locked (sleep, hibernate), never with
    // the desktop still showing. If the lock doesn't come, it doesn't run.
    property var afterLock: null
    function lockThen(argv, what) {
        afterLock = { argv: argv, what: what };
        lock();
        if (lockSecure)
            runAfterLock();
        else
            lockTimeout.restart();
    }
    function runAfterLock() {
        if (afterLock === null)
            return;
        const a = afterLock;
        afterLock = null;
        lockTimeout.stop();
        Commands.run(a.argv, a.what);
    }
    onLockSecureChanged: if (lockSecure) runAfterLock()
    Timer {
        id: lockTimeout
        interval: 3000
        onTriggered: if (shellState.afterLock !== null) {
            Commands.report(shellState.afterLock.what, "The screen didn't lock, so it didn't go ahead.");
            shellState.afterLock = null;
        }
    }

    function focusedScreen() {
        if (Hyprland.focusedMonitor)
            return Hyprland.focusedMonitor.name;
        return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "";
    }

    // Opens the launcher on the focused monitor, or closes it (SUPER is a toggle).
    function toggleLauncher() {
        launcherScreen = launcherScreen !== "" ? "" : focusedScreen();
    }

    function closeLauncher() {
        launcherScreen = "";
    }

    // ---- the window switcher (services/WindowSwitch.qml) ----
    // ALT+TAB and ALT+SHIFT+TAB, bound in hyprland.lua to these global shortcuts:
    // Hyprland keeps ALT+TAB to itself, so the switcher can't read it as a key.
    GlobalShortcut {
        appid: "nikita"
        name: "switcher"
        description: "Switch windows: the next one"
        onPressed: WindowSwitch.step(1)
    }
    GlobalShortcut {
        appid: "nikita"
        name: "switcherBack"
        description: "Switch windows: the previous one"
        onPressed: WindowSwitch.step(-1)
    }
    // Windows by last use, the newest first (addresses), from Hyprland's focus
    // events: ready the moment the switcher opens. Layer surfaces (the switcher
    // itself) aren't windows, so they don't count.
    property var recentWindows: []
    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            const t = Hyprland.activeToplevel;
            if (t)
                shellState.recentWindows = [t.address].concat(shellState.recentWindows.filter(a => a !== t.address)).slice(0, 64);
        }
    }

    // Opens Settings on `page` ("" = where it was). Asking again for what is
    // already shown closes it: the keys are toggles.
    function toggleSettings(page) {
        if (settingsOpen && (page === "" || page === settingsPage)) {
            settingsOpen = false;
            return;
        }
        openSettings(page);
    }
    function openSettings(page) {
        if (page !== "")
            settingsPage = page;
        if (settingsOpen)
            Hyprland.dispatch('hl.dsp.focus({ window = "title:^Settings$" })');
        settingsOpen = true;
    }

    // Created if missing.
    function openFolder(dir) {
        Commands.launch(["sh", "-c", 'mkdir -p "$1"; command -v nautilus >/dev/null && exec nautilus --new-window "$1" || exec xdg-open "$1"', "sh", dir], "Opening the folder");
    }

    function toggleMusic() {
        if (musicOpen)
            musicOpen = false;
        else
            openMusic();
    }
    function openMusic() {
        if (musicOpen)
            Hyprland.dispatch('hl.dsp.focus({ window = "title:^Music$" })');
        musicOpen = true;
    }

    IpcHandler {
        target: "nikita"

        function launcher(): void {
            shellState.toggleLauncher();
        }
        function search(text: string): void {
            if (shellState.launcherScreen === "")
                shellState.toggleLauncher();
            shellState.query(text);
        }
        function all(): void {
            shellState.peek("*", 4000, "");
        }
        // locate [monitor]: show where you are ("" = the focused monitor).
        function locate(where: string): void {
            shellState.locateRequested(where === "" ? shellState.focusedScreen() : where);
        }
        function peek(name: string): void {
            shellState.peek(name, 4000, "");
        }
        // vol up | down | mute | N | osd (only show the dock; not "show", which
        // `qs ipc` reads as its own word)
        function vol(arg: string): void {
            Audio.adjust(arg);
            shellState.peek("ctrl", 1500, "");
        }
        function bri(arg: string): void {
            Brightness.adjust(arg);
            shellState.peek("ctrl", 1500, "");
        }
        // record screen | region | audio (the monitor with its sound); while one is
        // running, any of them stops it
        function record(how: string): void {
            if (Recorder.active)
                Recorder.stop();
            else
                Recorder.start(how === "region", how === "audio");
        }
        // settings [page]: network bluetooth sound display power appearance panels
        // notifications keyboard shortcuts pointer datetime apps about ("" = the last one)
        function settings(page: string): void {
            shellState.toggleSettings(page);
        }
        // On or off; the notification center peeks to say which, as the volume
        // dock does for the volume keys.
        function dnd(): void {
            shellState.doNotDisturb = !shellState.doNotDisturb;
            shellState.peek("notifications", 2000, "");
        }
        function music(): void {
            shellState.toggleMusic();
        }
        // play-pause, next, previous
        function media(what: string): void {
            Media.control(what);
        }
        // The keyboard's backlight: up | down | N.
        function kbdlight(arg: string): void {
            KeyboardLight.adjust(arg);
        }
        // Check for package updates again (scripts/updates.sh after an update).
        function updates(): void {
            Updates.check(false);
        }
        // hyprland.lua and hypridle fall back to hyprlock when this fails.
        function lock(): void {
            shellState.lock();
        }
    }
}

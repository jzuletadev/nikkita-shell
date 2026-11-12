// ~/nikkita-shell/dotfiles/quickshell/services/WindowSwitch.qml
//
// ALT+TAB: which windows, which one is chosen, and switching to it. The workspace
// rail shows it (it grows to list the windows); surfaces/Switcher.qml takes the
// keyboard meanwhile (letting go of ALT, arrows, Enter, Escape). hyprland.lua binds
// ALT+TAB and ALT+SHIFT+TAB to global shortcuts (ShellState), since Hyprland keeps
// the key, and each one calls `step`.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: sw

    readonly property bool open: ShellState.switcherScreen !== ""
    // After a short pause: a quick ALT+TAB switches before the rail moves.
    property bool shown: false
    // The most recent first (ShellState keeps the order from Hyprland's focus
    // events), then the rest by Hyprland's own history. Fixed while it is open, so a
    // window that changes title or closes doesn't move the others.
    property var windows: []
    property int selected: 0
    readonly property var chosen: windows[selected] ?? null
    // The workspace of the chosen window, for the rail to mark.
    readonly property int chosenWorkspace: chosen && chosen.toplevel.workspace ? chosen.toplevel.workspace.id : -1

    function build() {
        const recent = ShellState.recentWindows;
        const rank = t => {
            const i = recent.indexOf(t.address);
            if (i >= 0)
                return i;
            const h = t.lastIpcObject ? t.lastIpcObject.focusHistoryID : undefined;
            return 1000 + (h === undefined || h < 0 ? 1000 : h);
        };
        return Hyprland.toplevels.values.slice().sort((a, b) => rank(a) - rank(b)).map(t => {
            const id = (t.wayland && t.wayland.appId) || (t.lastIpcObject && t.lastIpcObject.class) || "";
            const e = id ? DesktopEntries.heuristicLookup(id) : null;
            const ws = t.workspace ? t.workspace.name : "";
            return {
                toplevel: t,
                title: t.title || (e ? e.name : id),
                app: e ? e.name : id,
                icon: e ? e.icon : id,
                where: Background.minimized(t) ? "minimized" : ws.startsWith("special:") ? "hidden" : ""
            };
        });
    }

    // Opens with the window before the one in front chosen (TAB) or the last one
    // (SHIFT+TAB); open, it moves the choice.
    function step(dir) {
        if (!open) {
            pendingRaise = null;
            windows = build();
            selected = windows.length < 2 ? 0 : dir > 0 ? 1 : windows.length - 1;
            ShellState.closeLauncher();
            ShellState.switcherScreen = ShellState.focusedScreen();
            reveal.restart();
            return;
        }
        move(dir);
    }
    function move(dir) {
        const n = windows.length;
        if (n > 0)
            selected = (selected + dir + n) % n;
    }
    function pick(i) {
        selected = i;
        commit();
    }

    // The keyboard goes back first, then the chosen window is raised. Hyprland
    // doesn't move the focus while the switcher holds the keyboard, and when it lets
    // go it refocuses the window you left: a raise sent before that loses (measured,
    // in either order). So the raise waits for that refocus, Hyprland's next
    // `activewindow` event, or at the latest for the rail to finish shrinking.
    property var pendingRaise: null
    function commit() {
        pendingRaise = chosen ? chosen.toplevel : null;
        close();
    }
    function cancel() {
        pendingRaise = null;
        close();
    }
    function close() {
        reveal.stop();
        shown = false;
        ShellState.switcherScreen = "";
    }
    function settle() {
        const t = pendingRaise;
        pendingRaise = null;
        if (t)
            Background.raise(t);
    }
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name === "activewindow" && sw.pendingRaise !== null && !sw.open)
                sw.settle();
        }
    }

    Timer {
        id: reveal
        interval: 90
        onTriggered: sw.shown = sw.open
    }
}

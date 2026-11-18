// ~/nikita-shell/dotfiles/quickshell/services/Monitors.qml
//
// Settings → Display's monitor editor: a draft of every monitor (on or off) that
// `apply()` hands to Hyprland live (`hyprctl eval 'hl.monitor(...)'`). Then it
// asks: kept, it is written to ~/.local/state/nikita-shell/monitors.lua,
// which hyprland.lua reads at every start and reload; not kept within 15 s (a
// screen gone black can't answer), it goes back. Every monitor gets a fixed
// position: one left on "auto" moves whenever another one changes (measured).
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.common

Singleton {
    id: mons

    // [{ name, description, enabled, width, height, refresh, x, y, scale, transform,
    //    modes: [{ width, height, refresh }] }]
    property var current: []
    property var draft: []
    property var previous: null        // what "Go back" restores while asking
    property int countdown: 0
    readonly property bool asking: previous !== null
    readonly property bool changed: JSON.stringify(draft) !== JSON.stringify(current)
    readonly property string file: Paths.state + "/monitors.lua"
    property bool saved: false

    function clone(v) {
        return JSON.parse(JSON.stringify(v));
    }
    function load() {
        if (!listProc.running)
            listProc.running = true;
        savedCheck.reload();
    }
    function set(i, key, value) {
        const d = clone(draft);
        d[i][key] = value;
        draft = d;
    }
    function undo() {
        draft = clone(current);
    }

    // The size a monitor takes in the layout: pixels over scale, turned by 90°/270°.
    function logical(m) {
        const w = Math.round(m.width / m.scale), h = Math.round(m.height / m.scale);
        return m.transform % 2 === 1 ? { w: h, h: w } : { w: w, h: h };
    }

    function spec(m) {
        if (!/^[A-Za-z0-9_.-]+$/.test(m.name))
            return "";
        if (!m.enabled)
            return `{ output = "${m.name}", disabled = true }`;
        return `{ output = "${m.name}", mode = "${m.width}x${m.height}@${m.refresh.toFixed(2)}", position = "${Math.round(m.x)}x${Math.round(m.y)}", scale = ${m.scale}, transform = ${m.transform} }`;
    }
    function lua(list) {
        return list.map(m => spec(m)).filter(s => s !== "").map(s => `hl.monitor(${s})`).join("; ");
    }

    function apply() {
        previous = clone(current);
        countdown = 15;
        tick.restart();
        Commands.run(["hyprctl", "eval", lua(draft)], "Changing the displays", () => mons.load());
    }
    // ---- the main display: workspace 1 (SUPER + 1) and the start of the session ----
    // hyprland.lua reads monitor-order (the main one first, then the rest from left
    // to right) and gives workspace i to the i-th monitor. A monitor is named by its
    // description (make, model, serial), so it stays the main one on another port.
    readonly property string orderFile: Paths.state + "/monitor-order"
    property var order: []
    // Where workspaces past the monitors' own are made: "main" (the main display)
    // or "current" (the monitor you are on). A line of the same file.
    property string newWorkspaces: "main"
    function identity(m) {
        return m.description && !/["\x00-\x1f]/.test(m.description) ? "desc:" + m.description : m.name;
    }
    // "AOC 27G2G4 (HDMI-A-1)"; a laptop's own panel, "Built-in display (eDP-1)".
    function label(m) {
        if (/^(eDP|LVDS|DSI)/.test(m.name))
            return "Built-in display (" + m.name + ")";
        const what = (m.make + " " + m.model).trim();
        return what !== "" ? what + " (" + m.name + ")" : m.name;
    }
    // The one you chose, while it is connected; otherwise the one with workspace 1.
    readonly property string main: {
        const on = current.filter(m => m.enabled);
        const chosen = on.find(m => identity(m) === order[0]);
        if (chosen)
            return identity(chosen);
        const one = Hyprland.workspaces.values.find(w => w.id === 1);
        const holder = one && one.monitor ? on.find(m => m.name === one.monitor.name) : null;
        return holder ? identity(holder) : on.length > 0 ? identity(on[0]) : "";
    }
    function setMain(id) {
        writeOrder(id, newWorkspaces);
    }
    function setNewWorkspaces(mode) {
        writeOrder(main, mode);
    }
    function writeOrder(id, mode) {
        if (id === "")
            return;
        const others = current.filter(m => m.enabled && identity(m) !== id)
            .sort((a, b) => a.x - b.x || a.y - b.y).map(m => identity(m));
        // FileView doesn't read back what it writes itself: the page follows now.
        order = [id].concat(others);
        newWorkspaces = mode;
        orderView.setText(order.concat(["new-workspaces=" + mode]).join("\n") + "\n");
    }
    FileView {
        id: orderView
        path: mons.orderFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const lines = text().split("\n").map(l => l.trim()).filter(l => l !== "");
            const mode = lines.find(l => l.startsWith("new-workspaces="));
            mons.newWorkspaces = mode === "new-workspaces=current" ? "current" : "main";
            mons.order = lines.filter(l => !l.startsWith("new-workspaces="));
        }
        onLoadFailed: {
            mons.order = [];
            mons.newWorkspaces = "main";
        }
        // Hyprland's rules come from its config: a reload places the workspaces.
        onSaved: Commands.run(["hyprctl", "reload", "config-only"], "Changing the main display", () => mons.load())
    }

    function keep() {
        tick.stop();
        previous = null;
        const lines = current.map(m => spec(m)).filter(s => s !== "").map(s => "    " + s + ",");
        saveView.setText("-- Written by Settings → Display (dotfiles/quickshell/services/Monitors.qml).\n"
            + "-- Delete it, or press \"Automatic\" there, to go back to the automatic layout.\n"
            + "return {\n" + lines.join("\n") + "\n}\n");
        saved = true;
        if (order.length > 0 && main !== "")
            setMain(main);
    }
    function revert() {
        tick.stop();
        const p = previous;
        previous = null;
        if (p !== null)
            Commands.run(["hyprctl", "eval", lua(p)], "Going back to the previous displays", () => mons.load());
    }
    // Forget the saved layout: every monitor in its preferred mode again.
    function automatic() {
        Commands.run(["rm", "-f", file], "Forgetting the display layout", code => {
            if (code === 0) {
                Paths.syncGreeter();
                Commands.run(["hyprctl", "reload"], "Reloading Hyprland", () => mons.load());
            }
        });
    }

    Timer {
        id: tick
        interval: 1000
        repeat: true
        onTriggered: {
            mons.countdown--;
            if (mons.countdown <= 0)
                mons.revert();
        }
    }

    FileView {
        id: saveView
        path: mons.file
        printErrors: false
        // Written: the login screen gets the same layout (greeter-sync.sh).
        onSaved: Paths.syncGreeter()
    }
    FileView {
        id: savedCheck
        path: mons.file
        printErrors: false
        onLoaded: mons.saved = true
        onLoadFailed: mons.saved = false
    }

    Process {
        id: listProc
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text).map(m => ({
                        name: m.name,
                        description: m.description,
                        make: m.make || "",
                        model: m.model || "",
                        enabled: !m.disabled,
                        width: m.width,
                        height: m.height,
                        refresh: Math.round(m.refreshRate * 100) / 100,
                        x: m.x,
                        y: m.y,
                        scale: Math.round(m.scale * 1000) / 1000,
                        transform: m.transform % 4,
                        modes: (m.availableModes || []).map(s => {
                            const r = /^(\d+)x(\d+)@([\d.]+)Hz$/.exec(s);
                            return r ? { width: +r[1], height: +r[2], refresh: Math.round(+r[3] * 100) / 100 } : null;
                        }).filter(x => x !== null)
                    })).sort((a, b) => a.x - b.x || a.y - b.y);
                    const keepDraft = mons.changed && mons.draft.length === list.length;
                    mons.current = list;
                    if (!keepDraft)
                        mons.draft = mons.clone(list);
                } catch (e) {
                    Commands.report("Reading the displays", "hyprctl monitors: " + e);
                }
            }
        }
    }
}

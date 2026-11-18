// ~/nikita-shell/dotfiles/quickshell/services/HyprSettings.qml
//
// What Settings changes in Hyprland: input options (keyboard, mouse, touchpad), the
// keys of a shortcut, your own shortcuts, touchpad gestures.
//
//   * The choices live in Prefs (settings.json). Each change is written to
//     hyprland-settings.lua in the state folder, which hyprland.lua reads over its
//     defaults, and Hyprland is reloaded.
//   * hyprland.lua stays the place where shortcuts and gestures are defined, and
//     publishes them (nikita.json in Hyprland's runtime folder): every shortcut with
//     its id and default keys, the default gestures, what a gesture can do.
//   * Input options are read back from Hyprland itself (`hyprctl getoption`), so a
//     page shows what is really in use, changed here or not.
//
// Nothing runs unless a setting changes or a Settings page asks (`refresh`).
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import "../common/Combo.js" as Combo

Singleton {
    id: hs

    // ================================================== published by hyprland.lua
    property var shortcuts: []           // [{ id, section, description, default, keys, fixed }]
    property var gestureDefaults: []     // [{ fingers, direction, action }]
    property var gestureActions: []      // [{ id, title, swipe }]
    property var problems: []            // hyprland.lua's own (an unreadable settings file)
    property var errors: []              // Hyprland's config errors after a reload (a key it doesn't know)

    FileView {
        id: published
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/hypr/" + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + "/nikita.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                hs.shortcuts = d.shortcuts || [];
                hs.gestureDefaults = d.gestureDefaults || [];
                hs.gestureActions = d.gestureActions || [];
                hs.problems = d.problems || [];
            } catch (e) {
                hs.problems = ["What hyprland.lua published can't be read: " + e];
            }
        }
        onLoadFailed: hs.problems = ["hyprland.lua hasn't published its shortcuts: reload Hyprland (hyprctl reload) or log in again."]
    }

    // ============================================== input options, as Hyprland has them
    // Name → kind. Only these are ever written: nothing else from settings.json can
    // reach the Lua file. "touchpad.speed" is ours: Hyprland sets a touchpad's speed
    // per device, by name.
    readonly property var known: ({
        "kb_layout": "string", "kb_variant": "string", "kb_options": "string", "numlock_by_default": "bool",
        "repeat_rate": "int", "repeat_delay": "int",
        "sensitivity": "float", "accel_profile": "string", "natural_scroll": "bool", "left_handed": "bool", "scroll_factor": "float",
        "touchpad.natural_scroll": "bool", "touchpad.tap_to_click": "bool", "touchpad.disable_while_typing": "bool",
        "touchpad.clickfinger_behavior": "bool", "touchpad.scroll_factor": "float", "touchpad.tap_and_drag": "bool"
    })
    property var options: ({})           // name → value, from Hyprland
    property var touchpads: []           // device names
    property bool loaded: false

    // The value in use: what you chose here, else what Hyprland has.
    function value(name) {
        const mine = Prefs.hyprInput[name];
        if (mine !== undefined)
            return mine;
        if (name === "touchpad.speed")
            return 0;
        return options[name];
    }
    function changed(name) {
        return Prefs.hyprInput[name] !== undefined;
    }

    function refresh() {
        published.reload();
        optionsProc.running = true;
        devicesProc.running = true;
        errorsProc.running = true;
    }

    Process {
        id: optionsProc
        command: ["sh", "-c", 'for o; do hyprctl getoption "$o" -j; done', "sh"]
            .concat(Object.keys(hs.known).map(n => "input:" + n.replace(".", ":")))
        stdout: StdioCollector {
            onStreamFinished: {
                const v = {};
                for (const line of text.split("\n")) {
                    if (line.trim() === "")
                        continue;
                    try {
                        const o = JSON.parse(line);
                        const name = o.option.replace(/^input:/, "").replace(":", ".");
                        v[name] = o.bool ?? o.int ?? o.float ?? o.str ?? "";
                        // An empty string comes back as "[[EMPTY]]".
                        if (v[name] === "[[EMPTY]]")
                            v[name] = "";
                    } catch (e) {
                        console.warn("hyprland settings: can't read an option:", line);
                    }
                }
                hs.options = v;
                hs.loaded = true;
            }
        }
    }
    Process {
        id: devicesProc
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const names = (JSON.parse(text).mice || []).map(m => m.name).filter(n => /touchpad|trackpad|glidepoint/i.test(n));
                    const before = hs.touchpads.join("\n");
                    hs.touchpads = names;
                    // A touchpad plugged in later gets the speed you chose, too.
                    if (hs.loadedDevices && before !== names.join("\n") && Prefs.hyprInput["touchpad.speed"] !== undefined)
                        apply.restart();
                    hs.loadedDevices = true;
                } catch (e) {
                    console.warn("hyprland settings: can't parse `hyprctl devices -j`");
                }
            }
        }
    }
    property bool loadedDevices: false
    Process {
        id: errorsProc
        command: ["hyprctl", "configerrors"]
        stdout: StdioCollector {
            onStreamFinished: hs.errors = text.split("\n").map(l => l.trim()).filter(l => l !== "")
        }
    }

    // ============================================================== the changes
    // Back to hyprland.lua's values for these (input option names).
    function resetInputs(names) {
        const m = Object.assign({}, Prefs.hyprInput);
        for (const n of names)
            delete m[n];
        Prefs.set("hyprInput", m);
        apply.restart();
    }
    function setInput(name, value) {
        const m = Object.assign({}, Prefs.hyprInput);
        if (value === undefined)
            delete m[name];
        else
            m[name] = value;
        Prefs.set("hyprInput", m);
        apply.restart();
    }

    // ---- shortcuts ----
    // The keys in use for a published shortcut: yours ("" = off), else its default.
    function keysOf(s) {
        const mine = Prefs.shortcutKeys[s.id];
        return mine !== undefined ? mine : s.default;
    }
    // The keys in use for a shortcut, for people ("SUPER + /"); "" if it has none.
    function keysLabel(id) {
        const s = shortcuts.find(x => x.id === id);
        const keys = s ? keysOf(s) : "";
        return keys !== "" ? Combo.label(keys) : "";
    }
    function setKeys(id, keys) {
        const s = shortcuts.find(x => x.id === id);
        const m = Object.assign({}, Prefs.shortcutKeys);
        if (keys === undefined || (s && keys === s.default))
            delete m[id];
        else
            m[id] = keys;
        Prefs.set("shortcutKeys", m);
        apply.restart();
    }
    function resetKeys() {
        Prefs.set("shortcutKeys", ({}));
        apply.restart();
    }
    function setCustom(list) {
        Prefs.set("customShortcuts", list);
        apply.restart();
    }

    // ---- gestures ----
    readonly property var gestures: Prefs.gestures !== null ? Prefs.gestures : gestureDefaults
    function gesture(fingers, direction) {
        const g = gestures.find(x => x.fingers === fingers && x.direction === direction);
        return g ? g.action : "";
    }
    function follows(action) {
        const a = gestureActions.find(x => x.id === action);
        return a !== undefined && a.swipe !== "";
    }
    // One that follows the fingers (switching workspace) takes both sides of its
    // axis; the other side gives it up when this one stops following.
    function setGesture(fingers, direction, action) {
        const other = ({ left: "right", right: "left", up: "down", down: "up" })[direction];
        const was = gesture(fingers, direction);
        let list = gestures.filter(g => !(g.fingers === fingers && g.direction === direction));
        if (other !== undefined && (follows(action) || follows(was)))
            list = list.filter(g => !(g.fingers === fingers && g.direction === other));
        if (action !== "") {
            list.push({ fingers: fingers, direction: direction, action: action });
            if (other !== undefined && follows(action))
                list.push({ fingers: fingers, direction: other, action: action });
        }
        // Back to the defaults is no change: hyprland.lua's list again (and its
        // later changes), and no reset button.
        Prefs.set("gestures", sameGestures(list, gestureDefaults) ? null : list);
        apply.restart();
    }
    function sameGestures(a, b) {
        const key = l => l.map(g => g.fingers + g.direction + "=" + g.action).sort().join(",");
        return key(a) === key(b);
    }
    function resetGestures() {
        Prefs.set("gestures", null);
        apply.restart();
    }

    // ================================================ writing hyprland-settings.lua
    function quote(s) {
        return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/[\x00-\x1f\x7f]/g, c => "\\" + c.charCodeAt(0)) + '"';
    }
    function literal(kind, v) {
        if (kind === "bool")
            return v ? "true" : "false";
        if (kind === "int")
            return String(Math.round(Number(v) || 0));
        if (kind === "float")
            return String(Math.round((Number(v) || 0) * 1000) / 1000);
        return quote(v);
    }

    function lua() {
        const out = ["-- Written by Settings (dotfiles/quickshell/services/HyprSettings.qml): what you changed",
                     "-- there, read by hyprland.lua over its defaults. Change it in Settings, not here: it is",
                     "-- rewritten from ~/.local/state/nikita-shell/settings.json.", "return {"];
        // input, and its touchpad table
        const top = [], pad = [];
        for (const name of Object.keys(known)) {
            const v = Prefs.hyprInput[name];
            if (v === undefined)
                continue;
            if (name.startsWith("touchpad."))
                pad.push(name.slice(9) + " = " + literal(known[name], v));
            else
                top.push(name + " = " + literal(known[name], v));
        }
        if (pad.length > 0)
            top.push("touchpad = { " + pad.join(", ") + " }");
        if (top.length > 0)
            out.push("    input = { " + top.join(", ") + " },");
        const speed = Prefs.hyprInput["touchpad.speed"];
        if (speed !== undefined && touchpads.length > 0)
            out.push("    devices = { " + touchpads.map(n => "{ name = " + quote(n) + ", sensitivity = " + literal("float", speed) + " }").join(", ") + " },");
        // shortcuts
        const keys = Object.keys(Prefs.shortcutKeys).filter(id => /^[a-z0-9-]+$/.test(id) && typeof Prefs.shortcutKeys[id] === "string");
        if (keys.length > 0)
            out.push("    keys = { " + keys.map(id => "[" + quote(id) + "] = " + quote(Prefs.shortcutKeys[id])).join(", ") + " },");
        const custom = Prefs.customShortcuts.filter(c => c && typeof c.keys === "string" && typeof c.command === "string" && c.command.trim() !== "");
        if (custom.length > 0)
            out.push("    custom = {\n" + custom.map(c => "        { keys = " + quote(c.keys) + ", command = " + quote(c.command)
                + ", description = " + quote(c.description || "") + " },").join("\n") + "\n    },");
        // gestures
        if (Prefs.gestures !== null) {
            const ok = Prefs.gestures.filter(g => g && [3, 4, 5].indexOf(g.fingers) >= 0
                && ["left", "right", "up", "down", "pinchin", "pinchout"].indexOf(g.direction) >= 0 && /^[a-z-]+$/.test(g.action || ""));
            out.push("    gestures = {" + ok.map(g => " { fingers = " + g.fingers + ", direction = " + quote(g.direction) + ", action = " + quote(g.action) + " },").join("") + " },");
        }
        out.push("}");
        return out.join("\n") + "\n";
    }

    property bool applying: false
    Timer {
        id: apply
        interval: 300
        onTriggered: {
            hs.applying = true;
            writer.setText(hs.lua());
        }
    }
    FileView {
        id: writer
        path: Paths.state + "/hyprland-settings.lua"
        printErrors: false
        // `config-only`: the monitors stay as they are.
        onSaved: Commands.run(["hyprctl", "reload", "config-only"], "Applying the settings", () => settle.restart())
        onSaveFailed: err => {
            hs.applying = false;
            Commands.report("Saving the settings", "hyprland-settings.lua can't be written (" + FileViewError.toString(err) + ").");
        }
    }
    // Hyprland answers before the reload is over.
    Timer {
        id: settle
        interval: 250
        onTriggered: {
            hs.applying = false;
            hs.refresh();
        }
    }
}

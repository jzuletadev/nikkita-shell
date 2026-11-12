// ~/nikkita-shell/dotfiles/quickshell/services/Background.qml
//
// What is running, for the tray: apps with windows (from Hyprland, grouped per app,
// minimized ones included) and the services in `known`, checked with systemctl only
// while the tray is open. Add yours to `known`.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: bg

    // ======== apps with windows ========
    readonly property var toplevels: Hyprland.toplevels.values
    readonly property var apps: {
        const groups = {};
        for (const t of toplevels) {
            const id = (t.wayland && t.wayland.appId) || (t.lastIpcObject && t.lastIpcObject.class) || "";
            if (id === "" || id === "org.quickshell")
                continue;
            (groups[id] = groups[id] || []).push(t);
        }
        return Object.keys(groups).map(id => {
            const e = DesktopEntries.heuristicLookup(id);
            return {
                "id": id,
                "name": e ? e.name : id,
                "icon": e ? e.icon : id,
                "windows": groups[id],
                "active": groups[id].some(t => bg.focused(t)),
                "minimized": groups[id].filter(t => bg.minimized(t)).length
            };
        }).sort((a, b) => a.name.localeCompare(b.name));
    }

    // `activated` only moves with focus events; the active toplevel is known at once.
    function focused(t) {
        return t.activated || t === Hyprland.activeToplevel;
    }
    function minimized(t) {
        return t.workspace !== null && t.workspace.name === "special:minimized";
    }

    // The next window of this app after the focused one (the first if none is).
    function show(app) {
        const i = app.windows.findIndex(t => bg.focused(t));
        raise(app.windows[(i + 1) % app.windows.length]);
    }
    // Every minimized window of this app, back to this workspace.
    function restore(app) {
        for (const t of app.windows)
            if (minimized(t))
                raise(t);
    }
    function raise(t) {
        const window = "address:0x" + t.address;
        if (minimized(t)) {
            const here = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;
            Hyprland.dispatch(`hl.dsp.window.move({ workspace = "${here}", window = "${window}" })`);
        }
        Hyprland.dispatch(`hl.dsp.focus({ window = "${window}" })`);
    }

    // "2 windows · workspaces 2 and 4 · 1 minimized"
    function describe(app) {
        const n = app.windows.length;
        const spaces = [...new Set(app.windows.filter(t => !minimized(t) && t.workspace).map(t => t.workspace.name))];
        const parts = [n + (n === 1 ? " window" : " windows")];
        if (spaces.length > 0)
            parts.push((spaces.length === 1 ? "workspace " : "workspaces ") + spaces.join(", "));
        if (app.minimized > 0)
            parts.push(app.minimized + " minimized");
        return parts.join(" · ");
    }

    Component.onCompleted: Hyprland.refreshToplevels()

    // ======== known services ========
    // `user`: a user unit. `open` runs in a terminal when clicked.
    readonly property var known: [
        { "id": "docker", "name": "Docker", "unit": "docker.service", "user": false, "glyph": 0xF0868,
          "open": 'command -v lazydocker >/dev/null && exec lazydocker; docker ps -a; echo; exec "${SHELL:-bash}"' },
        { "id": "podman", "name": "Podman", "unit": "podman.socket", "user": true, "glyph": 0xF0868,
          "open": 'podman ps -a; echo; exec "${SHELL:-bash}"' },
        { "id": "ollama", "name": "Ollama", "unit": "ollama.service", "user": false, "glyph": 0xF06A9,
          "open": 'ollama list; echo; ollama ps; echo; exec "${SHELL:-bash}"' },
        { "id": "postgresql", "name": "PostgreSQL", "unit": "postgresql.service", "user": false, "glyph": 0xF01BC,
          "open": 'systemctl status postgresql --no-pager; exec "${SHELL:-bash}"' },
        { "id": "mariadb", "name": "MariaDB", "unit": "mariadb.service", "user": false, "glyph": 0xF01BC,
          "open": 'systemctl status mariadb --no-pager; exec "${SHELL:-bash}"' },
        { "id": "redis", "name": "Redis", "unit": "redis.service", "user": false, "glyph": 0xF01BC,
          "open": 'systemctl status redis --no-pager; exec "${SHELL:-bash}"' },
        { "id": "libvirtd", "name": "Virtual machines", "unit": "libvirtd.service", "user": false, "glyph": 0xF0379,
          "open": 'command -v virt-manager >/dev/null && exec virt-manager; virsh list --all; exec "${SHELL:-bash}"' },
        { "id": "syncthing", "name": "Syncthing", "unit": "syncthing.service", "user": true, "glyph": 0xF04E6,
          "open": 'xdg-open http://127.0.0.1:8384' }
    ]
    property var running: []            // the known ones that are active, with `detail`
    property string dockerNote: ""      // containers running, or why it can't tell

    function refresh() {
        if (!check.running)
            check.running = true;
    }
    function open(service) {
        Commands.launch(["kitty", "--title", service.name, "-e", "sh", "-c", service.open], "Opening " + service.name);
    }

    // One pass: system units, a separator, user units, then Docker's containers
    // (the docker group only counts after logging in again).
    Process {
        id: check
        command: ["sh", "-c", "systemctl is-active " + bg.known.filter(s => !s.user).map(s => s.unit).join(" ")
            + "; echo --; systemctl --user is-active " + bg.known.filter(s => s.user).map(s => s.unit).join(" ")
            + "; echo --; docker ps -q 2>&1 | head -50"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("--\n");
                const system = (parts[0] || "").trim().split("\n");
                const user = (parts[1] || "").trim().split("\n");
                const docker = (parts[2] || "").trim();
                const states = {};
                bg.known.filter(s => !s.user).forEach((s, i) => states[s.id] = system[i] === "active");
                bg.known.filter(s => s.user).forEach((s, i) => states[s.id] = user[i] === "active");
                if (/permission denied/i.test(docker))
                    bg.dockerNote = "Log out and in again to see its containers";
                else if (/Cannot connect|error/i.test(docker))
                    bg.dockerNote = "";
                else {
                    const n = docker === "" ? 0 : docker.split("\n").length;
                    bg.dockerNote = n + (n === 1 ? " container running" : " containers running");
                }
                bg.running = bg.known.filter(s => states[s.id]);
            }
        }
    }
}

// ~/nikkita-shell/dotfiles/quickshell/services/ClipHistory.qml
//
// The clipboard history, fed by a `wl-paste --watch` this process owns. Text only;
// what a password manager marks secret (x-kde-passwordManagerHint) isn't stored.
// Saved in ~/.local/state/nikkita-shell/clipboard.json.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: clip

    property var entries: []
    readonly property int limit: 200
    
    function add(t) {
        if (!t || t.trim() === "")
            return;
        if (entries.length > 0 && entries[0] === t)
            return;
        entries = [t].concat(entries.filter(e => e !== t)).slice(0, limit);
        save();
    }

    function copy(t) {
        Commands.run(["wl-copy", "--", t], "Copying");
    }

    function remove(t) {
        entries = entries.filter(e => e !== t);
        save();
    }

    function clear() {
        entries = [];
        save();
    }

    function save() {
        store.setText(JSON.stringify(entries));
    }

    // A Quickshell that dies abruptly leaves its wl-paste alive and orphaned. Before
    // listening, any not owned by this process is stopped (they carry the nikkita-clip mark).
    Process {
        id: limpiar
        running: true
        command: ["sh", "-c", "for p in $(pgrep -x wl-paste); do [ \"$(awk '{print $4}' /proc/$p/stat)\" = \"$PPID\" ] && continue; grep -qa nikkita-clip /proc/$p/cmdline && kill $p; done; true"]
        onExited: watcher.running = true
    }

    // Record separator: \x1e, which copied text never contains.
    Process {
        id: watcher
        command: ["wl-paste", "--type", "text", "--watch", "sh", "-c",
            "wl-paste --list-types 2>/dev/null | grep -q x-kde-passwordManagerHint && exit 0; head -c 262144; printf '\\036'", "nikkita-clip"]
        stdout: SplitParser {
            splitMarker: "\u001e"
            onRead: data => clip.add(data)
        }
        onRunningChanged: if (!running && !limpiar.running) retry.start()
    }
    // If wl-paste dies (a compositor restart), it is launched again.
    Timer {
        id: retry
        interval: 3000
        onTriggered: watcher.running = true
    }

    FileView {
        id: store
        path: Paths.state + "/clipboard.json"
        printErrors: false
        onLoaded: {
            try {
                const v = JSON.parse(text());
                if (Array.isArray(v))
                    clip.entries = v.concat(clip.entries.filter(e => v.indexOf(e) < 0)).slice(0, clip.limit);
            } catch (e) {
                console.warn("clip: unreadable history, starting from scratch");
            }
        }
    }
}

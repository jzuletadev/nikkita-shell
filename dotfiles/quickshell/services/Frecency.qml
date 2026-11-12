// ~/nikkita-shell/dotfiles/quickshell/services/Frecency.qml
//
// What you open from the launcher, and how often and how recently, in
// ~/.local/state/nikkita-shell/launcher.json. `boost(id)` is at most 40
// points: enough to put what you use first among similar matches, never enough to
// lift a description match over a name match (Fuzzy.js keeps those 1000 apart).
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: frecency

    readonly property int maxBoost: 40
    readonly property int keep: 200            // entries kept; the least used go first
    property var uses: ({})                    // id -> { n: times, t: last time (ms) }

    function boost(id) {
        const u = uses[id];
        if (!u)
            return 0;
        // Halves every two weeks without use.
        const days = (Date.now() - u.t) / 86400000;
        return Math.min(maxBoost, 12 * Math.log2(1 + u.n)) * Math.pow(0.5, days / 14);
    }

    function used(id) {
        const next = Object.assign({}, uses);
        const u = next[id] || { n: 0, t: 0 };
        next[id] = { n: u.n + 1, t: Date.now() };
        const ids = Object.keys(next);
        if (ids.length > keep) {
            ids.sort((a, b) => next[a].n - next[b].n || next[a].t - next[b].t);
            for (const old of ids.slice(0, ids.length - keep))
                delete next[old];
        }
        uses = next;
        saveTimer.restart();
    }

    Timer {
        id: saveTimer
        interval: 1000
        onTriggered: file.setText(JSON.stringify(frecency.uses))
    }

    FileView {
        id: file
        path: Paths.state + "/launcher.json"
        printErrors: false
        onLoaded: {
            try {
                const v = JSON.parse(text());
                if (v && typeof v === "object")
                    frecency.uses = v;
            } catch (e) {
                console.warn("launcher: unreadable launcher.json, starting from scratch:", e);
            }
        }
    }
}

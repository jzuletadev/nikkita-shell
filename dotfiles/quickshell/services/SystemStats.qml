// ~/nikita-shell/dotfiles/quickshell/services/SystemStats.qml
//
// CPU, memory, disk, network, GPU and fans, from scripts/system-stats.py.
//
// The script only runs while the Performance tab is visible (`watch`).
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: stats

    property int watchers: 0
    property var latest: null
    property var net: []             // the last 60 samples {rx, tx}
    property real rxTotal: 0         // bytes moved since the stats started this time
    property real txTotal: 0
    property var disk: null
    property var machine: null
    readonly property string script: Paths.script("system-stats.py")

    function watch(want) {
        watchers = Math.max(0, watchers + (want ? 1 : -1));
    }
    // Nobody watches: the run is stopped (SIGTERM) on purpose. `running` stays true
    // until it is gone, so this is the moment to remember it.
    onWatchersChanged: if (watchers === 0 && proc.running) proc.stopAsked = true

    function loadMachine() {
        machineProc.running = true;
    }

    function bytes(b) {
        if (b === null || b === undefined)
            return "--";
        const u = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (b >= 1024 && i < u.length - 1) {
            b /= 1024;
            i++;
        }
        return (b >= 100 || i === 0 ? Math.round(b) : b.toFixed(1)) + " " + u[i];
    }

    // "8.5 GB / 237 GB" -> "8.5 / 237 GB": one unit when both share it.
    function pair(a, b) {
        const x = bytes(a), y = bytes(b);
        const ux = x.split(" ").pop(), uy = y.split(" ").pop();
        return ux === uy ? x.replace(" " + ux, "") + " / " + y : x + " / " + y;
    }

    // "Intel(R) Core(TM) i5-8250U CPU @ 1.60GHz" -> "Intel Core i5-8250U".
    function shortCpu(s) {
        return (s || "").replace(/\((R|TM)\)/g, "").replace(/\bCPU\b/, "").replace(/@.*$/, "")
            .replace(/\s+\d+-Core Processor/, "").replace(/\s+/g, " ").trim();
    }

    Process {
        id: proc
        running: stats.watchers > 0
        command: ["python3", stats.script]
        property bool warned: false
        property bool stopAsked: false
        // Each opening starts clean.
        onRunningChanged: if (running) {
            stats.net = [];
            stats.rxTotal = 0;
            stats.txTotal = 0;
            warned = false;
            stopAsked = false;
        }
        stderr: StdioCollector {}
        // Stopping it when nobody watches is normal; ending by itself isn't. Not
        // `watchers > 0` at the end: closing and reopening the tab at once ends the
        // old run with 15 (SIGTERM) when someone already watches again (measured),
        // and Quickshell then starts a new one by itself.
        onExited: code => {
            if (!stopAsked)
                Commands.report("System stats", Commands.lastLine(stderr.text) || `system-stats.py ended with code ${code}.`);
            stopAsked = false;
        }
        stdout: SplitParser {
            onRead: line => {
                try {
                    const d = JSON.parse(line);
                    if (d.disk)
                        stats.disk = d.disk;
                    stats.latest = d;
                    stats.net = stats.net.concat([d.net]).slice(-60);
                    // One line per second: a rate is also the bytes of that second.
                    stats.rxTotal += d.net.rx;
                    stats.txTotal += d.net.tx;
                } catch (e) {
                    // Once per run: it prints a line a second.
                    if (!proc.warned)
                        console.warn("stats: can't read a line of system-stats.py:", e, line);
                    proc.warned = true;
                }
            }
        }
    }

    Process {
        id: machineProc
        command: ["python3", stats.script, "--machine"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    stats.machine = JSON.parse(text);
                } catch (e) {
                    console.warn("stats: can't read system-stats.py --machine:", e);
                }
            }
        }
        stderr: StdioCollector {}
        onExited: code => {
            if (code !== 0)
                Commands.report("Reading this machine's details", Commands.lastLine(stderr.text) || `system-stats.py ended with code ${code}.`);
        }
    }
}

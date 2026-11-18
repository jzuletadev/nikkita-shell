// ~/nikita-shell/dotfiles/quickshell/services/Brightness.qml
//
// Screen brightness through brightnessctl. /sys doesn't announce changes, so it is
// re-read when the dock opens and after each change; closed, nothing is polled.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: brightness

    property int percent: -1
    property string device: ""
    readonly property bool available: percent >= 0
    // A reading that arrives right after our own change may carry the old value
    // (brightnessctl hasn't written yet): that one is dropped.
    property real lastChange: 0

    function refresh() {
        reader.running = true;
    }

    function setPercent(p) {
        p = Math.max(1, Math.min(100, Math.round(p)));
        percent = p;
        lastChange = Date.now();
        Commands.run(["brightnessctl", "-q", "-c", "backlight", "set", p + "%"], "Brightness");
    }

    // up | down | N (1-100)
    function adjust(arg) {
        const base = available ? percent : 50;
        if (arg === "up")
            setPercent(Math.floor(base / 5) * 5 + 5);
        else if (arg === "down")
            setPercent(Math.ceil(base / 5) * 5 - 5);
        else if (!isNaN(parseInt(arg)))
            setPercent(parseInt(arg));
    }

    // "intel_backlight,backlight,cur,42%,max"
    Process {
        id: reader
        command: ["brightnessctl", "-m", "-c", "backlight", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split("\n")[0].split(",");
                if (f.length >= 4 && Date.now() - brightness.lastChange > 800) {
                    brightness.device = f[0];
                    brightness.percent = parseInt(f[3]);
                }
            }
        }
    }

    Component.onCompleted: refresh()
}

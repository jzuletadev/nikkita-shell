// ~/nikkita-shell/dotfiles/quickshell/services/Recorder.qml
//
// Screen recording with wf-recorder. Stopping is SIGINT, so it closes the mp4 cleanly.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.common

Singleton {
    id: grab

    readonly property bool active: proc.running
    property real startedAt: 0
    readonly property string dir: Paths.recordings

    function start(region, audio) {
        if (proc.running)
            return;
        const mon = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        let sh = `mkdir -p "${dir}"; `;
        if (region)
            sh += 'G="$(slurp)"; [ -n "$G" ] || exit 0; ';
        sh += `exec wf-recorder -f "${dir}/$(date +%Y-%m-%d_%H-%M-%S).mp4" -p preset=veryfast -p crf=23 `;
        sh += region ? '-g "$G"' : `-o ${mon}`;
        if (audio)
            sh += ' --audio="$(pactl get-default-sink).monitor"';
        stopping = false;
        proc.command = ["sh", "-c", sh];
        proc.running = true;
    }

    // Stopped by you: whatever it exits with isn't a failure.
    property bool stopping: false
    function stop() {
        if (proc.running) {
            stopping = true;
            proc.signal(2);
        }
    }

    Process {
        id: proc
        stderr: StdioCollector {}
        onRunningChanged: if (running) grab.startedAt = Date.now()
        // Missing wf-recorder or slurp is exit 127 from sh; a cancelled slurp is 0.
        onExited: code => {
            if (code !== 0 && !grab.stopping)
                Commands.report("Screen recording", Commands.lastLine(stderr.text) || `wf-recorder ended with code ${code}.`);
        }
    }
}

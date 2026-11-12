// ~/nikkita-shell/dotfiles/quickshell/services/Emoji.qml
//
// The emoji the launcher searches after ":" (scripts/emoji.py), read the first time
// they are asked for and kept.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: emoji

    property var list: []           // [["😀", "grinning face"], ...]
    readonly property bool loading: proc.running

    function load() {
        if (list.length === 0 && !proc.running)
            proc.running = true;
    }

    Process {
        id: proc
        command: ["python3", Paths.script("emoji.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    emoji.list = JSON.parse(text);
                } catch (e) {
                    console.warn("emoji: can't read emoji.py:", e);
                }
            }
        }
        stderr: StdioCollector {}
        onExited: code => {
            if (code !== 0)
                Commands.report("Emoji", Commands.lastLine(stderr.text) || `emoji.py ended with code ${code}.`);
        }
    }
}

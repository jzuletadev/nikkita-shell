// ~/nikita-shell/dotfiles/quickshell/services/KeyboardState.qml
//
// The keyboard layouts and which one is on, and Caps Lock (Qt doesn't say). Read
// from the main keyboard; switching applies to all of them.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: keyboard

    property var layouts: []
    property int layoutIndex: 0
    property bool capsLock: false

    function refresh() {
        proc.running = true;
    }

    function setLayout(i) {
        Commands.run(["hyprctl", "switchxkblayout", "all", String(i)], "Switching the keyboard layout");
    }

    Process {
        id: proc
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const k = JSON.parse(text).keyboards || [];
                    const kb = k.find(x => x.main) || k[0];
                    keyboard.capsLock = k.some(x => x.capsLock);
                    if (kb) {
                        const layouts = (kb.layout || "").split(",").map(x => x.trim()).filter(x => x);
                        keyboard.layouts = layouts;
                        keyboard.layoutIndex = Math.max(0, kb.active_layout_index);
                    }
                } catch (e) {
                    console.warn("keyboard: can't parse `hyprctl devices -j`");
                }
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name === "activelayout")
                keyboard.refresh();
        }
    }

    Component.onCompleted: refresh()
}

// ~/nikita-shell/dotfiles/quickshell/services/KeyboardLight.qml
//
// The keyboard's backlight, on laptops that have one the kernel knows about: any
// LED named "…kbd_backlight" (dell::, tpacpi::, asus::, smc::, system76::…), set
// through brightnessctl (logind lets the session do it). Most have a few levels
// (off, dim, bright). /sys doesn't announce changes made with the laptop's own
// key, so it is read when Settings → Keyboard opens and after each change.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: light

    property string device: ""
    property int level: 0
    property int max: 0
    readonly property bool available: max > 0
    // A reading right after our own change may still carry the old level.
    property real lastChange: 0

    function refresh() {
        reader.running = true;
    }

    function set(n) {
        if (!available)
            return;
        level = Math.max(0, Math.min(max, Math.round(n)));
        lastChange = Date.now();
        Commands.run(["brightnessctl", "-q", "-d", device, "set", String(level)], "Keyboard light");
    }

    // up | down | N: the keyboard-light keys (hyprland.lua) come through here.
    function adjust(arg) {
        if (arg === "up")
            set(level + 1);
        else if (arg === "down")
            set(level - 1);
        else if (!isNaN(parseInt(arg)))
            set(parseInt(arg));
    }

    // "dell::kbd_backlight,leds,1,50%,2"; nothing when there is no such LED.
    Process {
        id: reader
        command: ["brightnessctl", "-m", "-c", "leds", "-d", "*kbd_backlight*", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split("\n")[0].split(",");
                if (f.length < 5 || f[1] !== "leds") {
                    light.max = 0;
                    return;
                }
                light.device = f[0];
                light.max = parseInt(f[4]) || 0;
                if (Date.now() - light.lastChange > 800)
                    light.level = parseInt(f[2]) || 0;
            }
        }
    }

    Component.onCompleted: refresh()
}

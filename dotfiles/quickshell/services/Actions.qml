// ~/nikita-shell/dotfiles/quickshell/services/Actions.qml
//
// What the launcher can do besides opening apps and Settings pages. Titles follow
// the current state ("Turn Wi-Fi off" while it's on). Nothing here loses work:
// log out, restart and shut down stay in the Power corner, where they ask first.
pragma Singleton

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import qs.common

Singleton {
    readonly property var adapter: Bluetooth.defaultAdapter

    readonly property var list: [
        { id: "lock", title: "Lock the screen", subtitle: "SUPER + L", icon: "system-lock-screen-symbolic", keys: "lock",
          run: () => ShellState.lock() },
        { id: "sleep", title: "Sleep", subtitle: "Locks the screen first", icon: "weather-clear-night-symbolic", keys: "suspend",
          run: () => ShellState.lockThen(["systemctl", "--no-ask-password", "suspend"], "Sleep") },
        { id: "theme", title: Theme.dark ? "Switch to the light style" : "Switch to the dark style", subtitle: "Theme", glyph: Theme.dark ? Glyphs.lightStyle : Glyphs.darkStyle, keys: "dark light theme mode",
          run: () => Commands.run([Paths.script("theme-manager.sh"), "toggle"], "Switching the theme") },
        { id: "wifi", title: Networking.wifiEnabled ? "Turn Wi-Fi off" : "Turn Wi-Fi on", subtitle: "Network", icon: "network-wireless-symbolic", keys: "wifi wireless internet",
          run: () => Networking.wifiEnabled = !Networking.wifiEnabled },
        { id: "bluetooth", title: adapter !== null && adapter.enabled ? "Turn Bluetooth off" : "Turn Bluetooth on", subtitle: "Bluetooth", icon: "bluetooth-symbolic", keys: "bluetooth",
          run: () => {
              if (adapter !== null)
                  adapter.enabled = !adapter.enabled;
              else
                  Commands.report("Bluetooth", "There is no Bluetooth adapter.");
          } },
        { id: "mic", title: Audio.micMuted ? "Unmute the microphone" : "Mute the microphone", subtitle: "Sound", icon: "microphone-sensitivity-high-symbolic", keys: "microphone mic mute",
          run: () => Audio.toggleMic() },
        { id: "dnd", title: ShellState.doNotDisturb ? "Turn Do not disturb off" : "Turn Do not disturb on", subtitle: "Notifications", icon: "preferences-system-notifications-symbolic", keys: "dnd quiet notifications silence",
          run: () => ShellState.doNotDisturb = !ShellState.doNotDisturb },
        { id: "awake", title: ShellState.keepAwake ? "Stop keeping the screen awake" : "Keep the screen awake", subtitle: "Power", glyph: Glyphs.keepAwake, keys: "awake caffeine idle inhibit",
          run: () => ShellState.keepAwake = !ShellState.keepAwake },
        { id: "record", title: Recorder.active ? "Stop recording" : "Record the screen", subtitle: "Recording", icon: "media-record-symbolic", keys: "record video capture screencast",
          run: () => Recorder.active ? Recorder.stop() : Recorder.start(false, false) },
        { id: "screenshot", title: "Screenshot of a region", subtitle: "SUPER + SHIFT + S", icon: "camera-photo-symbolic", keys: "screenshot capture picture",
          run: () => Commands.launch([Paths.script("screenshot.sh"), "region"], "Screenshot") },
        { id: "music", title: "Music", subtitle: "SUPER + SHIFT + M", icon: "folder-music-symbolic", keys: "songs player library",
          run: () => ShellState.openMusic() },
        { id: "night", title: Prefs.nightLight ? "Turn night light off" : "Turn night light on", subtitle: "Display", icon: "night-light-symbolic", keys: "night light warm blue filter redshift sunset evening eyes",
          run: () => Prefs.set("nightLight", !Prefs.nightLight) },
        { id: "color", title: "Pick a color from the screen", subtitle: "SUPER + SHIFT + C", icon: "color-select-symbolic", keys: "color colour picker eyedropper hex rgb",
          run: () => Commands.launch([Paths.script("color-pick.sh")], "Picking a color") },
        { id: "update", title: Updates.count > 0 ? `Update the system (${Updates.count})` : "Update the system", subtitle: "Packages", icon: "software-update-available-symbolic", keys: "update upgrade pacman packages paru aur",
          run: () => Updates.install() },
        // These two type into the launcher instead of closing it.
        { id: "emoji", title: "Emoji", subtitle: "Type : and a name", icon: "face-smile-big-symbolic", keys: "emoji smiley symbols", typed: ":" },
        { id: "clipboard", title: "Clipboard history", subtitle: "Type ; and part of the text", icon: "edit-paste-symbolic", keys: "clipboard paste copied history pinned", typed: ";" },
        { id: "calculator", title: "Calculator", subtitle: "Type a sum, or = and one", icon: "accessories-calculator-symbolic", keys: "calculator math sum", typed: "=" }
    ]
}

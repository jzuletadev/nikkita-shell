// ~/nikita-shell/dotfiles/quickshell/services/Privacy.qml
//
// Who is using the microphone, the camera or your screen right now, from PipeWire:
// the amber mark at the bottom (PrivacyMark) and the tray say so.
//
//   * Microphone: an app's capture stream linked to a real input (a sink's monitor,
//     the desktop's own sound, doesn't count).
//   * Camera: the same, for a camera node, when the app reaches it through PipeWire
//     (some browsers open /dev/video directly; those can't be seen from here).
//   * Screen: what xdg-desktop-portal-hyprland streams (meetings, OBS through the
//     portal). Not grim or wf-recorder, which don't go through the portal: the
//     desktop's own recording has its red mark.
//
// Only capture streams are bound (PwObjectTracker), so links are tracked only while
// something records: nothing at rest.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: privacy

    function isScreen(n) {
        return n !== null && n.type === PwNodeType.VideoSource && (n.name || "").startsWith("xdph");
    }
    // Capture streams, and the portal's screen streams (to see who reads them).
    readonly property var watched: Pipewire.nodes.values.filter(n => (n.isStream && !n.isSink) || isScreen(n))
    PwObjectTracker {
        objects: privacy.watched
    }

    function appName(n) {
        const p = n.properties || {};
        return p["application.name"] || p["application.process.binary"] || n.description || n.name || "An app";
    }
    function add(list, name) {
        if (list.indexOf(name) < 0)
            list.push(name);
    }

    readonly property var users: {
        const mic = [], camera = [], screen = [];
        for (const g of Pipewire.linkGroups.values) {
            const s = g.source, t = g.target;
            if (!s || !t)
                continue;
            if (isScreen(s))
                add(screen, appName(t));
            else if (t.isStream && s.type === PwNodeType.AudioSource)
                add(mic, appName(t));
            else if (t.isStream && s.type === PwNodeType.VideoSource)
                add(camera, appName(t));
        }
        // A portal stream nobody has linked yet is still a shared screen.
        if (screen.length === 0 && watched.some(n => isScreen(n)))
            screen.push("An app");
        return { mic: mic, camera: camera, screen: screen };
    }
    readonly property var mic: users.mic
    readonly property var camera: users.camera
    readonly property var screen: users.screen
    readonly property bool inUse: mic.length > 0 || camera.length > 0 || screen.length > 0

    // "Microphone: Brave, Discord" lines, for tips.
    readonly property string summary: [
        mic.length > 0 ? "Microphone: " + mic.join(", ") : "",
        camera.length > 0 ? "Camera: " + camera.join(", ") : "",
        screen.length > 0 ? "Screen: " + screen.join(", ") : ""
    ].filter(x => x !== "").join("\n")
}

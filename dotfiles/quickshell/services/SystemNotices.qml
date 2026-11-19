// ~/nikita-shell/dotfiles/quickshell/services/SystemNotices.qml
//
// A short word when the machine changes: the charger, the network, Bluetooth, the
// microphone, the theme... Each category can be turned off (Settings → Notifications).
//
// `now` is what is true at this moment. When it changes, and stays changed for a
// moment (a network that drops and returns says nothing), the difference is announced.
// Nothing is said while the session starts or the screen is locked, nor just after it
// unlocks: what changed meanwhile isn't news. Driven by the services' own changes:
// nothing polls.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.UPower
import qs.common

Singleton {
    id: notices

    readonly property var categories: [
        { id: "power", title: "Power", subtitle: "Charger plugged in or out, battery charged, power mode", icon: "battery-level-80-symbolic" },
        { id: "network", title: "Network", subtitle: "Wi-Fi on or off, connected or lost, the cable", icon: "network-wireless-symbolic" },
        { id: "bluetooth", title: "Bluetooth", subtitle: "On or off, devices connecting", icon: "bluetooth-symbolic" },
        { id: "microphone", title: "Microphone", subtitle: "Muted or back on", icon: "microphone-sensitivity-high-symbolic" },
        { id: "display", title: "Display", subtitle: "Theme, night light, monitors plugged in or out", icon: "video-display-symbolic" },
        { id: "modes", title: "Modes", subtitle: "Do not disturb turned off, keeping the screen awake", icon: "preferences-system-notifications-symbolic" }
    ]

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var now: ({
        charger: Battery.present ? !UPower.onBattery : null,
        charged: Battery.present ? Battery.full : null,
        wifi: !Networking.wifiEnabled ? "off"
            : Net.wifi ? (Net.wifi.networks.values.find(n => n.connected)?.name ?? "on") : null,
        cable: Net.wired ? Net.cable : null,
        bluetooth: adapter ? adapter.enabled : null,
        devices: adapter ? adapter.devices.values.filter(d => d.connected).map(d => d.name || d.address).sort() : [],
        displays: Quickshell.screens.map(s => s.name).sort(),
        microphone: Audio.source ? Audio.micMuted : null,
        mode: PowerProfiles.profile,
        theme: Theme.dark,
        night: NightLight.enabled,
        dnd: ShellState.doNotDisturb,
        awake: ShellState.keepAwake
    })

    // key -> [category, what to say about going from `was` to `is`]. In order of
    // importance: when several change together, the first is the one said.
    readonly property var messages: [
        ["charger", "power", is => is
            ? ["Charger connected", Battery.pct + " %", "ac-adapter-symbolic"]
            : ["On battery", Battery.detail.replace(/^On battery( · )?/, "") || Battery.pct + " %", Battery.icon]],
        ["charged", "power", is => is ? ["Battery charged", "", "battery-level-100-charged-symbolic"] : null],
        ["wifi", "network", (is, was) => is === "off" ? ["Wi-Fi off", "", "network-wireless-disabled-symbolic"]
            : is === "on" ? [was === "off" ? "Wi-Fi on" : "Wi-Fi disconnected", was === "off" ? "" : was, "network-wireless-symbolic"]
            : ["Connected to " + is, "", "network-wireless-symbolic"]],
        ["cable", "network", is => is ? ["Cable connected", "", "network-wired-symbolic"]
                                      : ["Cable unplugged", "", "network-wired-disconnected-symbolic"]],
        ["bluetooth", "bluetooth", is => [is ? "Bluetooth on" : "Bluetooth off", "", is ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic"]],
        ["devices", "bluetooth", (is, was) => notices.listChange(is, was, " connected", " disconnected", "bluetooth-active-symbolic")],
        ["displays", "display", (is, was) => notices.listChange(is, was, " connected", " disconnected", "video-display-symbolic")],
        ["microphone", "microphone", is => is ? ["Microphone muted", "", "microphone-sensitivity-muted-symbolic"]
                                              : ["Microphone on", "", "microphone-sensitivity-high-symbolic"]],
        ["mode", "power", is => {
            const m = PowerModes.list.find(x => x.profile === is);
            return m ? [m.title, m.subtitle, m.icon] : null;
        }],
        ["theme", "display", is => [is ? "Dark style" : "Light style", "", "preferences-color-symbolic"]],
        ["night", "display", is => [is ? "Night light on" : "Night light off", "", "night-light-symbolic"]],
        // Turning it on says nothing: that is what it is for.
        ["dnd", "modes", is => is ? null : ["Do not disturb off", "", "preferences-system-notifications-symbolic"]],
        ["awake", "modes", is => [is ? "Keeping the screen awake" : "The screen can sleep again", "", "video-display-symbolic"]]
    ]

    function listChange(is, was, added, removed, icon) {
        const on = is.find(x => was.indexOf(x) < 0);
        if (on !== undefined)
            return [on + added, "", icon];
        const off = was.find(x => is.indexOf(x) < 0);
        return off !== undefined ? [off + removed, "", icon] : null;
    }

    property var seen: null              // what was last taken as known
    property real quietUntil: 0

    onNowChanged: if (seen !== null) settle.restart()
    Connections {
        target: ShellState
        function onLockSecureChanged() {
            notices.quietUntil = Date.now() + 5000;
        }
    }

    function announce() {
        const was = seen;
        seen = now;
        if (ShellState.lockSecure || Date.now() < quietUntil)
            return;
        for (const [key, category, say] of messages) {
            const a = was[key], b = now[key];
            if (a === null || b === null || a === undefined || b === undefined || JSON.stringify(a) === JSON.stringify(b))
                continue;
            const m = Prefs.noticeShown(category) ? say(b, a) : null;
            if (m) {
                Commands.notice(m[0], m[1], m[2]);
                return;
            }
        }
    }

    Timer {
        id: settle
        interval: 1200
        onTriggered: notices.announce()
    }
    // The first time the desktop runs: every panel shows for a moment and a notice says
    // how they open. Settings → Panels → Show all does it again.
    Timer {
        running: !Prefs.introSeen
        interval: 12000
        onTriggered: {
            Prefs.set("introSeen", true);
            ShellState.peek("*", 5000, "");
            Commands.notice("Every edge and corner opens a panel", "Touch one. Settings → Panels shows where each is (SUPER + /).", "view-grid-symbolic");
        }
    }
    // The session starting up: services arrive one by one.
    Timer {
        running: true
        interval: 6000
        onTriggered: notices.seen = notices.now
    }
}

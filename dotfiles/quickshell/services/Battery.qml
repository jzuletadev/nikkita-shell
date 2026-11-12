// ~/nikkita-shell/dotfiles/quickshell/services/Battery.qml
//
// The laptop battery, from UPower: the Power corner, Settings → Power, Performance
// and the lock and login screens. `present` is false on a desktop PC.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.common

Singleton {
    readonly property var device: UPower.displayDevice
    readonly property bool present: device !== null && device.isLaptopBattery && device.isPresent
    // UPower has given 0-1 and 0-100, depending on the version.
    readonly property int pct: present ? Math.round(device.percentage > 1 ? device.percentage : device.percentage * 100) : 0
    readonly property bool charging: present && (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.PendingCharge)
    readonly property bool full: present && device.state === UPowerDeviceState.FullyCharged
    readonly property string icon: present ? device.iconName || "battery-symbolic" : "ac-adapter-symbolic"
    // Amber from 20 %, red from 10 %, unless it is charging.
    readonly property color level: pct <= 10 && !charging ? Theme.bad : pct <= 20 && !charging ? Theme.warn : Theme.accent
    readonly property string detail: !present ? "Plugged in"
        : full ? "Fully charged"
        : charging ? "Charging" + (device.timeToFull > 0 ? " · full in " + duration(device.timeToFull) : "")
        : "On battery" + (device.timeToEmpty > 0 ? " · " + duration(device.timeToEmpty) + " left" : "")

    function duration(s) {
        const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60);
        return (h > 0 ? h + " h " : "") + m + " min";
    }

    // ---- warnings ----
    // While it drains: once at 20 % and once at 5 % (UPower's "low" and "critical"
    // in /etc/UPower/UPower.conf). At 2 % UPower itself hibernates or turns the
    // computer off, so the last one says so. Plugging it in starts over. Driven by
    // UPower's own changes: nothing polls.
    readonly property bool draining: present && device.ready && device.state === UPowerDeviceState.Discharging
    property int warnedAt: 101          // the lowest level already warned about
    onDrainingChanged: draining ? warn() : warnedAt = 101
    onPctChanged: warn()

    function warn() {
        if (!draining)
            return;
        const left = device.timeToEmpty > 0 ? " · about " + duration(device.timeToEmpty) : "";
        if (pct <= 5 && warnedAt > 5) {
            warnedAt = 5;
            Commands.notify("Battery almost empty", `${pct} % left${left}. Plug in the charger: at 2 % the computer hibernates or turns off.`, "battery-level-0-symbolic", true);
        } else if (pct <= 20 && warnedAt > 20) {
            warnedAt = 20;
            Commands.notify("Battery low", `${pct} % left${left}.`, "battery-level-20-symbolic", false);
        }
    }
}

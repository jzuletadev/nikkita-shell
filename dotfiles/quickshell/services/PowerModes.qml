// ~/nikkita-shell/dotfiles/quickshell/services/PowerModes.qml
//
// The power modes (power-profiles-daemon), named and drawn the same in the Power
// corner and Settings → Power. Performance only where the machine has it.
pragma Singleton

import Quickshell
import Quickshell.Services.UPower

Singleton {
    readonly property var list: [
        { profile: PowerProfile.PowerSaver, title: "Power saver", subtitle: "Longer battery, quieter", icon: "power-profile-power-saver-symbolic" },
        { profile: PowerProfile.Balanced, title: "Balanced", subtitle: "The usual", icon: "power-profile-balanced-symbolic" },
        { profile: PowerProfile.Performance, title: "Performance", subtitle: "Everything the CPU has", icon: "power-profile-performance-symbolic" }
    ].filter(m => m.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)

    readonly property string limited: PowerProfiles.degradationReason !== PerformanceDegradationReason.None
        ? PerformanceDegradationReason.toString(PowerProfiles.degradationReason) : ""
}

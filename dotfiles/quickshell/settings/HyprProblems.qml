// ~/nikkita-shell/dotfiles/quickshell/settings/HyprProblems.qml
// What went wrong applying the settings Hyprland owns (keyboard, shortcuts, mouse,
// touchpad): shown at the top of those pages, only when there is something to say.
import QtQuick
import qs.common
import qs.services

Section {
    readonly property var lines: HyprSettings.problems.concat(HyprSettings.errors)

    visible: lines.length > 0
    title: "Not applied"
    note: "Hyprland said this about the settings. Changing the setting it names, or putting it back, clears it."

    Repeater {
        model: parent.lines

        SettingRow {
            required property string modelData
            icon: "dialog-warning-symbolic"
            title: modelData
        }
    }
}

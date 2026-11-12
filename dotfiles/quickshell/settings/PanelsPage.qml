// ~/nikkita-shell/dotfiles/quickshell/settings/PanelsPage.qml
// The edge panels: which open on touching their edge, and the workspace rail.
import QtQuick
import qs.common
import qs.services

Column {
    id: page
    spacing: Theme.spaceXl

    readonly property var panels: [
        { name: "workspaces", title: "Workspaces", where: "Left edge", icon: "view-app-grid-symbolic" },
        { name: "ctrl", title: "Volume and brightness", where: "Right edge", icon: "audio-volume-high-symbolic" },
        { name: "power", title: "Power", where: "Top-left corner", icon: "system-shutdown-symbolic" },
        { name: "dashboard", title: "Dashboard", where: "Top edge", icon: "view-grid-symbolic" },
        { name: "notifications", title: "Notification history", where: "Top-right corner", icon: "preferences-system-notifications-symbolic" },
        { name: "clipboard", title: "Clipboard", where: "Bottom-left corner", icon: "edit-paste-symbolic" },
        { name: "tray", title: "Tray", where: "Bottom edge", icon: "view-more-horizontal-symbolic" },
        { name: "quickactions", title: "Screenshots and quick actions", where: "Bottom-right corner", icon: "camera-photo-symbolic" }
    ]

    Section {
        title: "Open on touch"
        note: "Turned off, a panel only opens with its keys or when they are all shown: Show all, below, or the touchpad (four fingers apart, by default)."

        Repeater {
            model: page.panels

            SettingRow {
                id: panel
                required property var modelData
                icon: modelData.icon
                title: modelData.title
                subtitle: modelData.where
                PillButton {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 30
                    flat: true
                    text: "Show"
                    icon: "view-reveal-symbolic"
                    iconSize: 13
                    onClicked: ShellState.peek(panel.modelData.name, 2500, "")
                }
                ToggleSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Prefs.opensOnTouch(panel.modelData.name)
                    onToggled: Prefs.setOpensOnTouch(panel.modelData.name, !checked)
                }
            }
        }

        SettingRow {
            icon: "view-reveal-symbolic"
            title: "Show them all"
            subtitle: "Every panel on this monitor, for a few seconds. Four fingers spreading apart on the touchpad do it too, by default."
            PillButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Show all"
                onClicked: ShellState.peek("*", 4000, "")
            }
        }
    }

    Section {
        title: "Workspaces"
        SettingRow {
            icon: "view-app-grid-symbolic"
            title: "Show the rail on every jump"
            subtitle: "Switching workspace, by keys, gestures or clicks, shows the rail for a moment: a trace of where you went."
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: Prefs.railPeek
                onToggled: Prefs.set("railPeek", !Prefs.railPeek)
            }
        }
    }
}

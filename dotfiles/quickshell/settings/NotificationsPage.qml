// ~/nikita-shell/dotfiles/quickshell/settings/NotificationsPage.qml
// Do not disturb, and the whole saved history with room to read it.
import QtQuick
import qs.common
import qs.services

Column {
    id: page
    spacing: Theme.spaceXl

    function ago(t) {
        const s = Math.max(0, Math.floor((Date.now() - t) / 1000));
        if (s < 60)
            return "now";
        if (s < 3600)
            return Math.floor(s / 60) + " min ago";
        if (s < 86400)
            return Math.floor(s / 3600) + " h ago";
        return Qt.formatDateTime(new Date(t), Prefs.clock24h ? "d MMM, HH:mm" : "d MMM, h:mm AP");
    }

    Section {
        SettingRow {
            icon: "notifications-disabled-symbolic"
            title: "Do not disturb"
            subtitle: "New notifications go straight to the history without popping up. Critical ones still show."
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: ShellState.doNotDisturb
                onToggled: ShellState.doNotDisturb = !ShellState.doNotDisturb
            }
        }
    }

    Section {
        title: "System notices"
        note: "A short word when one of these changes. They stay out of the history, and Do not disturb silences them."

        Repeater {
            model: SystemNotices.categories

            SettingRow {
                id: noticeRow
                required property var modelData
                icon: modelData.icon
                title: modelData.title
                subtitle: modelData.subtitle
                ToggleSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Prefs.noticeShown(noticeRow.modelData.id)
                    onToggled: Prefs.setNoticeShown(noticeRow.modelData.id, !checked)
                }
            }
        }
    }

    Section {
        title: Notifs.history.length === 0 ? "History" : "History · " + Notifs.history.length
        note: "The last " + Notifs.limit + " are kept, also after a restart. The top-right corner shows them too."

        SettingRow {
            visible: Notifs.undoable !== null
            icon: "edit-undo-symbolic"
            title: "History cleared"
            PillButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Undo"
                onClicked: Notifs.undo()
            }
        }

        SettingRow {
            visible: Notifs.history.length > 0
            icon: "edit-clear-all-symbolic"
            title: "Clear the history"
            PillButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Clear all"
                danger: true
                onClicked: Notifs.clear()
            }
        }

        Repeater {
            model: Notifs.history

            SettingRow {
                id: entry
                required property var modelData
                appIcon: modelData.image || modelData.icon || "dialog-information"
                title: (modelData.critical ? "⚠ " : "") + (modelData.summary || modelData.app)
                subtitle: [modelData.app, page.ago(modelData.time)].filter(x => x).join(" · ")
                    + (modelData.body ? "\n" + modelData.body.replace(/<[^>]*>/g, "") : "")

                PillButton {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 28
                    flat: true
                    icon: "window-close-symbolic"
                    iconSize: 12
                    opacity: entry.hovering || hovering ? 1 : 0.35
                    onClicked: Notifs.removeEntry(entry.modelData.key)
                }
            }
        }

        StyledText {
            visible: Notifs.history.length === 0 && Notifs.undoable === null
            width: parent.width
            padding: Theme.spaceL
            text: "Nothing yet."
            color: Theme.dim
        }
    }
}

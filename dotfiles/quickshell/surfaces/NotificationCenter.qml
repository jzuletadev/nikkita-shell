// ~/nikkita-shell/dotfiles/quickshell/surfaces/NotificationCenter.qml

import QtQuick
import Quickshell
import qs.common
import qs.services

EdgePanel {
    id: center

    name: "notifications"
    edge: "top"
    placement: "end"
    span: m.corner
    depth: m.cornerHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: center.isOpen
    }

    function ago(ms) {
        const s = (clock.date.getTime() - ms) / 1000;
        if (s < 60)
            return "now";
        if (s < 3600)
            return Math.floor(s / 60) + " min";
        if (s < 86400)
            return Math.floor(s / 3600) + " h";
        const d = Math.floor(s / 86400);
        return d === 1 ? "yesterday" : d + " days";
    }

    Column {
        anchors.fill: parent
        spacing: Theme.spaceS

        Item {
            width: parent.width
            height: 28

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceS
                Icon { name: "preferences-system-notifications-symbolic"; size: 15; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                StyledText { text: "Notifications"; font.weight: Font.DemiBold }
                StyledText { text: Notifs.history.length; color: Theme.dim; font.pixelSize: Theme.textSmall }
                // Said in words too: the button alone is easy to miss when the
                // panel only peeks (SUPER + N).
                StyledText {
                    visible: ShellState.doNotDisturb
                    text: "· Do not disturb"
                    color: Theme.muted
                    font.pixelSize: Theme.textSmall
                }
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceXs
                PillButton {
                    height: 26
                    flat: !ShellState.doNotDisturb
                    active: ShellState.doNotDisturb
                    icon: "notifications-disabled-symbolic"
                    iconSize: 14
                    tip: "Do not disturb\nNotifications wait here instead of popping up"
                    onClicked: ShellState.doNotDisturb = !ShellState.doNotDisturb
                }
                PillButton {
                    height: 26
                    flat: true
                    icon: "user-trash-symbolic"
                    iconSize: 14
                    visible: Notifs.history.length > 0
                    tip: "Clear all"
                    onClicked: Notifs.clear()
                }
            }
        }

        Item {
            width: parent.width
            height: parent.height - 36

            ListView {
                id: listView
                width: parent.width - 6
                height: parent.height
                clip: true
                spacing: Theme.spaceXs
                boundsBehavior: Flickable.StopAtBounds
                model: Notifs.history

                StyledText {
                    anchors.centerIn: parent
                    visible: listView.count === 0
                    text: ShellState.doNotDisturb ? "Do not disturb is on" : "All caught up"
                    color: Theme.dim
                }

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    width: listView.width
                    height: col.implicitHeight + 16
                    radius: Theme.radiusM
                    color: area.containsMouse ? Theme.cardHover : Theme.card
                    border.width: modelData.critical ? 1 : 0
                    border.color: Theme.bad
                    Behavior on color { ColorAnimation { duration: Theme.msFast } }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    AppIcon {
                        id: ico
                        x: 10
                        y: 9
                        name: row.modelData.image || row.modelData.icon
                        size: 22
                    }
                    Column {
                        id: col
                        x: 42
                        y: 8
                        width: parent.width - 42 - 34
                        spacing: Theme.spaceXxs
                        Row {
                            width: parent.width
                            spacing: Theme.spaceS
                            StyledText {
                                width: Math.min(implicitWidth, parent.width - timeLabel.implicitWidth - parent.spacing)
                                text: row.modelData.summary || row.modelData.app
                                font.weight: Font.DemiBold
                                font.pixelSize: Theme.textLabel
                            }
                            StyledText {
                                id: timeLabel
                                text: center.ago(row.modelData.time)
                                color: Theme.dim
                                font.pixelSize: Theme.textCaption
                            }
                        }
                        StyledText {
                            width: parent.width
                            visible: text !== ""
                            text: row.modelData.body
                            textFormat: Text.StyledText
                            color: Theme.muted
                            font.pixelSize: Theme.textSmall
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                        }
                    }
                    PillButton {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spaceS
                        anchors.top: parent.top
                        anchors.topMargin: Theme.spaceS
                        height: 22
                        flat: true
                        icon: "window-close-symbolic"
                        iconSize: 11
                        opacity: area.containsMouse || hovering ? 1 : 0
                        onClicked: Notifs.removeEntry(row.modelData.key)
                    }
                }
            }

            EdgeFade { view: listView }

            ScrollHint { view: listView }
        }
    }
}

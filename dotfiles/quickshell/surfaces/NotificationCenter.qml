// ~/nikita-shell/dotfiles/quickshell/surfaces/NotificationCenter.qml

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

    // A click on a row: the notification's own action while it is alive, else the app
    // it came from; with neither, the whole text.
    function activate(row) {
        const live = Notifs.liveFor(row.modelData);
        const action = live ? Notifs.defaultAction(live) : null;
        if (action) {
            action.invoke();
            Notifs.removeToast(live);
            center.close();
        } else if (Notifs.openApp(row.modelData)) {
            center.close();
        } else {
            row.expanded = !row.expanded;
        }
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
                HexShape {
                    visible: Notifs.history.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    height: 20
                    width: Math.max(Math.round(height * Theme.hexRatio), labelWidth + Theme.spaceS)
                    fill: Theme.control
                    label: Notifs.history.length
                    labelColor: Theme.muted
                }
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
                    danger: true
                    // It keeps its place: Do not disturb, next to it, mustn't slide under
                    // the pointer that just cleared the list.
                    interactive: Notifs.history.length > 0
                    opacity: interactive ? 1 : 0
                    tip: interactive ? "Clear all" : ""
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

                Column {
                    anchors.centerIn: parent
                    visible: listView.count === 0
                    spacing: Theme.spaceS
                    Logo {
                        anchors.horizontalCenter: parent.horizontalCenter
                        mark: "rocket"
                        size: 44
                        color: Theme.faint
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Notifs.undoable !== null ? "History cleared" : ShellState.doNotDisturb ? "Do not disturb is on" : "All caught up"
                        color: Theme.dim
                    }
                    PillButton {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: Notifs.undoable !== null
                        height: 28
                        text: "Undo"
                        onClicked: Notifs.undo()
                    }
                }

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    property bool expanded: false
                    readonly property var live: Notifs.liveFor(modelData)
                    readonly property var liveActions: live ? live.actions.filter(a => a.identifier !== "default") : []
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
                        cursorShape: Qt.PointingHandCursor
                        onClicked: center.activate(row)
                    }

                    AppIcon {
                        id: ico
                        x: 10
                        y: 9
                        name: row.modelData.image || row.modelData.icon || (Notifs.appFor(row.modelData)?.icon ?? "")
                        initial: row.modelData.app || row.modelData.summary
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
                            maximumLineCount: row.expanded ? 12 : 2
                        }
                        Flow {
                            width: parent.width
                            visible: row.liveActions.length > 0
                            spacing: Theme.spaceXs
                            topPadding: Theme.spaceXs
                            Repeater {
                                model: row.liveActions
                                PillButton {
                                    required property var modelData
                                    text: modelData.text
                                    height: 26
                                    onClicked: {
                                        const n = row.live;   // invoking can destroy it
                                        modelData.invoke();
                                        Notifs.removeToast(n);
                                    }
                                }
                            }
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

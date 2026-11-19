// ~/nikita-shell/dotfiles/quickshell/surfaces/Clipboard.qml

import QtQuick
import qs.common
import qs.services

EdgePanel {
    id: board

    name: "clipboard"
    edge: "bottom"
    placement: "start"
    span: m.corner
    depth: m.cornerHeight

    property string copied: ""

    Column {
        anchors.fill: parent
        spacing: Theme.spaceS

        Item {
            width: parent.width
            height: 28

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceS
                Icon { name: "edit-paste-symbolic"; size: 15; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                StyledText { text: "Clipboard"; font.weight: Font.DemiBold }
                HexShape {
                    visible: ClipHistory.shown.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    height: 20
                    width: Math.max(Math.round(height * Theme.hexRatio), labelWidth + Theme.spaceS)
                    fill: Theme.control
                    label: ClipHistory.shown.length
                    labelColor: Theme.muted
                }
            }
            PillButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 26
                flat: true
                icon: "user-trash-symbolic"
                iconSize: 14
                visible: ClipHistory.entries.length > 0
                danger: true
                tip: "Clear the history\nPinned ones stay"
                onClicked: ClipHistory.clear()
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
            model: ClipHistory.shown

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
                    text: ClipHistory.undoable !== null ? "History cleared" : "Nothing copied yet\nSearch it from the launcher: ;"
                    color: Theme.dim
                }
                PillButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: ClipHistory.undoable !== null
                    height: 28
                    text: "Undo"
                    onClicked: ClipHistory.undo()
                }
            }

            delegate: Rectangle {
                id: row
                required property string modelData
                required property int index
                readonly property bool isPinned: ClipHistory.pinned.indexOf(modelData) >= 0
                width: listView.width
                height: 30
                radius: Theme.radiusM
                color: board.copied === modelData ? Theme.accentSoft : area.containsMouse ? Theme.cardHover : Theme.card
                Behavior on color { ColorAnimation { duration: Theme.msFast } }

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: row.isPinned ? 28 : Theme.spaceM
                    anchors.right: pinButton.left
                    anchors.rightMargin: Theme.spaceS
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.replace(/\s+/g, " ").trim()
                    font.pixelSize: Theme.textLabel
                    color: board.copied === row.modelData ? Theme.accent : Theme.fg
                }
                Icon {
                    visible: row.isPinned
                    x: Theme.spaceM
                    anchors.verticalCenter: parent.verticalCenter
                    name: "view-pin-symbolic"
                    size: 12
                    color: Theme.muted
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        ClipHistory.copy(row.modelData);
                        board.copied = row.modelData;
                        forgetTimer.restart();
                    }
                }
                PillButton {
                    id: pinButton
                    anchors.right: removeButton.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: 24
                    flat: true
                    icon: "view-pin-symbolic"
                    iconSize: 12
                    active: row.isPinned
                    carried: false
                    tip: row.isPinned ? "Unpin" : "Pin: it stays on top"
                    opacity: area.containsMouse || hovering || row.isPinned ? 1 : 0
                    onClicked: row.isPinned ? ClipHistory.unpin(row.modelData) : ClipHistory.pin(row.modelData)
                }
                PillButton {
                    id: removeButton
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spaceXs
                    anchors.verticalCenter: parent.verticalCenter
                    height: 24
                    flat: true
                    icon: "window-close-symbolic"
                    iconSize: 12
                    opacity: area.containsMouse || hovering ? 1 : 0
                    onClicked: ClipHistory.remove(row.modelData)
                }
            }
        }

        EdgeFade { view: listView }

        ScrollHint { view: listView }
        }
    }

    Timer {
        id: forgetTimer
        interval: 1200
        onTriggered: board.copied = ""
    }
}

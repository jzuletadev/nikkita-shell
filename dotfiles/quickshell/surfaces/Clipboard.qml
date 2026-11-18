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
                StyledText { text: ClipHistory.entries.length; color: Theme.dim; font.pixelSize: Theme.textSmall }
            }
            PillButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 26
                flat: true
                icon: "user-trash-symbolic"
                iconSize: 14
                visible: ClipHistory.entries.length > 0
                tip: "Clear the history"
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
            model: ClipHistory.entries

            StyledText {
                anchors.centerIn: parent
                visible: listView.count === 0
                text: "Nothing copied yet"
                color: Theme.dim
            }

            delegate: Rectangle {
                id: row
                required property string modelData
                required property int index
                width: listView.width
                height: 30
                radius: Theme.radiusM
                color: board.copied === modelData ? Theme.accentSoft : area.containsMouse ? Theme.cardHover : Theme.card
                Behavior on color { ColorAnimation { duration: Theme.msFast } }

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spaceM
                    anchors.right: removeButton.left
                    anchors.rightMargin: Theme.spaceS
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.replace(/\s+/g, " ").trim()
                    font.pixelSize: Theme.textLabel
                    color: board.copied === row.modelData ? Theme.accent : Theme.fg
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

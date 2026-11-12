// ~/nikkita-shell/dotfiles/quickshell/settings/NavItem.qml
// A page in the Settings sidebar. `cursor` is the keyboard's pick while filtering.
import QtQuick
import qs.common

Item {
    id: item

    required property var page
    property bool selected: false
    property bool cursor: false
    signal clicked

    width: parent ? parent.width : 0
    height: 54

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusM
        color: item.selected ? Theme.alpha(Theme.fg, 0.12) : (area.containsMouse || item.cursor) ? Theme.alpha(Theme.fg, 0.06) : "transparent"
        border.width: item.cursor && !item.selected ? 1 : 0
        border.color: Theme.alpha(Theme.fg, 0.4)
        Behavior on color { ColorAnimation { duration: Theme.msFast } }
    }

    Rectangle {
        x: 11
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: 36
        radius: width / 2
        // Not inverted on hover: it would look chosen.
        color: item.selected ? Theme.accent : area.containsMouse ? Theme.alpha(Theme.fg, 0.16) : Theme.alpha(Theme.fg, 0.08)
        scale: item.selected || area.containsMouse ? 1 : 0.9
        Behavior on color { ColorAnimation { duration: Theme.msNormal } }
        Behavior on scale { NumberAnimation { duration: Theme.msSlow; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

        Icon {
            anchors.centerIn: parent
            name: item.page.icon
            size: 18
            color: item.selected ? Theme.accentText : Theme.fg
        }
    }

    Column {
        x: 58
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - 10
        spacing: Theme.spaceXxs
        StyledText {
            width: parent.width
            text: item.page.title
            font.pixelSize: Theme.textLarge
            font.weight: item.selected ? Font.DemiBold : Font.Medium
        }
        StyledText {
            width: parent.width
            text: item.page.subtitle
            color: Theme.muted
            font.pixelSize: Theme.textSmall
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: item.clicked()
    }
}

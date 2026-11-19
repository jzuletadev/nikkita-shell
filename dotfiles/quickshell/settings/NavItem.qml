// ~/nikita-shell/dotfiles/quickshell/settings/NavItem.qml
// A page in the Settings sidebar. `cursor` is the keyboard's pick. `iconOnly` (a narrow
// window) keeps just the icon; `dense` (a short screen) drops the subtitle.
import QtQuick
import qs.common

Item {
    id: item

    required property var page
    property bool selected: false
    property bool cursor: false
    property bool iconOnly: false
    property bool dense: false
    signal clicked

    width: parent ? parent.width : 0
    height: dense || iconOnly ? 44 : 54

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusM
        // The chosen one's fill is the sidebar's sliding mark, not this.
        color: item.selected ? "transparent" : (area.containsMouse || item.cursor) ? Theme.alpha(Theme.fg, 0.06) : "transparent"
        // The keyboard's pick wears the same ring as a focused control.
        border.width: item.cursor ? 2 : 0
        border.color: Theme.fg
        Behavior on color { ColorAnimation { duration: Theme.msFast } }
    }

    Rectangle {
        x: item.iconOnly ? (parent.width - width) / 2 : 11
        anchors.verticalCenter: parent.verticalCenter
        width: item.dense || item.iconOnly ? 32 : 36
        height: width
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
        visible: !item.iconOnly
        x: item.dense ? 52 : 58
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
            visible: !item.dense
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

        Tip {
            text: item.iconOnly ? item.page.title : ""
            side: "right"
        }
    }
}

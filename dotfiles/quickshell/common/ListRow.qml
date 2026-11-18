// ~/nikita-shell/dotfiles/quickshell/common/ListRow.qml
// A list row: icon, title, subtitle and whatever goes on the right.
import QtQuick
import qs.common

Rectangle {
    id: f

    property string icon: ""
    property string appIcon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false          // the one in use (connected network, active theme...)
    property bool cursor: false          // highlighted by the keyboard
    property color iconColor: active ? Theme.accent : Theme.fg
    default property alias trailing: side.data
    readonly property bool hovering: area.containsMouse

    signal clicked
    signal rightClicked

    implicitHeight: 44
    radius: Theme.radiusM
    color: active ? Theme.accentSoft : (hovering || cursor) ? Theme.cardHover : Theme.card
    border.width: cursor ? 1 : 0
    border.color: Theme.accent
    Behavior on color { ColorAnimation { duration: Theme.msFast } }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: ev => ev.button === Qt.RightButton ? f.rightClicked() : f.clicked()
    }

    Icon {
        id: ico
        visible: f.icon !== ""
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        name: f.icon
        size: 16
        color: f.iconColor
    }
    AppIcon {
        id: icoApp
        visible: f.appIcon !== ""
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        name: f.appIcon
        size: 22
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        x: f.icon !== "" || f.appIcon !== "" ? 40 : 14
        width: parent.width - x - side.width - 12
        spacing: Theme.spaceXxs
        StyledText {
            width: parent.width
            text: f.title
            font.weight: f.active ? Font.DemiBold : Font.Normal
            color: f.active ? Theme.accent : Theme.fg
        }
        StyledText {
            width: parent.width
            visible: text !== ""
            text: f.subtitle
            color: Theme.muted
            font.pixelSize: Theme.textSmall
        }
    }

    Row {
        id: side
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceS
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceXs
    }
}

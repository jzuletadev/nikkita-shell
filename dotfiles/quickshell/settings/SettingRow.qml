// ~/nikita-shell/dotfiles/quickshell/settings/SettingRow.qml
// One setting inside a Section; its control goes on the right.
import QtQuick
import qs.common

Item {
    id: row

    property string icon: ""             // symbolic theme icon
    property string appIcon: ""          // full-color application icon
    property int glyph: 0                // or a Nerd Font glyph
    property string title: ""
    property string subtitle: ""
    property bool clickable: false
    property bool divider: Positioner.index > 0
    default property alias control: side.data
    readonly property bool hovering: area.containsMouse
    readonly property bool hasIcon: icon !== "" || appIcon !== "" || glyph > 0

    signal clicked

    width: parent ? parent.width : 0
    implicitHeight: Math.max(56, texts.implicitHeight + 24)

    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.spaceXxs
        radius: Theme.radiusM
        color: row.clickable && area.containsMouse ? Theme.alpha(Theme.fg, 0.06) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.msFast } }
    }
    Rectangle {
        visible: row.divider
        x: 16
        width: parent.width - 32
        height: 1
        color: Theme.divider
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: row.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (row.clickable) row.clicked()
    }

    Icon {
        visible: row.icon !== ""
        x: 18
        anchors.verticalCenter: parent.verticalCenter
        name: row.icon
        size: 18
    }
    AppIcon {
        visible: row.appIcon !== "" && row.icon === ""
        x: 15
        anchors.verticalCenter: parent.verticalCenter
        name: row.appIcon
        size: 24
    }
    Glyph {
        visible: row.glyph > 0 && row.icon === "" && row.appIcon === ""
        x: 15
        width: 24
        anchors.verticalCenter: parent.verticalCenter
        code: row.glyph
        size: 18
    }

    Column {
        id: texts
        x: row.hasIcon ? 54 : 18
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - side.width - 34
        spacing: Theme.spaceXxs
        StyledText {
            width: parent.width
            text: row.title
            font.pixelSize: Theme.textLarge
        }
        StyledText {
            width: parent.width
            visible: text !== ""
            text: row.subtitle
            color: Theme.muted
            font.pixelSize: Theme.textSmall
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            maximumLineCount: 3
        }
    }

    Row {
        id: side
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceL
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceM
    }
}

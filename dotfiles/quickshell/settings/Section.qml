// ~/nikkita-shell/dotfiles/quickshell/settings/Section.qml
// A group of settings: a header, a card with its rows, and an optional note.
import QtQuick
import qs.common

Column {
    id: section

    property string title: ""
    property string note: ""
    property int padding: Theme.spaceXs
    default property alias content: body.data

    width: parent ? parent.width : 0
    spacing: Theme.spaceS

    StyledText {
        visible: section.title !== ""
        text: section.title
        leftPadding: Theme.spaceS
        color: Theme.muted
        font.pixelSize: Theme.textLabel
        font.weight: Font.DemiBold
    }

    Rectangle {
        width: parent.width
        height: body.implicitHeight + 2 * section.padding
        radius: Theme.radiusL
        color: Theme.alpha(Theme.fg, 0.045)

        Column {
            id: body
            x: section.padding
            y: section.padding
            width: parent.width - 2 * section.padding
        }
    }

    StyledText {
        visible: section.note !== ""
        width: parent.width
        text: section.note
        leftPadding: Theme.spaceS
        rightPadding: Theme.spaceS
        color: Theme.dim
        font.pixelSize: Theme.textSmall
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }
}

// ~/nikita-shell/dotfiles/quickshell/common/Glyph.qml
// A Nerd Font icon by code point, for what Adwaita has no symbolic icon for.
import QtQuick
import qs.common

StyledText {
    property int code: 0
    property int size: 16

    text: code > 0 ? String.fromCodePoint(code) : ""
    font.family: Theme.glyphFamily
    font.pixelSize: size
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideNone
}

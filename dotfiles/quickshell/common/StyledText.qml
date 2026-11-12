// ~/nikkita-shell/dotfiles/quickshell/common/StyledText.qml
// Text in the desktop's font and color.
import QtQuick
import qs.common

Text {
    color: Theme.fg
    font.family: Theme.fontFamily
    font.pixelSize: Theme.textBody
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    Behavior on color { ColorAnimation { duration: Theme.msNormal } }
}
